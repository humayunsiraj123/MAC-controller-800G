/*
================================================================================
USAGE GUIDE: tbps_crc_axis
================================================================================
This module wraps a CRC generator with AXI-Stream (AXIS) bus interfaces for easy integration.

Parameters:
// Implementation parameters:
- DWIDTH:     Data width in bits (must be a multiple of 8, e.g., 64, 512, 768)
- PIPE_LVL:   Number of pipeline stages for fmax/area/latency tradeoff
- REV_PIPE_EN_ONEHOT: Revert pipeline enable one-hot code, controls whether to register corresponding revert pipeline stages
there are log2(DWIDTH/8) revert stages, by default, all pipeline stages are registered
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
  localparam     DEPTH      = 128                         ; //minimum depth reuried is 78 beat for close bram 2^n
  localparam     D_LATENCY  = 1                           ;
  localparam     CR_WIDTH   = $bits(in_ctrl_t)            ; //20;

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


//localparam CRC_WIDTH = 32;
  logic                 crc_wr_en  ;
  logic                 crc_rd_en  ;
  logic [CRC_WIDTH-1:0] crc_wr_data;

  always_ff @(posedge clk) begin : proc_rand_crc
    crc_wr_data <= $urandom_range(32'hAAAAAAAA,32'hfffffff0);
  end

  logic [CRC_WIDTH-1:0] crc_rd_data;
  logic                 crc_full   ;
  logic                 crc_empty  ;
  logic                 eop_late   ;
  logic                 eop_late_c ;
  logic                 eop_late_r ;
  logic                 eop_late_r2;





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


  logic                cr_wr_en  ;
  logic                cr_rd_en  ;
  logic [CR_WIDTH-1:0] cr_wr_data;
  logic [CR_WIDTH-1:0] cr_rd_data;

  logic cr_full ;
  logic cr_empty;
//reading  user reading reg
//TODO : need to udapt the logic
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
        in_reg_axis_tdata       <= '0;// i_data_axis_tkeep[ii]?i_data_axis_tdata[8*ii+:8] : '0;
        in_reg_axis_sof         <= 0;
      end
    else if(slave_ready&i_data_axis_tvalid)
      begin
        for(int ii =0 ; ii<NUM_BYTE; ii++)
          in_reg_axis_tdata[ii/8][(ii%8)*8+:8] <= i_data_axis_tkeep[ii]?i_data_axis_tdata[8*ii+:8] : '0;

        in_reg_axis_tkeep       <= i_data_axis_tvalid ? i_data_axis_tkeep :  0;
        in_reg_axis_tlast       <= i_data_axis_tvalid & i_data_axis_tlast ;
        in_reg_axis_tvalid      <= i_data_axis_tvalid ; //& ~tfull  /*~i_tready*/;
        pkt_ctrl_r.frm_vld      <= i_data_axis_tvalid ; //&  ~tfull /*~i_tready*/ ;
        pkt_ctrl_r.frm_end      <= i_data_axis_tvalid  & i_data_axis_tlast ; //& ~tfull  /*~i_tready*/  & i_data_axis_tlast ;
        pkt_ctrl_r.frm_num_ln   <= byte_cnt_c[BYTE_CNT_W:3] + |byte_cnt_c[2:0]             ;
        pkt_ctrl_r.frm_fcs_ofst <= byte_cnt_c;
        pkt_ctrl_r.frm_sof      <= tlast_lch_r & i_data_axis_tvalid/*& ~tfull*/ /*~i_tready*/;
        in_reg_axis_sof         <= tlast_lch_r & i_data_axis_tvalid;
      end
    else if(slave_ready)
      begin
        in_reg_axis_tvalid <= 0;//i_data_axis_tvalid ; //& ~tfull  /*~i_tready*/;
        pkt_ctrl_r.frm_vld <= 0;//i_data_axis_tvalid ; //&  ~tfull /*~i_tready*/ ;
      end



    // /pkt_ctrl_pf.frm_end[0]     <=
    // /pkt_ctrl_pf.frm_end[1]     <=
    // /pkt_ctrl_pf.frm_num_ln[0]  <= aligner_ofst;
    // /pkt_ctrl_pf.frm_num_ln[1]  <=
    // /pkt_ctrl_pf.frm_fcs_ofst[0]<=
    // /pkt_ctrl_pf.frm_fcs_ofst[1]<=

  end
  assign bp_user = ~tfull;
