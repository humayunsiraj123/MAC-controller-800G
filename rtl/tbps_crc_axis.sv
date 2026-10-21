/*
This module wraps a CRC generator with AXI-Stream (AXIS) bus interfaces for easy integration.

// CRC polynomial parameters:
- CRC_WIDTH:  Width of the CRC output (e.g., 16 for CRC-16)
- CRC_POLY:   CRC polynomial (hexadecimal, e.g., 16'hda5f)

Ports:

- clk:                Clock input
- rst:                Synchronous reset (active high)
// Dynamic CRC control inputs:
- crc_init_val:  Initial CRC value [CRC_WIDTH-1:0] (input)
- xor_out:       Value to XOR with CRC result before output (input)
- ref_in:        Reflect input bytes (bit reversal per byte, input)
- ref_out:       Reflect output CRC (bit reversal, input)
// Input data bus
- i_data_axis_tdata:  AXIS input data bus [DWIDTH-1:0]
- i_data_axis_tkeep:  AXIS input byte enable mask [DWIDTH/8-1:0]
- i_data_axis_tlast:  AXIS input last signal (asserted on last data beat)
- i_data_axis_tvalid: AXIS input valid strobe
// Output ports:
- o_crc_axis_tdata:   AXIS output CRC value [CRC_WIDTH-1:0]
- o_crc_axis_tvalid:  AXIS output valid strobe (asserted when o_crc_axis_tdata is valid)

Usage:

- Set crc_init_val, xor_out, ref_in, and ref_out as needed for your CRC configuration.
- Assert i_data_axis_tvalid when i_data_axis_tdata and i_data_axis_tkeep are valid.
- Set i_data_axis_tlast high on the last data beat of a packet.
- o_crc_axis_tdata and o_crc_axis_tvalid will be asserted with the computed CRC after the last beat.
- The module supports pipelined operation for high-throughput designs.

============================================================================
*/

