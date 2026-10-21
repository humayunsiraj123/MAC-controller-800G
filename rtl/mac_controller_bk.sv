`timescale 1ps / 1ps
module mac_controller
 #(
  parameter int DWIDTH             = 1024        ,
  parameter int CRC_WIDTH          = 32          ,
  parameter     CRC_POLY           = 16'hda5f
) (
  // Clock signal
  input  logic                 clk               ,
  // Synchronous reset (active high)
  input  logic                 rst               ,
  // AXIS input data bus
  input  logic [   DWIDTH-1:0] i_axis_tdata ,
  // AXIS input byte enable mask
  input  logic [ DWIDTH/8-1:0] i_axis_tkeep ,
  // AXIS input last signal (asserted on last data beat)
  input  logic                 i_axis_tlast ,
  // AXIS input valid strobe
  input  logic                 i_axis_tvalid,
  // AXIS input user data
  input  logic [ DWIDTH/8:0]   i_axis_user, //msb carries sop lsb valdi data bytes 
  // AXIS slave tready 
  output logic                 i_axis_tready,
    // CRC initial value
  input  logic [CRC_WIDTH-1:0] crc_init_val      ,
  // Value to XOR with CRC result before output
  input  logic [CRC_WIDTH-1:0] xor_out           ,
  // Reflect input bytes (bit reversal per byte)
  input  logic                 ref_in            ,
  // Reflect output CRC (bit reversal)
  input  logic                 ref_out           ,
  //MII intf signals
  output logic [   DWIDTH-1:0] o_mii_txd  ,
  output logic [ DWIDTH/8-1:0] o_mii_txc  
);
  logic i_tready;
  // Instantiate the CRC generator, directly connecting wrapper ports
  logic [(DWIDTH/64)-1:0][64-1:0] dbg_data_axis_tdata;
  // AXIS  byte enable mask
  logic [(DWIDTH/64)-1:0][8-1:0] dbg_data_axis_tkeep;

  assign dbg_data_axis_tdata = i_axis_tdata;
  assign dbg_data_axis_tkeep = /*i_axis_tkeep*/i_axis_user;

  localparam     NUM_BYTE   = DWIDTH/8                   ;
  localparam     NUM_LN     = DWIDTH/64                  ;
  localparam     BYTE_CNT_W = $clog2(NUM_BYTE)           ;
  localparam     LN_CNT_W   = $clog2(NUM_LN)             ;
  localparam     logic [64-1:0] SOF_WORD   = 64'hD5_55_55_55_55_55_55_FB;
  localparam     NUM_STG    = 4                          ;
  localparam     DEPTH      = 128                        ; //minimum depth reuried is 78 beat for close bram 2^n
  localparam     D_LATENCY  = 1                          ;

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
  localparam  CR_WIDTH   = $bits(in_ctrl_t); //20;
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
  in_ctrl_t                      pf_pkt_ctrl_r     ;
  in_ctrl_t                      pf_rd_pkt_ctrl    ;
  in_ctrl_t                      pf_pkt_ctrl       ;
  ctrl_t                         pf_pkt_ctrl_pf    ;
  logic [ CRC_WIDTH-1:0]         pkt_crc           ;
  logic                          halt_rd           ;
  logic                          halt_rd_r         ;
  logic                          eop_late          ;
  logic                          eop_late_c        ;
  logic                          eop_late_r        ;
  logic                          eop_late_r2       ;
  logic [          31:0] crc32_val                                  ;
  logic                  crc32_vld                                  ;
  
  logic                  in_vld     = in_reg_axis_tvalid&slave_ready;

  logic [   1:0]      num_ln_append ;
  logic [15-1:0][7:0] idle_word_c   ;
  logic [15-1:0][7:0] idle_word     ;
  logic [   3:0]      ipg_en_cnt    ;
  logic [   1:0]      ln_cnt_ocpy   ;
  logic [   1:0]      dic_cnt       ;
  logic [   1:0]      dic_cnt_r     ;
  logic [   4:0]      invld_byte_off;

  logic                 crc_wr_en  ;
  logic                 crc_rd_en  ;
  logic [CRC_WIDTH-1:0] crc_wr_data;
  logic [CRC_WIDTH-1:0] crc_rd_data;
  logic                 crc_full   ;
  logic                 crc_empty  ;

  logic  arst_n;
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

  
  logic                cr_wr_en                     ;
  logic                cr_rd_en                     ;
  logic [CR_WIDTH-1:0] cr_wr_data                   ;
  logic [CR_WIDTH-1:0] cr_rd_data                   ;

  logic cr_full ;
  logic cr_empty;

  logic [31:0]  fcs_cnt;
  logic [31:0]  start_cnt;

//==================================================================================================================================================================
//                                                               AXI-Slave Logic 
//==================================================================================================================================================================
  
  assign byte_cnt_c = $countones(/*i_axis_tkeep*/i_axis_user[NUM_BYTE-1:0]) ;

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
    else if(slave_ready&i_axis_tvalid)
      begin
        for(int ii =0 ; ii<NUM_BYTE; ii++)
          in_reg_axis_tdata[ii/8][(ii%8)*8+:8] <=  /*i_axis_tkeep*/i_axis_user[ii]?i_axis_tdata[8*ii+:8] : '0;
        in_reg_axis_tkeep       <= i_axis_tvalid ? /*i_axis_tkeep*/i_axis_user :  0;
        in_reg_axis_tlast       <= i_axis_tvalid & i_axis_tlast ;
        in_reg_axis_tvalid      <= i_axis_tvalid ;
        in_reg_axis_sof         <= i_axis_user[NUM_BYTE] /*tlast_lch_r*/ & i_axis_tvalid;
        pkt_ctrl_r.frm_vld      <= i_axis_tvalid ;
        pkt_ctrl_r.frm_end      <= i_axis_tvalid  & i_axis_tlast ;
        pkt_ctrl_r.frm_num_ln   <= byte_cnt_c[BYTE_CNT_W:3] + |byte_cnt_c[2:0]             ;
        pkt_ctrl_r.frm_fcs_ofst <= byte_cnt_c;
        pkt_ctrl_r.frm_sof      <= i_axis_user[NUM_BYTE] /*tlast_lch_r*/ & i_axis_tvalid;
      end
    else if(slave_ready)
      begin
        in_reg_axis_tvalid <= 0;
        pkt_ctrl_r.frm_vld <= 0;
      end
  end
  assign i_axis_tready = ~tfull;

  always_ff @(posedge clk) begin : proc_tlast_lch_r
    if(rst) begin
      tlast_lch_r <= 1;
    end else if(i_axis_tvalid & i_axis_tready/*& ~i_tready*/) begin
      tlast_lch_r <= i_axis_tvalid & i_axis_tlast ;
    end
  end


//==================================================================================================================================================================
//                                                               Control & Data Buffer Instances  
//==================================================================================================================================================================

  assign cr_wr_en   = pkt_ctrl_r.frm_vld &slave_ready;
  assign cr_wr_data = pkt_ctrl_r;
  assign cr_rd_data = rd_pkt_ctrl;

 //PER BEAT FIFO CTRL
  fwft_fifo_wrapper #(
    .DATA_WIDTH(CR_WIDTH),
    .DEPTH     (DEPTH   )
    //.FTHRESH   (DEPTH-2 ),
  // /  .LATENCY   (1       )
  ) ctrl_buff (
    .clk    (clk        ),
    .rst    (rst     ),
    .wr_data(cr_wr_data ),
    .wr_en  (cr_wr_en   ),
    .full   (cr_full    ),
    .rd_data(rd_pkt_ctrl),
    .rd_en  (rd_crtl_en ),
    .empty  (cr_empty   )
  );
  //DATA BUFF
  
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

//==================================================================================================================================================================
//                                            CRC-32 Computation Engine & Buffer  Instance 
//==================================================================================================================================================================
//CRC COMPUTE ENGINE INST
crc_compute_engine #(.STG(NUM_STG)) crc_compute_engine (
  .clk       (clk                           ),
  .rst       (rst                           ),
  .i_sof_in  (in_reg_axis_sof               ),
  .i_tx_valid(in_reg_axis_tvalid&slave_ready),
  .i_tx_data (in_reg_axis_tdata             ),
  .i_tx_tkeep(in_reg_axis_tkeep             ),
  .i_tx_tlast(in_reg_axis_tlast             ),
  .crc32_val (crc32_val                     ),
  .crc32_vld (crc32_vld                     )
);


 //CRC BUFF
  fwft_fifo_wrapper #(
    .DATA_WIDTH(CRC_WIDTH),
    .DEPTH     (DEPTH    )
  ) crc_buff (
    .clk    (clk        ),
    .rst    (rst     ),
    .wr_data(crc32_val  ),
    .wr_en  (crc32_vld  ),
    .full   (crc_full   ),
    .rd_data(crc_rd_data),
    .rd_en  (crc_rd_en  ),
    .empty  (crc_empty  )
  );


//==================================================================================================================================================================
//                                                              ENCAPSULATION LOGIC
//==================================================================================================================================================================

  assign pf_ln_cnt_avl  = NUM_LN - rd_pkt_ctrl.frm_num_ln;
  assign rd_crtl_en     = ~halt_rd &  ~cr_empty  & ~crc_empty;
  assign pf_sof         = rd_crtl_en&& rd_pkt_ctrl.frm_sof;

  //(aligner_ofst>2 & sof & i_axis_tvalid&i_axis_tlast & (byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst)<16) ? 16 -(byte_cnt_c[BYTE_CNT_W:3]+sof +aligner_ofst) : 0;
  assign pf_extr_offset = 0;
//todo ipg FD+ 
  assign invld_byte_off = rd_crtl_en ?  5'd16 - (5'h8-(rd_pkt_ctrl.frm_fcs_ofst[0][2:0]==0 ? 8 : rd_pkt_ctrl.frm_fcs_ofst[0][2:0])) + dic_cnt_r  :'0;
  assign ln_cnt_ocpy    = rd_crtl_en & rd_pkt_ctrl.frm_end?  /*invld_byte_off%8>0 && */invld_byte_off%8<4  ? invld_byte_off/8  :  (invld_byte_off/8)+1 :'0;
  assign num_ln_append  = rd_crtl_en  & rd_pkt_ctrl.frm_end ? ln_cnt_ocpy : 0;
  assign pf_aligner_ofst_c = pf_ln_cnt_avl>= (pf_aligner_ofst  + pf_extr_offset + (pf_sof + (ln_cnt_ocpy)))? 0
                           : (pf_sof   +      pf_aligner_ofst  + pf_extr_offset + (ln_cnt_ocpy))-pf_ln_cnt_avl;
  assign pf_fcs_ofst = pf_extr_offset*8+  pf_sof*8 + pf_aligner_ofst*8   +  rd_pkt_ctrl.frm_fcs_ofst ;
  assign pf_efd_ofst = pf_extr_offset*8+  pf_sof*8 + pf_aligner_ofst*8   +  rd_pkt_ctrl.frm_fcs_ofst + 4 ;
  assign rd          = rd_crtl_en;

  assign dic_cnt        = /*invld_byte_off%8>0 &&*/ invld_byte_off%8<4  ? invld_byte_off%8  :   0  ;
  assign ipg_en_cnt     = 'd12 - dic_cnt + dic_cnt_r;

  always_comb
    begin
      idle_word_c = '0;
      idle_word_c[0] = 8'hFD;
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
      pf_aligner_ofst <= 0;
    end
    else if(pf_halt_wr)
      pf_aligner_ofst <= pf_curr_beat_ln;
    else if(rd_crtl_en) begin
      pf_aligner_ofst <= pf_aligner_ofst_c;// (sof + (i_axis_tvalid& i_axis_tlast ? 2:0)) - (i_axis_tvalid& i_axis_tlast ? ln_cnt_avl :0);
    end
    pf_aligner_ofst_d  <= pf_aligner_ofst;
    pf_aligner_ofst_d2 <= pf_aligner_ofst_d;
  end

  //aligment and merging special character
  always_ff @(posedge clk) begin : proc_pf_aligner_word
    if(rst) begin
      pf_aligner <= '0;
    end
    else if((halt_rd_r &~halt_rd) | (eop_late & ~rd_crtl_en_d))
      pf_aligner <= pf_aligner>>DWIDTH;
    else if(rd_crtl_en_d) begin
      pf_aligner <= (pf_aligner[31:16])                       |
        (rd_data<<((pf_sof_d+pf_aligner_ofst_d)*64))          |
        (pf_sof_d ? (SOF_WORD<< (pf_aligner_ofst_d)*64)  : '0)|
        (pf_eof_d ? (({/*8'hFD,*/pkt_crc}<<(pf_fcs_ofst_d*8)  |(idle_word<<((4+pf_fcs_ofst_d)*8)))) :'0)  ;
    end
  end

always_ff @(posedge clk) begin 
  if(rst) begin
    fcs_cnt   <='0;
    start_cnt <= '0;
  end else begin
    fcs_cnt   <=fcs_cnt  +pf_sof_d;
    start_cnt <=start_cnt+pf_eof_d;
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

  assign pf_curr_beat_ln = (pf_aligner_ofst/*+extr_offset*/+ (rd_crtl_en &rd_pkt_ctrl.frm_sof) + (rd_pkt_ctrl.frm_num_ln))+(ln_cnt_ocpy);

  //todo : need to udapte conditon 
  assign pf_halt_wr = 0;// rd_crtl_en &&(pf_aligner_ofst/*+extr_offset*/+(rd_crtl_en &rd_pkt_ctrl.frm_sof + (rd_pkt_ctrl.frm_num_ln))
  // + (rd_crtl_en &rd_pkt_ctrl.frm_end/*i_axis_tlast&& i_axis_tvalid & ~i_tready */? 2'b10:2'b00))<13;

  always_ff @(posedge clk) begin : proc_pf_halt_wr
    if(rst) begin
      pf_halt_wr_r <= 0;
    end else begin
      pf_halt_wr_r <= pf_halt_wr ;
    end
    pf_halt_wr_r2 <= pf_halt_wr_r;
  end


//==================================================================================================================================================================
//                                                             MII INTF LOGIC
//==================================================================================================================================================================


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


function automatic logic [NUM_BYTE-1:0] pre_xor (input logic [NUM_BYTE-1:0] x);
  logic [NUM_BYTE-1:0] y;
  y = x;
  for (int s = 1; s < NUM_BYTE; s = s << 1)
    y = y ^ (y << s);
  return y;
endfunction

  logic [NUM_BYTE-1:0][8-1:0] mii_txd_cx   ;
  logic [NUM_BYTE-1:0]        mii_txc_cx   ;
  logic [NUM_BYTE-1:0][8-1:0] mii_txdx     ;
  logic [NUM_BYTE-1:0]        mii_txcx     ;
  logic [NUM_BYTE-1:0]        mii_ctrlx    ;
  logic [  NUM_LN-1:0][8-1:0]   mii_ctrl_dbgx;
  logic [  NUM_LN-1:0][8-1:0]  mii_txc_dbgx ;
  logic [  NUM_LN-1:0][64-1:0] mii_txd_dbgx ;
  logic [32-1:0] beat_mismatch;
  logic [64-1:0] byte_mismatch;
  logic [32-1:0] tc_beat_mismatch;
  logic [64-1:0] tc_byte_mismatch;
  logic [32-1:0] beat_mismatch_c;
  logic [64-1:0] byte_mismatch_c;
  logic [32-1:0] tc_beat_mismatch_c;
  logic [64-1:0] tc_byte_mismatch_c;
logic [NUM_BYTE-1:0]      ctrl_incl;    
logic [NUM_BYTE-1:0]      in_frm;       
logic                     frm_carry_q;  
logic [NUM_BYTE-1:0][7:0] pf_bytes;     

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

  always_comb begin : proc_mii_adp
    sof_vld_ln   = 0;
    eof_vld      = 0;
    mii_txd_c    = {NUM_BYTE{8'h07}} ;
    ctrl_inprg   = 0;
    mii_ctrl     = (pf_sof_d2<<(pf_aligner_ofst_d2*8)) | (pf_eof_d2<<((pf_fcs_ofst_r2))) | (eop_late_r<<((pf_fcs_ofst_r3)));
    mii_ctrlx    = pf_sof_d2  << (pf_aligner_ofst_d2 * 8)|(pf_eof_d2  << pf_fcs_ofst_r2) |(eop_late_r << pf_fcs_ofst_r3);
    mii_txc_c    = '1;
    sof_vld      = sof_vld_r;
    eof_vld      = eof_vld_r;
    mii_ctrl_dbg = mii_ctrl;
    mii_ctrl_dbgx= mii_ctrlx;
    ctrl_incl    = pre_xor(mii_ctrlx);
    in_frm       = {ctrl_incl[NUM_BYTE-2:0], 1'b0} ^ {NUM_BYTE{frm_carry_q}};
    for(int ln = 0 ; ln<NUM_LN;ln++)
      sof_vld_ln[ln] = out_beat_vld & SOF_WORD == pf_aligned[ln];
    for (int i = 0; i < NUM_BYTE; i++) begin
      mii_txc_cx[i] = mii_ctrlx[i]  | ~in_frm[i];
      mii_txd_cx[i] = (mii_ctrlx[i] | in_frm[i]) ? pf_aligned[i/8][(i%8)*8 +: 8]: 8'h07;
    end
 
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
          mii_txd_c[ii] = pf_aligned[ii/8][(ii%8)*8+:8];
        end
    else if(sof_vld)
      begin
        mii_txc_c[ii] = 0;
        // sof_vld = 0;
        mii_txd_c[ii] = pf_aligned[ii/8][(ii%8)*8+:8];
      end
    mii_txc_dbg = mii_txc_c;
    mii_txd_dbg = mii_txd_c;
    mii_txc_dbgx = mii_txc_cx  ;
    mii_txd_dbgx = mii_txd_cx  ; 
  end

  always_ff @(posedge clk) begin : proc_mii_blk
    if(rst) begin
      mii_txc <= '1;
      mii_txd <= {NUM_BYTE{8'h07}};
      mii_txcx <= '1;
      mii_txdx <= {NUM_BYTE{8'h07}};
    end
    else begin
      mii_txc    <= mii_txc_c;
      mii_txd    <= mii_txd_c;
      mii_txcx <= mii_txc_cx;
      mii_txdx <= mii_txd_cx;
    end
  end

assign o_mii_txd = mii_txd;
assign o_mii_txc = mii_txc;


always_ff @(posedge clk) begin
  if (rst)
    frm_carry_q <= 1'b0;
  else     
    frm_carry_q <= frm_carry_q ^ ctrl_incl[NUM_BYTE-1];   
end


always_comb
  begin
    byte_mismatch_c    = 0;
    tc_byte_mismatch_c = 0;
    for(int ii=0;ii<NUM_BYTE; ii++)
      begin
        byte_mismatch_c+=mii_txdx[ii]!=mii_txd[ii];
        tc_byte_mismatch_c+=mii_txcx[ii]!=mii_txc[ii];
      end
  end

always_ff @(posedge clk) begin : proc_missmatch_cnt
  if(rst) begin
    beat_mismatch   <= '0;
    byte_mismatch   <= '0;
    tc_beat_mismatch<= '0;
    tc_byte_mismatch<= '0;
  end 
  else begin
    beat_mismatch   <=beat_mismatch+(mii_txdx!=mii_txd) ; 
    byte_mismatch   <=byte_mismatch+byte_mismatch_c ; 
    tc_beat_mismatch<=tc_beat_mismatch+(mii_txcx!=mii_txc) ; 
    tc_byte_mismatch<=tc_byte_mismatch+tc_byte_mismatch_c ; 
  end
end

//assign pf_byte_cnt = tlast_lch & i_axis_tvalid& ~i_tready ? $countones(i_axis_tkeep) : i_axis_tvalid& ~i_tready ? $countones(i_axis_tkeep) + byte_cnt_r :byte_cnt_r;

//==================================================================================================================================================================
//                                                               DEBUG LOGIC  
//==================================================================================================================================================================

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

always_ff @(posedge clk) begin 
  if(rst || (in_reg_axis_tvalid&&slave_ready)) begin
    idle_cyc_cnt<= 0;
  end
   else if(idle_cyc_cnt<1000)begin
    idle_cyc_cnt<=idle_cyc_cnt+1 ;
  end
end

assign clear = 0;
longint unsigned  n_err ;
longint unsigned  n_err1 ;
mac_bw_monitor mac_bw_monitor (
  .clk     (clk     ),
  .rst_n   (~rst    ),
  .clear   (clear   ),
  .report  (idle_cyc_cnt==999),
  .n_frames(0),
  .s_tvalid(in_reg_axis_tvalid),
  .s_tready(slave_ready),
  .s_tlast (in_reg_axis_tlast ),
  .s_tkeep (in_reg_axis_tkeep ),
  .txd     (mii_txd     ),
  .txc     (mii_txc     )
);


mac_tx_scoreboard_simple i_mac_tx_scoreboard_simple (
  .clk     (clk               ),
  .rst_n   (~rst              ),
  .s_tvalid(in_reg_axis_tvalid),
  .s_tready(slave_ready       ),
  .s_tlast (in_reg_axis_tlast ),
  .s_tdata (in_reg_axis_tdata ),
  .s_tkeep (in_reg_axis_tkeep ),
  .txd     (mii_txd     ),
  .txc     (mii_txc     ),
  .report  (idle_cyc_cnt==999 ),
  .n_err   (n_err1  )
);


endmodule 