//==================================================================================================================================================================
//                                                                PRE FIFO  logic
//==================================================================================================================================================================

  assign sof         = tlast_lch & i_data_axis_tvalid&~i_tready;
  assign extr_offset = 0;//(aligner_ofst>2 & sof & i_data_axis_tvalid&i_data_axis_tlast & (byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst)<16) ? 16 -(byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst) : 0;
  assign sof_ofst    = aligner_ofst ;
  assign fcs_ofst    = extr_offset*8+sof*8 + aligner_ofst*8 + $countones(i_data_axis_tkeep) ;

//   assign pkt_ctrl.frm_vld      = '0;
//   assign pkt_ctrl.frm_end      = '0;
//   assign pkt_ctrl.frm_num_ln   = '0;
//   assign pkt_ctrl.frm_fcs_ofst = fcs_ofst;

  always_ff @(posedge clk) begin : proc_fsc_reg
    if(rst) begin
      fcs_ofst_r <= '0;
    end else begin
      fcs_ofst_r <= fcs_ofst;
    end
  end


  always_ff @(posedge clk) begin : proc_aligner_word
    if(rst) begin
      aligner  <= '0;
      aligner1 <= '0;
      aligner2 <= '0;
      aligner3 <= '0;
    end
    // else if(halt_wr_r)
    //   aligner<=aligner;
    else if(~i_tready_r &  i_tready)
      aligner <= aligner>>DWIDTH;
    else if(i_data_axis_tvalid & ~i_tready) begin
      aligner <= (halt_wr_r ? aligner[15:0]: aligner[31:16])        |
        (dbg_data_axis_tdata<<((sof+aligner_ofst +extr_offset)*64)) |
        (sof ? (SOF_WORD<< (extr_offset+aligner_ofst)*64)  : '0)    |
        (i_data_axis_tvalid& ~i_tready& i_data_axis_tlast ? ((32'hffffffff<<(fcs_ofst*8)|(IDLE_WORD<<((4+fcs_ofst)*8)))) : '0)  ;
      // aligner1<= aligner[31:16]  ;
      // aligner2<=((dbg_data_axis_tdata<<((sof+aligner_ofst)*64)));
      // aligner3<= (sof ? (SOF_WORD<<(aligner_ofst*64)) : '0);
    end
  end

  assign aligned = aligner[15:0];


  always_ff @(posedge clk) begin : proc_fifo_wr
    if(rst) begin
      wr_vld <= 0;
    end else begin
      wr_vld <= halt_wr_r||(~halt_wr &i_data_axis_tvalid& ~i_tready) ||  (i_tready &  ~i_tready);
    end
  end

  assign aligner_ofst_c = ln_cnt_avl>= (sof+ aligner_ofst+extr_offset +(i_data_axis_tvalid& ~i_tready& i_data_axis_tlast ? 2:0))? 0
    :              (sof+ aligner_ofst+extr_offset +(i_data_axis_tvalid& ~i_tready& i_data_axis_tlast ? 2:0))- ln_cnt_avl;

  always_ff @(posedge clk) begin : i_proc_tready;
    if(rst) begin
      i_tready <= 0;
    end else begin
      i_tready <= (i_data_axis_tvalid & ~i_tready& i_data_axis_tlast && aligner_ofst_c>12) ;
    end
    i_tready_r <= i_tready;
  end

  always_ff @(posedge clk) begin : proc_alginer_ofst
    if(rst) begin
      aligner_ofst <= '0;
    end
    else if(i_tready) begin
      aligner_ofst <= 0;// (sof + (i_data_axis_tvalid& i_data_axis_tlast ? 2:0)) - (i_data_axis_tvalid& i_data_axis_tlast ? ln_cnt_avl :0);
    end
    else if(halt_wr)
      aligner_ofst <= curr_beat_ln;
    else if(i_data_axis_tvalid& ~i_tready) begin
      aligner_ofst <= aligner_ofst_c;// (sof + (i_data_axis_tvalid& i_data_axis_tlast ? 2:0)) - (i_data_axis_tvalid& i_data_axis_tlast ? ln_cnt_avl :0);
    end
  end

  always_ff @(posedge clk) begin : proc_tlast_lthc
    if(rst) begin
      tlast_lch <= 1;
    end else if(i_data_axis_tvalid& ~i_tready) begin
      tlast_lch <= i_data_axis_tvalid & i_data_axis_tlast   ;
    end
  end


  assign ln_cnt_avl   = NUM_LN -     (/*i_tready ?   :*/(byte_cnt_c[BYTE_CNT_W:3] + |byte_cnt_c[2:0]));
  assign curr_beat_ln = (aligner_ofst+extr_offset+sof + (byte_cnt_c[BYTE_CNT_W:3] + |byte_cnt_c[2:0]))+
    (i_data_axis_tlast&& i_data_axis_tvalid & ~i_tready ? 2'b10:2'b00);
  assign halt_wr = ~i_tready&& i_data_axis_tvalid&(aligner_ofst+extr_offset+(sof + (byte_cnt_c[BYTE_CNT_W:3] + |byte_cnt_c[2:0]))
    + (i_data_axis_tlast&& i_data_axis_tvalid & ~i_tready ? 2'b10:2'b00))<13;

  always_ff @(posedge clk) begin : proc_halt_wr
    if(rst) begin
      halt_wr_r <= 0;
    end else begin
      halt_wr_r <= halt_wr ;
    end
  end

  assign byte_cnt = tlast_lch & i_data_axis_tvalid& ~i_tready ? $countones(i_data_axis_tkeep) : i_data_axis_tvalid& ~i_tready ? $countones(i_data_axis_tkeep) + byte_cnt_r :byte_cnt_r;

  always_ff @(posedge clk) begin : proc_byt_cnt_reg
    if(rst) begin
      byte_cnt_r   <= '0;
      byte_cnt_avl <= '0;
    end else if(i_data_axis_tvalid & ~i_tready)begin
      byte_cnt_r   <= byte_cnt;
      byte_cnt_avl <= NUM_BYTE-$countones(i_data_axis_tkeep);
    end
  end




//==================================================================================================================================================================
//                                                                Main logic
//==================================================================================================================================================================



  // assign bp_user = ~i_tready;

  //  assign pkt_ctrl.frm_vld      = '0;
  //  assign pkt_ctrl.frm_end      = '0;
  //  assign pkt_ctrl.frm_num_ln   = '0;
  //  assign pkt_ctrl.frm_fcs_ofst = fcs_ofst;

  // always_ff @(posedge clk) begin : proc_fsc_reg
  //   if(rst) begin
  //     fcs_ofst_r <= '0;
  //   end else begin
  //     fcs_ofst_r <= fcs_ofst;
  //   end
  // end


  //assign sof_ofst   = pf_aligner_ofst ;
//////////////////////////////////////////////TODO: ALIGNEMNT FOR FD BYTE
  //todo:
  //assign cr_rd_en   = ~cr_empty;

  assign pf_ln_cnt_avl     = NUM_LN - rd_pkt_ctrl.frm_num_ln;
  assign rd_crtl_en        = ~halt_rd &  ~cr_empty  & ~crc_empty;
  assign pf_sof            = rd_crtl_en&& rd_pkt_ctrl.frm_sof;
  assign pf_extr_offset    = 0;//(aligner_ofst>2 & sof & i_data_axis_tvalid&i_data_axis_tlast & (byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst)<16) ? 16 -(byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst) : 0;
  assign pf_aligner_ofst_c = pf_ln_cnt_avl>= (pf_aligner_ofst/*+extr_offset*/ + (pf_sof + (rd_crtl_en &rd_pkt_ctrl.frm_end ? 2:0)))? 0
    : (pf_sof   +   pf_aligner_ofst  /*+extr_offset*/  + (rd_crtl_en &rd_pkt_ctrl.frm_end? 2:0))-pf_ln_cnt_avl;
  assign pf_fcs_ofst = /*extr_offset*8+*/pf_sof*8 + pf_aligner_ofst*8   +  rd_pkt_ctrl.frm_fcs_ofst ;
  assign rd          = rd_crtl_en;
  //flushing offset
  assign eop_late_c = pf_eof_d & pf_fcs_ofst_d[BYTE_CNT_W];

  assign crc_rd_en = rd_pkt_ctrl.frm_vld & rd_pkt_ctrl.frm_end & rd_crtl_en & ~crc_empty;

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
    eop_late       <= pf_eof_d    &  pf_fcs_ofst_d[BYTE_CNT_W];
    eop_late_r     <= eop_late ;
    eop_late_r2    <= eop_late_r ;
    //pf_fcs_ofst_late<= pf_eof_d    &  pf_fcs_ofst_d[BYTE_CNT_W] ? pf_fcs_ofst_d :  ;
    pf_eof_d2      <= pf_eof_d   & ~pf_fcs_ofst_d[BYTE_CNT_W] /*| eop_late */;
    pf_eof_d3      <= pf_eof_d2;
    pf_fcs_ofst_d  <= pf_fcs_ofst;
    pf_fcs_ofst_r  <= pf_fcs_ofst;
    pf_fcs_ofst_r2 <= pf_fcs_ofst_r;
    pf_fcs_ofst_r3 <= pf_fcs_ofst_r2;
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
      pf_aligner_ofst <= 0;// (sof + (i_data_axis_tvalid& i_data_axis_tlast ? 2:0)) - (i_data_axis_tvalid& i_data_axis_tlast ? ln_cnt_avl :0);
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
      pf_aligner <= (/*halt_wr_r ? pf_aligner[15:0]:*/ pf_aligner[31:16])               |
        (rd_data<<((pf_sof_d+pf_aligner_ofst_d /*+extr_offset*/)*64))                   |
        (pf_sof_d ? (SOF_WORD<< (/*extr_offset+*/pf_aligner_ofst_d)*64)  : '0)          |
        (pf_eof_d ? ((pkt_crc<<(pf_fcs_ofst_d*8)|(88'(IDLE_WORD)<<((5+pf_fcs_ofst_d)*8))|(8'hFD<<((4+pf_fcs_ofst_d)*8)) )) : '0)  ;
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
    (rd_crtl_en &rd_pkt_ctrl.frm_end ? 2:0);

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

  logic [NUM_BYTE-1:0][8-1:0] mii_txd    ;
  logic [NUM_BYTE-1:0]        mii_txc    ;
  logic [NUM_BYTE-1:0]        mii_ctrl   ;
  logic [  NUM_LN-1:0][8-1:0] mii_txc_dbg;
  logic [  NUM_LN-1:0]        sof_vld_ln ;
  logic                       eof_vld    ;
  logic                       frm_inprg  ;
  logic                       ctrl_inprg ;


  always_ff @(posedge clk) begin
    if(rst) begin
      frm_inprg <= 0;
    end else begin
      frm_inprg <= 0 ;
    end
  end

  always_comb begin : proc_mii_adp
    sof_vld_ln = 0;
    eof_vld    = 0;
    mii_txd    = pf_aligned ;
    ctrl_inprg = 0 ;
    mii_ctrl   = (pf_sof_d2<<(pf_aligner_ofst_d2*8)) | (pf_eof_d2<<((pf_fcs_ofst_r2+5))) | (eop_late_r<<((pf_fcs_ofst_r3+5)));
    mii_txc    = 0 ;
    for(int ln = 0 ; ln<NUM_LN;ln++)
      sof_vld_ln[ln] = out_beat_vld & SOF_WORD == pf_aligned[ln];
    for(int ii =0  ;  ii <NUM_BYTE ; ii++)
      if(mii_ctrl[ii] &~ctrl_inprg)
        begin
          mii_txc[ii] = 1;
          ctrl_inprg  = 1;
        end
      else if(ctrl_inprg && mii_ctrl[ii])
        begin
          mii_txc[ii] = 1;
          ctrl_inprg  = 1;
        end
    // else if(ctrl_inprg &&mii_ctrl[ii])
    //   begin
    //     mii_txc[ii] = 1;
    //     ctrl_inprg  = 0;
    //   end
    //for(int ii=0 ; ii<NUM_BYTE;ii++)
    mii_txc_dbg = mii_txc;

  end



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
    .DEPTH     (DEPTH   ),
    .LATENCY   (1       )
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


  logic                  i_tx_valid    ;
  logic [    DWIDTH-1:0] i_tx_data     ;
  logic [(DWIDTH/8)-1:0] i_tx_tkeep    ;
  logic                  i_tx_tlast    ;
  logic [          31:0] crc32_val     ;
  logic                  crc32_vld     ;
  localparam             NUM_STG    = 4;

//CRC COMPUTE ENGINE INST
  crc_compute_engine #(.STG(NUM_STG)) crc_compute_engine (
    .clk       (clk                                                                                   ),
    .arst_n    (~rst                                                                                  ),
    .i_sof_in  (in_reg_axis_sof& in_reg_axis_tvalid/*tlast_lch_r &in_reg_axis_tvalid*/ /*& ~crc_full*/),
    .i_tx_valid(in_reg_axis_tvalid/*& ~crc_full*/                                                     ),
    .i_tx_data (in_reg_axis_tdata                                                                     ),
    .i_tx_tkeep(in_reg_axis_tkeep                                                                     ),
    .i_tx_tlast(in_reg_axis_tlast& in_reg_axis_tvalid/*&  ~crc_full*/                                 ),
    .crc32_val (crc32_val                                                                             ),
    .crc32_vld (crc32_vld                                                                             )
  );


//CRC BUFF
  fwft_fifo_wrapper #(
    .DATA_WIDTH(CRC_WIDTH),
    .DEPTH     (DEPTH    ),
    .LATENCY   (1        )
  ) crc_buff (
    .clk    (clk        ),
    .arst_n (arst_n     ),
    .wr_data(crc_wr_data),
    .wr_en  (crc32_vld  ),
    .full   (crc_full   ),
    .rd_data(crc_rd_data),
    .rd_en  (crc_rd_en  ),
    .empty  (crc_empty  )
  );


  //DATA BUFF
  assign cr_wr_en   = pkt_ctrl_r.frm_vld;
  assign cr_wr_data = pkt_ctrl_r;
  assign cr_rd_data = rd_pkt_ctrl;

  sfifo #(
    .DEPTH     (DEPTH    ),
    .DATA_WIDTH(DWIDTH   ),
    .LATENCY   (D_LATENCY)
  ) data_buff (
    .clk      (clk               ),
    .arst_n   (~rst              ),
    .wr       (in_reg_axis_tvalid),
    .wr_data  (in_reg_axis_tdata ),
    .full     (full              ),
    .tfull    (tfull             ),
    .ovf      (ovf               ),
    .rd       (rd                ),
    .rd_data  (rd_data           ),
    .empty    (empty             ),
    .tempty   (tempty            ),
    .udf      (udf               ),
    .num_vld  (num_vld           ),
    .init_done(init_done         ),
    .sec      (sec               ),
    .ded      (ded               )
  );


endmodule 