`timescale 1ps / 1ps
module tbps_crc_axis #(
  /*
  Implementation parameters:
  */
  // Data width in bits (must be a multiple of 8)
  parameter int DWIDTH             = 512         ,
  // Number of pipeline stages (latency control)
  parameter int PIPE_LVL           = 0           ,
  // Revert pipeline enable one-hot code, controls whether to register corresponding pipeline stages, default is all stages enabled
  parameter int REV_PIPE_EN_ONEHOT = 32'hffffffff,
  /*
  CRC polynomial parameters:
  */
  // CRC output width in bits
  parameter int CRC_WIDTH          = 16          ,
  // CRC polynomial in hexadecimal format
  parameter     CRC_POLY           = 16'hda5f
) (
  // Clock signal
  input  logic                 clk               ,
  // Synchronous reset (active high)
  input  logic                 rst               ,
  // AXIS input data bus
  input  logic [   DWIDTH-1:0] i_data_axis_tdata ,
  // AXIS input byte enable mask
  input  logic [ DWIDTH/8-1:0] i_data_axis_tkeep ,
  // AXIS input last signal (asserted on last data beat)
  input  logic                 i_data_axis_tlast ,
  // AXIS input valid strobe
  input  logic                 i_data_axis_tvalid,
  // CRC initial value
  input  logic [CRC_WIDTH-1:0] crc_init_val      ,
  // Value to XOR with CRC result before output
  input  logic [CRC_WIDTH-1:0] xor_out           ,
  // Reflect input bytes (bit reversal per byte)
  input  logic                 ref_in            ,
  // Reflect output CRC (bit reversal)
  input  logic                 ref_out           ,
  // AXIS output CRC value
  output logic [CRC_WIDTH-1:0] o_crc_axis_tdata  ,
  // AXIS output valid strobe (asserted when o_crc_axis_tdata is valid)
  output logic                 o_crc_axis_tvalid ,
  //TODO: i_tready logic inverison
  output logic                 bp_user
);
  logic i_tready;
  // Instantiate the CRC generator, directly connecting wrapper ports
  logic [(DWIDTH/64)-1:0][64-1:0] dbg_data_axis_tdata;
  // AXIS  byte enable mask
  logic [(DWIDTH/64)-1:0][8-1:0] dbg_data_axis_tkeep;

  assign dbg_data_axis_tdata = i_data_axis_tdata;
  assign dbg_data_axis_tkeep = i_data_axis_tkeep;

  localparam     NUM_BYTE   = DWIDTH/8                    ;
  localparam     NUM_LN     = DWIDTH/64                   ;
  localparam     BYTE_CNT_W = $clog2(NUM_BYTE)            ;
  localparam     LN_CNT_W   = $clog2(NUM_LN)              ;
  localparam logic [64-1:0] SOF_WORD   = 64'hD5_55_55_55_55_55_55_FB ;
  localparam logic [96-1:0] IDLE_WORD  = 96'h070707070707070707070707;


  typedef struct packed {
    logic [1:0]                 frm_vld     ;
    logic [1:0]                 frm_end     ;
    logic [1:0][    NUM_LN-1:0] frm_num_ln  ;
    logic [1:0][BYTE_CNT_W-1:0] frm_fcs_ofst;
  } ctrl_t;

  typedef struct packed {
    logic [0:0]               frm_vld     ;
    logic [0:0]               frm_sof     ;
    logic [0:0]               frm_end     ;
    logic [0:0][  LN_CNT_W:0] frm_num_ln  ;
    logic [0:0][BYTE_CNT_W:0] frm_fcs_ofst;
  } in_ctrl_t;
  logic [NUM_LN*2-1:0][64-1:0] aligner       ;
  logic [NUM_LN*2-1:0][64-1:0] aligner1      ;
  logic [NUM_LN*2-1:0][64-1:0] aligner2      ;
  logic [NUM_LN*2-1:0][64-1:0] aligner3      ;
  logic [  NUM_LN-1:0][64-1:0] aligned       ;
  logic                        wr_vld        ;
  logic [LN_CNT_W-1:0]         aligner_ofst_c;
  logic [LN_CNT_W-1:0]         sof_ofst_r    ;
  logic [LN_CNT_W-1:0]         aligner_ofst  ;
  logic [LN_CNT_W-1:0]         curr_beat_ln  ;
  logic [LN_CNT_W-1:0]         extr_offset   ;

  logic [  BYTE_CNT_W:0] fcs_ofst  ;
  logic [BYTE_CNT_W-1:0] fcs_ofst_r; //for modulo
  logic [  BYTE_CNT_W:0] ipg_ofst  ;

  logic [BYTE_CNT_W:0] byte_cnt    ;
  logic [BYTE_CNT_W:0] byte_cnt_c  ;
  logic [BYTE_CNT_W:0] byte_cnt_r  ;
  logic [BYTE_CNT_W:0] byte_cnt_avl;
  logic [  LN_CNT_W:0] ln_cnt_avl  ;

  logic tlast_lch  ;
  logic tlast_lch_r;
  logic sof        ;
  logic halt_wr    ;
  logic halt_wr_r  ;
  logic i_tready_r ;

  in_ctrl_t pkt_ctrl_r ;
  in_ctrl_t rd_pkt_ctrl;
  in_ctrl_t pkt_ctrl   ;
  ctrl_t    pkt_ctrl_pf;
  // AXIS  byte enable mask

  logic [(DWIDTH/64)-1:0][64-1:0] in_reg_axis_tdata ;
  logic [(DWIDTH/64)-1:0][ 8-1:0] in_reg_axis_tkeep ;
  logic                           in_reg_axis_tlast ;
  logic                           in_reg_axis_tvalid;
  logic                           slave_ready       ;
  logic                           in_reg_axis_sof   ;

  logic [  NUM_LN*2-1:0][64-1:0] pf_aligner        ;
  logic [    NUM_LN-1:0][64-1:0] pf_aligned        ;
  logic                          out_beat_vld      ;
  logic [  LN_CNT_W-1:0]         pf_aligner_ofst_c ;
  logic [  LN_CNT_W-1:0]         pf_sof_ofst_r     ;
  logic [  LN_CNT_W-1:0]         pf_aligner_ofst   ;
  logic [  LN_CNT_W-1:0]         pf_aligner_ofst_d ;
  logic [  LN_CNT_W-1:0]         pf_aligner_ofst_d2;
  logic [  LN_CNT_W-1:0]         pf_curr_beat_ln   ;
  logic [  LN_CNT_W-1:0]         pf_extr_offset    ;
  logic [  BYTE_CNT_W:0]         pf_fcs_ofst       ;
  logic [  BYTE_CNT_W:0]         pf_efd_ofst       ;
  logic [  BYTE_CNT_W:0]         pf_efd_ofst_d     ;
  logic [  BYTE_CNT_W:0]         pf_fcs_ofst_d     ;
  logic [  BYTE_CNT_W:0]         pf_fcs_ofst_d2    ;
  logic [BYTE_CNT_W-1:0]         pf_fcs_ofst_r     ;
  logic [BYTE_CNT_W-1:0]         pf_fcs_ofst_r2    ;
  logic [BYTE_CNT_W-1:0]         pf_fcs_ofst_r3    ;
  logic [  BYTE_CNT_W:0]         pf_fcs_ofst_late  ;
  logic [  BYTE_CNT_W:0]         pf_ipg_ofst       ;
  logic [  BYTE_CNT_W:0]         pf_byte_cnt       ;
  logic [  BYTE_CNT_W:0]         pf_byte_cnt_c     ;
  logic [  BYTE_CNT_W:0]         pf_byte_cnt_r     ;
  logic [  BYTE_CNT_W:0]         pf_byte_cnt_avl   ;
  logic [    LN_CNT_W:0]         pf_ln_cnt_avl     ;
  logic                          pf_tlast_lch      ;
  logic                          pf_tlast_lch_r    ;
  logic                          pf_sof            ;
  logic                          pf_sof_d          ;
  logic                          pf_sof_d2         ;
  logic                          pf_sof_d3         ;
  logic                          pf_eof_d          ;
  logic                          pf_eof_d2         ;
  logic                          pf_eof_d3         ;
  logic                          rd_crtl_en        ;
  logic                          rd_crtl_en_d      ;
  logic                          pf_halt_wr        ;
  logic                          pf_halt_wr_r      ;
  logic                          pf_halt_wr_r2     ;
  logic                          pf_i_tready_r     ;
  in_ctrl_t                    pf_pkt_ctrl_r     ;
  in_ctrl_t                    pf_rd_pkt_ctrl    ;
  in_ctrl_t                    pf_pkt_ctrl       ;
  ctrl_t                       pf_pkt_ctrl_pf    ;
  logic [ CRC_WIDTH-1:0]         pkt_crc           ;
  logic                          halt_rd           ;
  logic                          halt_rd_r         ;
  logic                          eop_late          ;
  logic                          eop_late_c        ;
  logic                          eop_late_r        ;
  logic                          eop_late_r2       ;

  logic [   1:0]      num_ln_append ;
  logic [15-1:0][7:0] idle_word_c   ;
  logic [15-1:0][7:0] idle_word     ;
  logic [   3:0]      ipg_en_cnt    ;
  logic [   1:0]      ln_cnt_ocpy   ;
  logic [   1:0]      dic_cnt       ;
  logic [   1:0]      dic_cnt_r     ;
  logic [   4:0]      invld_byte_off;

//localparam CRC_WIDTH = 32;
  logic                 crc_wr_en  ;
  logic                 crc_rd_en  ;
  logic [CRC_WIDTH-1:0] crc_wr_data;
  logic [CRC_WIDTH-1:0] crc_rd_data;
  logic                 crc_full   ;
  logic                 crc_empty  ;



  localparam DEPTH     = 128; //minimum depth reuried is 78 beat for close bram 2^n
  localparam D_LATENCY = 1  ;

  logic arst_n;
  assign arst_n = ~rst;

  logic                           wr       ;
  logic [     DWIDTH-1:0]         wr_data  ;
  logic                           full     ;
  logic                           tfull    ;
  logic                           ovf      ;
  logic                           rd       ;
  logic [         16-1:0][64-1:0] rd_data  ;
  logic                           empty    ;
  logic                           tempty   ;
  logic                           udf      ;
  logic [$clog2(DEPTH):0]         num_vld  ;
  logic                           init_done;
  logic                           sec      ;
  logic                           ded      ;

  localparam           CR_WIDTH   = $bits(in_ctrl_t); //20;
  logic                cr_wr_en                     ;
  logic                cr_rd_en                     ;
  logic [CR_WIDTH-1:0] cr_wr_data                   ;
  logic [CR_WIDTH-1:0] cr_rd_data                   ;

  logic cr_full ;
  logic cr_empty;
//reading  user reading reg
//TODO : need to update the logic
  always_ff @(posedge clk) begin : proc_tlast_lch_r
    if(rst) begin
      tlast_lch_r <= 1;
    end else if(i_data_axis_tvalid & bp_user/*& ~i_tready*/) begin
      tlast_lch_r <= i_data_axis_tvalid & i_data_axis_tlast ;
    end
  end

  assign byte_cnt_c = $countones(i_data_axis_tkeep) ;

  assign slave_ready = ~tfull;
  always_ff @(posedge clk) begin : blk_ip_reg
    if(rst)
      begin
        pf_tlast_lch_r          <= 1;
        in_reg_axis_tkeep       <= '0;//
        in_reg_axis_tlast       <= '0;//
        in_reg_axis_tvalid      <= '0;//
        pkt_ctrl_r.frm_end      <= '0;//
        pkt_ctrl_r.frm_vld      <= '0;//
        pkt_ctrl_r.frm_num_ln   <= '0;//
        pkt_ctrl_r.frm_fcs_ofst <= '0;//
        pkt_ctrl_r.frm_sof      <= '0;//
        in_reg_axis_tdata       <= '0;//
        in_reg_axis_sof         <=  0;
      end
    else if(slave_ready&i_data_axis_tvalid)
      begin
        for(int ii =0 ; ii<NUM_BYTE; ii++)
          in_reg_axis_tdata[ii/8][(ii%8)*8+:8] <= i_data_axis_tkeep[ii]?i_data_axis_tdata[8*ii+:8] : '0;
        in_reg_axis_tkeep       <= i_data_axis_tvalid ? i_data_axis_tkeep :  0;
        in_reg_axis_tlast       <= i_data_axis_tvalid & i_data_axis_tlast ;
        in_reg_axis_tvalid      <= i_data_axis_tvalid ;
        in_reg_axis_sof         <= tlast_lch_r & i_data_axis_tvalid;
        pkt_ctrl_r.frm_vld      <= i_data_axis_tvalid ;
        pkt_ctrl_r.frm_end      <= i_data_axis_tvalid  & i_data_axis_tlast ;
        pkt_ctrl_r.frm_num_ln   <= byte_cnt_c[BYTE_CNT_W:3] + |byte_cnt_c[2:0]             ;
        pkt_ctrl_r.frm_fcs_ofst <= byte_cnt_c;
        pkt_ctrl_r.frm_sof      <= tlast_lch_r & i_data_axis_tvalid;
      end
    else if(slave_ready)
      begin
        in_reg_axis_tvalid <= 0;
        pkt_ctrl_r.frm_vld <= 0;
      end
  end
  assign bp_user = ~tfull;

//==================================================================================================================================================================
//                                                                Main logic
//==================================================================================================================================================================

  assign pf_ln_cnt_avl  = NUM_LN - rd_pkt_ctrl.frm_num_ln;
  assign rd_crtl_en     = ~halt_rd &  ~cr_empty  & ~crc_empty;
  assign pf_sof         = rd_crtl_en&& rd_pkt_ctrl.frm_sof;
  assign pf_extr_offset = 0;//(aligner_ofst>2 & sof & i_data_axis_tvalid&i_data_axis_tlast & (byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst)<16) ? 16 -(byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst) : 0;
//todo:                                 set 5'h16d for fd to be ipg part 
  assign invld_byte_off = rd_crtl_en ?  5'd16 -  (5'h8-(rd_pkt_ctrl.frm_fcs_ofst[0][2:0]==0 ? 8 : rd_pkt_ctrl.frm_fcs_ofst[0][2:0])) + dic_cnt_r  :'0;
  assign ln_cnt_ocpy    = rd_crtl_en &rd_pkt_ctrl.frm_end?  invld_byte_off%8>0 && invld_byte_off%8<4  ? invld_byte_off/8  :  (invld_byte_off/8)+1 :'0;
  assign dic_cnt        = invld_byte_off%8>0 && invld_byte_off%8<4  ? invld_byte_off%8  :   0  ;
  assign ipg_en_cnt     = 'd12 - dic_cnt + dic_cnt_r;
  assign num_ln_append  = rd_crtl_en  & rd_pkt_ctrl.frm_end ? ln_cnt_ocpy : 0;

  assign pf_aligner_ofst_c = pf_ln_cnt_avl>= (pf_aligner_ofst/*+extr_offset*/ + (pf_sof + (/*rd_crtl_en &rd_pkt_ctrl.frm_end ? 2:0*/ln_cnt_ocpy)))? 0
    : (pf_sof   +   pf_aligner_ofst  /*+extr_offset*/  + (ln_cnt_ocpy/*rd_crtl_en &rd_pkt_ctrl.frm_end? 2:0*/))-pf_ln_cnt_avl;
  assign pf_fcs_ofst = /*extr_offset*8+*/pf_sof*8 + pf_aligner_ofst*8   +  rd_pkt_ctrl.frm_fcs_ofst ;
  assign pf_efd_ofst = /*extr_offset*8+*/pf_sof*8 + pf_aligner_ofst*8   +  rd_pkt_ctrl.frm_fcs_ofst + 4 ;
  assign rd          = rd_crtl_en;

  always_comb
    begin
      idle_word_c = '0;
      idle_word_c[ii] = 8'hFD;
      for(int ii =1 ;ii<15;ii++)
        if(ii<ipg_en_cnt)
          idle_word_c[ii] = 8'h07;
    end

  always_ff @(posedge clk) begin
    if(rst) begin
      dic_cnt_r <= 0;
    end else if(rd_crtl_en&rd_pkt_ctrl.frm_end)begin
      dic_cnt_r <= dic_cnt;
    end
  end

  //flushing offset
  assign eop_late_c = pf_eof_d & pf_fcs_ofst_d[BYTE_CNT_W];
  assign crc_rd_en  = rd_pkt_ctrl.frm_end & rd_crtl_en & ~crc_empty;


  always_ff @(posedge clk) begin
    if(rst) begin
      pkt_crc <= 0;
    end else if(crc_rd_en)begin
      pkt_crc <= crc_rd_data ;
    end
  end

  always_ff @(posedge clk) begin:blk_ctrl_pipe
    pf_sof_d       <= pf_sof;
    pf_sof_d2      <= pf_sof_d;
    pf_sof_d3      <= pf_sof_d2;
    rd_crtl_en_d   <= rd_crtl_en;
    pf_eof_d       <= rd_crtl_en  &  rd_pkt_ctrl.frm_end;
    eop_late       <= pf_eof_d    &  pf_efd_ofst_d[BYTE_CNT_W];
    eop_late_r     <= eop_late ;
    eop_late_r2    <= eop_late_r ;
    //pf_fcs_ofst_late<= pf_eof_d    &  pf_fcs_ofst_d[BYTE_CNT_W] ? pf_fcs_ofst_d :  ;
    pf_eof_d2      <= pf_eof_d    & ~pf_efd_ofst_d[BYTE_CNT_W] /*| eop_late */;
    pf_eof_d3      <= pf_eof_d2;
    pf_fcs_ofst_d  <= pf_fcs_ofst;
    pf_fcs_ofst_r  <= pf_fcs_ofst;
    pf_efd_ofst_d  <= pf_efd_ofst;
    pf_fcs_ofst_r2 <= pf_efd_ofst_d;//pf_fcs_ofst_r;
    pf_fcs_ofst_r3 <= pf_fcs_ofst_r2;//pf_fcs_ofst_r2;
    idle_word      <= idle_word_c;
  end

  always_ff @(posedge clk) begin : i_proc_halt_rd;
    if(rst) begin
      halt_rd <= 0;
    end else begin
      halt_rd <= (rd_crtl_en && rd_pkt_ctrl.frm_end && pf_aligner_ofst_c>12) ;
    end
    halt_rd_r <= halt_rd;
  end

  always_ff @(posedge clk) begin : proc_aligner_ofst
    if(rst) begin
      pf_aligner_ofst <= '0;
    end
    else if(halt_rd | (eop_late_c& ~rd_crtl_en)) begin
      pf_aligner_ofst <= 0; // (sof + (i_data_axis_tvalid& i_data_axis_tlast ? 2:0)) - (i_data_axis_tvalid& i_data_axis_tlast ? ln_cnt_avl :0);
    end
    else if(pf_halt_wr)
      pf_aligner_ofst <= pf_curr_beat_ln;
    else if(rd_crtl_en) begin
      pf_aligner_ofst <= pf_aligner_ofst_c;// (sof + (i_data_axis_tvalid& i_data_axis_tlast ? 2:0)) - (i_data_axis_tvalid& i_data_axis_tlast ? ln_cnt_avl :0);
    end
    pf_aligner_ofst_d  <= pf_aligner_ofst;
    pf_aligner_ofst_d2 <= pf_aligner_ofst_d;
  end

  //aligment and merging special character
  always_ff @(posedge clk) begin : proc_pf_aligner_word
    if(rst) begin
      pf_aligner <= '0;
    end
    else if((halt_rd_r &~halt_rd)| (eop_late & ~rd_crtl_en_d))
      pf_aligner <= pf_aligner>>DWIDTH;
    else if(rd_crtl_en_d) begin
      pf_aligner <= (pf_aligner[31:16])                                 |
        (rd_data<<((pf_sof_d+pf_aligner_ofst_d)*64))                    |
        (pf_sof_d ? (SOF_WORD<< (pf_aligner_ofst_d)*64)  : '0)          |
        (pf_eof_d ? (({/*8'hFD,*/pkt_crc}<<(pf_fcs_ofst_d*8)|(idle_word<<((4+pf_fcs_ofst_d)*8))/*|(8'hFD<<((4+pf_fcs_ofst_d)*8))*/ )) : '0)  ;
    end
  end

  // output beat valid  reg
  always_ff @(posedge clk) begin : proc_pf_fifo_wr
    if(rst) begin
      out_beat_vld <= 0;
    end else begin
      out_beat_vld <= (halt_rd_r & ~halt_rd) ||rd_crtl_en_d ;
    end
  end

  assign pf_aligned = pf_aligner[15:0];

  assign pf_curr_beat_ln = (pf_aligner_ofst/*+extr_offset*/+ (rd_crtl_en &rd_pkt_ctrl.frm_sof) + (rd_pkt_ctrl.frm_num_ln))+
    (/*rd_crtl_en &rd_pkt_ctrl.frm_end ? 2:0*/ln_cnt_ocpy);

  //todo : need to udapte conditon as its usefull
  assign pf_halt_wr = 0;// rd_crtl_en &&(pf_aligner_ofst/*+extr_offset*/+(rd_crtl_en &rd_pkt_ctrl.frm_sof + (rd_pkt_ctrl.frm_num_ln))
  // + (rd_crtl_en &rd_pkt_ctrl.frm_end/*i_data_axis_tlast&& i_data_axis_tvalid & ~i_tready */? 2'b10:2'b00))<13;

  always_ff @(posedge clk) begin : proc_pf_halt_wr
    if(rst) begin
      pf_halt_wr_r <= 0;
    end else begin
      pf_halt_wr_r <= pf_halt_wr ;
    end
    pf_halt_wr_r2 <= pf_halt_wr_r;
  end

  logic [NUM_BYTE-1:0][8-1:0] mii_txd_c   ;
  logic [NUM_BYTE-1:0]        mii_txc_c   ;
  logic [NUM_BYTE-1:0][8-1:0] mii_txd     ;
  logic [NUM_BYTE-1:0]        mii_txc     ;
  logic [NUM_BYTE-1:0]        mii_ctrl    ;
  logic [  NUM_LN-1:0][8-1:0] mii_ctrl_dbg;
  logic [  NUM_LN-1:0][8-1:0] mii_txc_dbg ;
  logic [  NUM_LN-1:0][64-1:0] mii_txd_dbg ;
  logic [  NUM_LN-1:0]        sof_vld_ln  ;
  logic                       sof_vld     ;
  logic                       eof_vld     ;
  logic                       sof_vld_r   ;
  logic                       eof_vld_r   ;
  logic                       frm_inprg   ;
  logic                       ctrl_inprg  ;
  logic                       eof_vld_r_d ;
  logic                       frm_inprg_d ;
  logic                       ctrl_inprg_d;


  always_ff @(posedge clk) begin
    if(rst) begin
      frm_inprg <= 0;
      sof_vld_r <= 0;
      eof_vld_r <= 0;
    end else begin
      frm_inprg    <= 0 ;
      sof_vld_r    <= sof_vld;
      eof_vld_r    <= eof_vld & sof_vld;
      eof_vld_r_d  <= eof_vld_r;
      frm_inprg_d  <= frm_inprg;
      ctrl_inprg_d <= ctrl_inprg;
    end
  end

// localparam int NB = 128;
// logic [NB-1:0]   ev, px, in_frm, ev_s, ev_t, txc_c;
// logic [NB*8-1:0] txd_c;
// logic            carry_q;   //


// always_comb begin
//   ev = mii_ctrl;
//   // inclusive prefix XOR: px[i] = ^ev[i:0]
//   px = ev;
//   px = px ^ (px << 1);
//   px = px ^ (px << 2);
//   px = px ^ (px << 4);
//   px = px ^ (px << 8);
//   px = px ^ (px << 16);
//   px = px ^ (px << 32);
//   px = px ^ (px << 64);

//   // state BEFORE byte i (exclusive prefix, plus carry from the previous beat)
//   in_frm = {NB{carry_q}} ^ (px << 1);

//   ev_s  = ev & ~in_frm;                // marker seen outside a frame = FB
//   ev_t  = ev &  in_frm;                // marker seen inside a frame  = FD
//   txc_c = ~in_frm | ev;                // idle, S and T = 1; preamble, data and FCS = 0

//   for (int i = 0; i < NB; i++) begin
//     if      (ev_s[i])  txd_c[i*8 +: 8] = 8'hFB;
//     else if (ev_t[i])  txd_c[i*8 +: 8] = 8'hFD;
//     else if (txc_c[i]) txd_c[i*8 +: 8] = 8'h07;
//     else               txd_c[i*8 +: 8] = pf_aligned[i*8 +: 8];
//   end
// end

// always_ff @(posedge clk)
//   if (rst) carry_q <= 1'b0;
//   else     carry_q <= carry_q ^ px[NB-1];

//assert property (@(posedge clk) disable iff (rst) !(|(ev_s & in_frm)));
//assert property (@(posedge clk) disable iff (rst) !(|(ev_t & ~in_frm)));
//assert property (@(posedge clk) disable iff (rst) !(carry_q && !beat_vld));

  always_comb begin : proc_mii_adp
    sof_vld_ln   = 0;
    eof_vld      = 0;
    mii_txd_c    = {NUM_BYTE{8'h07}} ;//pf_aligned ;
    ctrl_inprg   = 0;
    mii_ctrl     = (pf_sof_d2<<(pf_aligner_ofst_d2*8)) | (pf_eof_d2<<((pf_fcs_ofst_r2))) | (eop_late_r<<((pf_fcs_ofst_r3)));
    mii_txc_c    = '1;// 0 ;
    sof_vld      = sof_vld_r;
    eof_vld      = eof_vld_r;
    mii_ctrl_dbg = mii_ctrl;
    for(int ln = 0 ; ln<NUM_LN;ln++)
      sof_vld_ln[ln] = out_beat_vld & SOF_WORD == pf_aligned[ln];
    for(int ii =0 ;  ii <NUM_BYTE ; ii++)
     
      if(mii_ctrl[ii]& ~sof_vld)
        begin
          mii_txc_c[ii] = 1;
          sof_vld       = 1;
          mii_txd_c[ii] = pf_aligned[ii/8][(ii%8)*8+:8];
        end
      else if(mii_ctrl[ii]& sof_vld)
        begin
          mii_txc_c[ii] = 1;
          sof_vld       = 0;
          mii_txd_c[ii] =pf_aligned[ii/8][(ii%8)*8+:8];
        end
    else if(sof_vld)
      begin
        mii_txc_c[ii] = 0;
        mii_txd_c[ii] = pf_aligned[ii/8][(ii%8)*8+:8];
        // sof_vld = 0;
      end
    mii_txc_dbg = mii_txc_c;
    mii_txd_dbg = mii_txd_c;
  end

  always_ff @(posedge clk) begin : proc_mii_blk
    if(rst) begin
      mii_txc <= '1;
      mii_txd <= {128{8'h07}};
    end
    else begin
      mii_txc    <= mii_txc_c;
      mii_txd   <=mii_txd_c;
    end
  end

function automatic logic [NUM_BYTE-1:0] pre_xor (input logic [NUM_BYTE-1:0] x);
  logic [NUM_BYTE-1:0] y;
  y = x;
  for (int s = 1; s < NUM_BYTE; s = s << 1)
    y = y ^ (y << s);
  return y;
endfunction

logic [NUM_BYTE-1:0]      mii_ctrlx;    
logic [NUM_BYTE-1:0]      ctrl_incl;    
logic [NUM_BYTE-1:0]      in_frm;       
logic                     frm_carry_q;  
logic [NUM_BYTE-1:0][7:0] pf_bytes;     

always_comb begin
  for (int i = 0; i < NUM_BYTE; i++)
    pf_bytes[i] = pf_aligned[i/8][(i%8)*8 +: 8];
  
  mii_ctrlx =NUM_BYTE'(pf_sof_d2)  << (pf_aligner_ofst_d2 * 8)
  | (NUM_BYTE'(pf_eof_d2)  << pf_fcs_ofst_r2) |
             (NUM_BYTE'(eop_late_r) << pf_fcs_ofst_r3);

  // ---- in-frame state: toggles on every marker, seeded by the carry ----
  ctrl_incl = prefix_xor(mii_ctrl);
  in_frm    = {ctrl_incl[NUM_BYTE-2:0], 1'b0} ^ {NUM_BYTE{frm_carry_q}};

  for (int i = 0; i < NUM_BYTE; i++) begin
    mii_txc_cx[i] = mii_ctrl[i] | ~in_frm[i];
    mii_txd_cx[i] = (mii_ctrl[i] | in_frm[i]) ? pf_bytes[i] : 8'h07;
  end
end

// ---- single-bit loop-carried state ----
always_ff @(posedge clk) begin
  if (rst) frm_carry_q <= 1'b0;
  else     frm_carry_q <= frm_carry_q ^ ctrl_incl[NUM_BYTE-1];   // parity of the whole beat
end

// ---- output register ----
always_ff @(posedge clk) begin
  if (rst) begin
    mii_txdx <= {NUM_BYTE{8'h07}};
    mii_txcx <= '1;
  end else begin
    mii_txdx <= mii_txd_cx;
    mii_txcx <= mii_txc_cx;
  end
end

/*`ifndef SYNTHESIS
  // no /S/ while a frame is open, no /T/ while none is open
  assert property (@(posedge clk) disable iff (rst)
    !(|(s_vec &  in_frm)) && !(|(t_vec & ~in_frm)));

  // /S/ only at byte 0 of a lane and carries FB; /T/ carries FD
  always_comb
    for (int i = 0; i < NUM_BYTE; i++) begin
      if (s_vec[i]) assert (i % 8 == 0 && pf_bytes[i] == 8'hFB);
      if (t_vec[i]) assert (pf_bytes[i] == 8'hFD);
    end

  // with store-and-forward, a frame must never be left open across an idle beat
  assert property (@(posedge clk) disable iff (rst)
    !out_beat_vld |-> !frm_carry_q);
`endif*/
 // if(mii_ctrl[ii] &  ~sof_vld & ~eof_vld)
      //   begin
      //   mii_txc_c[ii] = 1;
      //   sof_vld = 1;
      //   eof_vld = 0;
      //   end
      // else  if(mii_ctrl[ii] & sof_vld & ~eof_vld)
      //   begin
      //   mii_txc_c[ii] = 1;
      //   sof_vld = 0;
      //   eof_vld = 1;
      //   end
      // else  if(mii_ctrl[ii] &&eof_vld)
      //   begin
      //   mii_txc_c[ii] = 1;
      //   sof_vld = 1;
      //   eof_vld = 0;
      //   end
      // else  if(~mii_ctrl[ii] &&eof_vld)
      //   begin
      //   mii_txc_c[ii] = 1;
      //   // /sof_vld = 0;
      //   // /eof_vld = 0;
      //   end
  //assign pf_byte_cnt = tlast_lch & i_data_axis_tvalid& ~i_tready ? $countones(i_data_axis_tkeep) : i_data_axis_tvalid& ~i_tready ? $countones(i_data_axis_tkeep) + byte_cnt_r :byte_cnt_r;

  // always_ff @(posedge clk) begin : proc_byt_cnt_reg
  //   if(rst) begin
  //     byte_cnt_r   <= '0;
  //     byte_cnt_avl <= '0;
  //   end else if(i_data_axis_tvalid & ~i_tready)begin
  //     byte_cnt_r   <= byte_cnt;
  //     byte_cnt_avl <= NUM_BYTE-$countones(i_data_axis_tkeep);
  //   end
  // end

  //PER BEAT FIFO CTRL
  fwft_fifo_wrapper #(
    .DATA_WIDTH(CR_WIDTH),
    .DEPTH     (DEPTH   )
    //.FTHRESH   (DEPTH-2 ),
  // /  .LATENCY   (1       )
  ) ctrl_buff (
    .clk    (clk        ),
    .arst_n (arst_n     ),
    .wr_data(cr_wr_data ),
    .wr_en  (cr_wr_en   ),
    .full   (cr_full    ),
    .rd_data(rd_pkt_ctrl),
    .rd_en  (rd_crtl_en ),
    .empty  (cr_empty   )
  );


  logic                  i_tx_valid                                 ;
  logic [    DWIDTH-1:0] i_tx_data                                  ;
  logic [(DWIDTH/8)-1:0] i_tx_tkeep                                 ;
  logic                  i_tx_tlast                                 ;
  logic [          31:0] crc32_val                                  ;
  logic                  crc32_vld                                  ;
  localparam             NUM_STG    = 4                             ;
  logic                  in_vld     = in_reg_axis_tvalid&slave_ready;

//CRC COMPUTE ENGINE INST
  crc_compute_engine #(.STG(NUM_STG)) crc_compute_engine (
    .clk       (clk                                                               ),
    .arst_n    (~rst                                                              ),
    .i_sof_in  (in_reg_axis_sof/*tlast_lch_r &in_reg_axis_tvalid*/ /*& ~crc_full*/),
    .i_tx_valid(in_reg_axis_tvalid&slave_ready/*& ~crc_full*/                     ),
    .i_tx_data (in_reg_axis_tdata                                                 ),
    .i_tx_tkeep(in_reg_axis_tkeep                                                 ),
    .i_tx_tlast(in_reg_axis_tlast/*&  ~crc_full*/                                 ),
    .crc32_val (crc32_val                                                         ),
    .crc32_vld (crc32_vld                                                         )
  );


 //CRC BUFF
  fwft_fifo_wrapper #(
    .DATA_WIDTH(CRC_WIDTH),
    .DEPTH     (DEPTH    )
  ) crc_buff (
    .clk    (clk        ),
    .arst_n (arst_n     ),
    .wr_data(crc32_val  ),
    .wr_en  (crc32_vld  ),
    .full   (crc_full   ),
    .rd_data(crc_rd_data),
    .rd_en  (crc_rd_en  ),
    .empty  (crc_empty  )
  );

  //DATA BUFF
  assign cr_wr_en   = pkt_ctrl_r.frm_vld &slave_ready;
  assign cr_wr_data = pkt_ctrl_r;
  assign cr_rd_data = rd_pkt_ctrl;

  sfifo #(
    .DEPTH     (DEPTH    ),
    .DATA_WIDTH(DWIDTH   ),
    .LATENCY   (D_LATENCY)
  ) data_buff (
    .clk      (clk              ),
    .arst_n   (~rst             ),
    .wr       (cr_wr_en         ),
    .wr_data  (in_reg_axis_tdata),
    .full     (full             ),
    .tfull    (tfull            ),
    .ovf      (ovf              ),
    .rd       (rd               ),
    .rd_data  (rd_data          ),
    .empty    (empty            ),
    .tempty   (tempty           ),
    .udf      (udf              ),
    .num_vld  (num_vld          ),
    .init_done(init_done        ),
    .sec      (sec              ),
    .ded      (ded              )
  );

  // logic rst_n;
  // logic s_tvalid;
  // logic s_tready;
  // logic s_tlast;
  // logic [127:0] s_tkeep;
  // logic [128*8-1:0] txd;
  // logic [127:0] txc;
//    logic win_done;
//    logic [47:0] r_in_bytes;
//    logic [47:0] r_frames_in;
//    logic [47:0] r_out_bytes;
//    logic [47:0] r_frames_out;
//    logic [47:0] r_idle_bytes;
//    logic [47:0] r_idle_beats;
//    logic [47:0] r_stall_cycles;
// mac_bw_monitor i_mac_bw_monitor (
//   .clk           (clk           ),
//   .rst_n         (~rst         ),
//   .s_tvalid      (in_reg_axis_tvalid&slave_ready      ),
//   .s_tready      (slave_ready             ),
//   .s_tlast       (in_reg_axis_tlast       ),
//   .s_tkeep       (in_reg_axis_tkeep       ),
//   .txd           (mii_txd           ),
//   .txc           (mii_txc           ),
//   .win_done      (win_done      ),
//   .r_in_bytes    (r_in_bytes    ),
//   .r_frames_in   (r_frames_in   ),
//   .r_out_bytes   (r_out_bytes   ),
//   .r_frames_out  (r_frames_out  ),
//   .r_idle_bytes  (r_idle_bytes  ),
//   .r_idle_beats  (r_idle_beats  ),
//   .r_stall_cycles(r_stall_cycles)
// );


  logic rst_n;
  logic clear;
  logic report;
  logic s_tvalid;
  logic s_tready;
  logic s_tlast;
  logic [127:0] s_tkeep;
  logic [128*8-1:0] txd;
  logic [127:0] txc;
  logic[9:0] idle_cyc_cnt;
//always_ff @(posedge clk) begin 
//  for(int ii = 0 ; ii<100; ii++)
//
//end
always_ff @(posedge clk) begin 
  if(rst || (in_reg_axis_tvalid&&slave_ready)) begin
    idle_cyc_cnt<= 0;
  end
   else if(idle_cyc_cnt<300)begin
     idle_cyc_cnt<=idle_cyc_cnt+1 ;
  end
end
  
  

assign clear =0;
mac_bw_monitor mac_bw_monitor (
  .clk     (clk     ),
  .rst_n   (~rst    ),
  .clear   (clear   ),
  .report  (idle_cyc_cnt==300),
  .s_tvalid(in_reg_axis_tvalid),
  .s_tready(slave_ready),
  .s_tlast (in_reg_axis_tlast ),
  .s_tkeep (in_reg_axis_tkeep ),
  .txd     (mii_txd     ),
  .txc     (mii_txc     )
);




// For 800G, the MII is 1024 bits at 781.25 MHz, which is exactly 100 GB/s (128 B × 781.25 M). One clock cycle is 1.28 ns, so bits per ns equals Gb/s. That makes the math simple.

// //Max frame rate = 100e9 / (L + 24)
// //Ideal goodput = 800 Gb/s × L / (L + 24)
// //L Slot on wire  Max frame rate  Ideal goodput
// //60 (min, with pad)  84 B  1.19 Gfps 571.4 Gb/s
// //512 536 B 186.6 Mfps  764.2 Gb/s
// //1514  1538 B  65.0 Mfps 787.5 Gb/s
// //9000  9024 B  11.1 Mfps 797.9 Gb/s

// Computing the numbers (per window)

// With W = WINDOW cycles:

// Metric  Formula
// Input goodput (Gb/s)  r_in_bytes × 8 / (W × 1.28), which equals r_in_bytes × 6.25 / W
// Wire utilisation  1 − r_idle_bytes / (128 × W)
// Frame rate  r_frames_out / W × 781.25e6
// Efficiency vs ideal measured goodput ÷ 800 × L/(L+24) for a fixed L
// Backpressure ratio  r_stall_cycles / W
// Pass and fail checks
// No loss: r_frames_in == r_frames_out over a long run. A difference of 1 at window edges is normal, since a frame can straddle two windows.
// Byte conservation: r_out_bytes − 4 × r_frames_out ≈ r_in_bytes. Small drift comes from padding.
// Saturated input (tvalid always 1): r_idle_beats should be about 0, and goodput should be within about 0.5% of ideal at every L. If it isn't, the read-halt threshold or the packer stall is costing you cycles.
// Sanity: total wire bytes 128 × W = data + idle + control bytes. If they don't sum, your byte classification is wrong.
// Backpressure: if r_stall_cycles is high while r_idle_beats is also high, the FIFO is stalling the input while the output starves. That points to store-and-forward latency (waiting for tlast) or a FIFO that is too shallow for the frame size.
// Test matrix

// Run each for a few windows, with input saturated and no output backpressure:

// L = 60, fixed, which exercises DIC
// L = 61 to 68, one at a time, to sweep alignments
// L = 1514 and 9000
// IMIX (a 7:4:1 mix of 64 B, 594 B and 1518 B)
// Random L from 60 to 1514 with random tvalid gaps, where goodput should track the input rate

// If you'd like, I can write the matching cocotb test with a Python reference model for ideal goodput.


endmodule 