import crc32_pkg::*;

module crc_compute_engine
#(parameter STG =4) (
	input  logic                  clk    ,
	input  logic                  rst    ,
	//
	input  logic                  i_sof_in  ,
	// user axi steraming intf
	input  logic                  i_tx_valid,
	input  logic [DATA_WIDTH-1:0] i_tx_data ,
	input  logic [KEEP_WIDTH-1:0] i_tx_tkeep,
	input  logic                  i_tx_tlast,
	// computed crc32 output with its valid status,
	output logic [        32-1:0] crc32_val ,
	output logic                  crc32_vld
);
	
	localparam int unsigned MID_STG_NUM_BITS = DATA_WIDTH/2      ;
	localparam int unsigned PER_STG_NUM_BITS = DATA_WIDTH/STG    ;
	localparam int unsigned NUM_BYTES_W      = $clog2(KEEP_WIDTH);
	localparam int unsigned CRC_W            = 32                ;
  localparam int GW  											 = PER_STG_NUM_BITS;              // 256 (STG=4) or 512 (STG=2)
	localparam int MDW 											 = 512;              // 512 (STG=4) or 512 (STG=2)
  localparam logic [31:0] POLY     	 			 = 32'hEDB88320;//reflected poly
  localparam logic [31:0] CRC_INIT 	 			 = 32'hFFFFFFFF;
 	localparam int          DW         			 = 1024;
 	localparam int          KW         			 = 128;
 	localparam int          D          			 = 2;

	typedef struct packed{
		logic                   tvalid   ;
		logic [ DATA_WIDTH-1:0] tdata    ;
		logic [ KEEP_WIDTH-1:0] tkeep    ;
		logic                   tlast    ;
		logic                   sof_vld  ;
		logic [NUM_BYTES_W:0] vbyte_cnt;

	} axist_bus_t ;

	axist_bus_t [         STG:0]                    st_pipe_bus       ;
	logic       [         STG:0][CRC_W-1:0]         stg_crc_bm        ;
	logic       [         STG:0][CRC_W-1:0]         stg_acc_crc_bm    ;
	logic       [ NUM_BYTES_W:0]                    byte_cnt          ;
	logic       [     CRC_W-1:0]                    crc_stat_am       ;
	logic       [     CRC_W-1:0]                    func_crc_stat_am  ;
	logic       [     CRC_W-1:0]                    merge_xor_mat     ;
	logic       [     CRC_W-1:0]                    func_merge_xor_mat;
	logic       [     CRC_W-1:0]                    crc_stat_nxt      ;
	logic       [     CRC_W-1:0]                    crc_stat          ;
	logic       [DATA_WIDTH-1:0]                    corr_mat          ;
	logic       [     CRC_W-1:0]                    corr_crc          ;
	logic       [           3:0][      3:0][64-1:0] data_samp         ;


	logic [       STG-2:0][CRC_W-1:0]         mid_stg_crc_bm        ;
	logic [       STG-2:0][CRC_W-1:0]         mid_stg_acc_crc_bm    ;
	logic [ NUM_BYTES_W:0]                    mid_byte_cnt          ;
	logic [     CRC_W-1:0]                    mid_crc_stat_am       ;
	logic [     CRC_W-1:0]                    func_mid_crc_stat_am  ;
	logic [     CRC_W-1:0]                    mid_merge_xor_mat     ;
	logic [     CRC_W-1:0]                    func_mid_merge_xor_mat;
	logic [     CRC_W-1:0]                    mid_crc_stat_nxt      ;
	logic [     CRC_W-1:0]                    mid_crc_stat          ;
	logic [DATA_WIDTH-1:0]                    mid_corr_mat          ;
	logic [     CRC_W-1:0]                    mid_corr_crc          ;
	logic [           1:0][      7:0][64-1:0] mid_data_samp         ;

	logic [          31:0] ref_acc_q    [0:STG-1];
	logic [          31:0] mid_ref_acc_q[    0:1];
	logic [DATA_WIDTH-1:0] rpipe_tdata  [  0:STG];
	logic                  rpipe_vld    [  0:STG];
	logic                  rpipe_sop    [  0:STG];
	logic                  rpipe_tlast  [  0:STG];

	logic [31:0] ref_bm_comb    [0:STG-1];
	logic [31:0] mid_ref_bm_comb[    0:1];

  function automatic logic [31:0] ref_crc(input logic [7:0] bytes[], input int n);
    logic [31:0] c;
    logic        fb; 
    c = 32'hFFFF_FFFF;
    for (int i = 0; i < n; i++) begin
      for (int b = 0; b < 8; b++) begin
        fb = (c ^ bytes[i][b]) & 1'b1;
        c  = c >> 1;
        if (fb) c = c ^ POLY;
      end
    end
    return c ^ 32'hFFFF_FFFF;
  endfunction

  function automatic logic [31:0] crc_step(input logic [31:0] c, input logic b);
    logic fb;
    fb = (c ^ b) & 1'b1;
    c  = c >> 1;
    if (fb) c = c ^ POLY;
    return c;
  endfunction

  function automatic logic [31:0] func_group_bm(input logic [DATA_WIDTH-1:0] data,
                                                input int lo, input int hi);
    logic [31:0] s;
    s = '0;
    for (int k = 0; k < DATA_WIDTH; k++) begin
      logic d;
      d = (k >= lo && k < hi) ? data[k] : 1'b0;
      s = crc_step(s, d);
    end
    return s;
  endfunction

  // Advance 32-bit state through 1024 zero-data steps (== A · state).
  function automatic logic [31:0] func_A(input logic [31:0] st);
    logic [31:0] s;
    s = st;
    for (int k = 0; k < DATA_WIDTH; k++)
      s = crc_step(s, 1'b0);
    return s;
  endfunction

  function automatic logic [31:0] func_full_bm(input logic [DATA_WIDTH-1:0] data);
    logic [31:0] s;
    s = '0;
    for (int k = 0; k < DATA_WIDTH; k++)
      s = crc_step(s, data[k]);
    return s;
  endfunction

// def func_corr(combined, n_valid_bytes):
//     k = (BEAT_BYTES - n_valid_bytes) * 8
//     s = combined
//     for _ in range(k):
//         s = rstep(s)
//     return s
function automatic logic [31:0] crc_rstep(input logic [31:0] crc);
  return crc[31]
       ? (((crc ^ POLY) << 1) | 32'h0000_0001)
       :  (crc << 1);
endfunction


function automatic logic [31:0] func_corr_lut(
    input logic [31:0] combined,
    input logic [7:0]  n_valid_bytes);
    logic [31:0]   y;
    logic [1023:0] corr_mat;
    corr_mat = CORR_PACKED[n_valid_bytes * 1024 +: 1024];
    for (int ii = 0; ii < 32; ii++)
        y[ii] = ^(combined & corr_mat[ii*32 +: 32]);
    return y;
endfunction

//CORR_PACKED[n*1024 + o*32 +: 32] is the row for output bit o, at valid-byte count n.

function automatic logic [31:0] func_corr_bit(
    input logic [31:0] combined,
    input logic [7:0]  n_valid_bytes);
    logic [31:0] s;
    int          k;
    k = (128 - n_valid_bytes) * 8;
    s = combined;
    for (int i = 0; i < k; i++)
        s = crc_rstep(s);
    return s;
endfunction

  function automatic logic [DW-1:0] mask_by_keep(logic [DW-1:0] d,
                                                 logic [KW-1:0] k);
    logic [DW-1:0] m;
    m = '0;
    for (int b = 0; b < KW; b++)
      if (k[b]) m[8*b +: 8] = d[8*b +: 8];
    return m;
  endfunction

  function automatic int count_keep(logic [KW-1:0] k);
    int n; n = 0;
    for (int b = 0; b < KW; b++) n += int'(k[b]);
    return n;
  endfunction

  function automatic logic [31:0] a_advance(logic [31:0] st);
    logic [31:0] s;
    s = st;
    for (int k = 0; k < DW; k++) s = crc_step(s, 1'b0);
    return s;
  endfunction

  function automatic logic [31:0] b_group(logic [DW-1:0] d, int g);
    logic [31:0] s;
    int lo, hi;
    lo = g * MDW; hi = lo + MDW;
    s = '0; 
    for (int k = 0; k < DW; k++)
      s = crc_step(s, (k >= lo && k < hi) ? d[k] : 1'b0);
    return s;
  endfunction

  function automatic logic [31:0] b_all(logic [DW-1:0] d);
    logic [31:0] s;
    s = '0;
    for (int k = 0; k < DW; k++) s = crc_step(s, d[k]);
    return s;
  endfunction

  function automatic logic [31:0] corr_rewind(logic [31:0] c, int n_valid);
    logic [31:0] s;
    int k;
    k = (BEAT_BYTES - n_valid) * 8;
    s = c;
    for (int i = 0; i < k; i++) s = crc_rstep(s);
    return s;
  endfunction

 //refernce crc function 
  function automatic logic [31:0] golden_fcs(input logic [7:0] data [],
                                             input int n);
    logic [31:0] c;
    c = CRC_INIT;
    for (int i = 0; i < n; i++)
      for (int b = 0; b < 8; b++)
        c = crc_step(c, data[i][b]);
    return c ^ CRC_XOROUT;
  endfunction

  //refernce crc function full beat
  function automatic logic [31:0] golden_fcs_beats(
      input logic [DW-1:0] tdata_arr [],
      input logic [KW-1:0] tkeep_arr []);
    logic [31:0] c;
    int nbeats;
    c = CRC_INIT;
    nbeats = tdata_arr.size();
    for (int i = 0; i < nbeats; i++) begin
      for (int b = 0; b < KW; b++) begin
        if (!tkeep_arr[i][b]) continue;
        for (int bi = 0; bi < 8; bi++)
          c = crc_step(c, tdata_arr[i][8*b + bi]);
      end
    end
    return c ^ CRC_XOROUT;
  endfunction

	genvar b_gv;
	genvar a_gv;
//TODO:stall pipeline when invld cycle
//pipeline data and ctlr

/*def step(crc: int, bit: int) -> int:
	fb = (crc ^ bit) &
	crc >>= 1
	if fb:
	crc ^= POLY_REFLECTED11
	return crc

def crc32_final(data: bytes) -> int:
	crc = INIT//0xFFFFFFFF
	for byte in data:
	for i in range(8):
	crc = step(crc, (byte >> i) & 1)
	return (crc ^ XOROUT) & 0xFFFFFFFF

def build_A_columns(verbose: bool = False):
	"""
	A_cols[i] = result of running 32-bit unit vector e_i (bit i set,
	everything else 0) through W serial steps with data=0 the whole way.
	Answers: "how does old_state bit i alone evolve over one full beat?"
	"""
	cols = []
	for i in range(32):
	state = 1 << i
	for _ in range(W):
	state = step(state, 0)
	cols.append(state)

A : 32   columns, column i = result of simulating 1024 zero-data steps starting from state = "bit i alone." Answers: "how does the old state alone evolve over one full beat?"
B : 1024 columns, column j = result of simulating 1024 steps starting from state 0, with a single 1-bit at data position j. Answers: "how does one data bit alone push the state?"
new_state = A·old_state XOR B·data. Built once, reused forever — this is what replaces 1024 serial loop iterations with one lookup+XOR.
	new_state[k] = XOR-reduce(vec AND mask[k]).

	*/
		assign st_pipe_bus[0].tvalid 			= i_tx_valid ;
		assign st_pipe_bus[0].tdata  			= i_tx_data  ;
		assign st_pipe_bus[0].tkeep  			= i_tx_tkeep ;
		assign st_pipe_bus[0].tlast  			= i_tx_valid& i_tx_tlast ;
		assign st_pipe_bus[0].sof_vld  		= i_tx_valid& i_sof_in ;
		assign st_pipe_bus[0].vbyte_cnt  	= i_tx_tlast& i_tx_valid ? $countones(i_tx_tkeep) : KEEP_WIDTH  ;

	generate
		//^(tdata_eff[GROUP0_HI-1:GROUP0_LO] & B_GROUP0_MASK_PACKED[k*GROUP0_W +: GROUP0_W]);
		// (data in  [(stg*256)-1:0] & BGROUP MASK for ehc 32 bit 256 bit
		for(a_gv = 0  ; a_gv<STG;a_gv++)
			assign data_samp[a_gv] = st_pipe_bus[a_gv].tdata[(a_gv*PER_STG_NUM_BITS)+:PER_STG_NUM_BITS];

		assign mid_data_samp[0] = st_pipe_bus[0].tdata[(0*MID_STG_NUM_BITS)+:MID_STG_NUM_BITS];
		assign mid_data_samp[1] = st_pipe_bus[1].tdata[(1*MID_STG_NUM_BITS)+:MID_STG_NUM_BITS];

		//assign data_samp[0]  = st_pipe_bus[0].tdata[(0*PER_STG_NUM_BITS)-1+PER_STG_NUM_BITS];
		//assign data_samp[1]  = st_pipe_bus[1].tdata[(1*PER_STG_NUM_BITS)-1+PER_STG_NUM_BITS];
		//assign data_samp[2]  = st_pipe_bus[2].tdata[(2*PER_STG_NUM_BITS)-1+PER_STG_NUM_BITS];
		//assign data_samp[3]  = st_pipe_bus[3].tdata[(3*PER_STG_NUM_BITS)-1+PER_STG_NUM_BITS];
		
		for (b_gv=0 ;b_gv <32;b_gv++) begin: blk_crc_stg
			assign stg_crc_bm[0][b_gv]     = ^(st_pipe_bus[0].tdata[(0*PER_STG_NUM_BITS)+:PER_STG_NUM_BITS] & B_GROUP0_MASK_PACKED[b_gv*PER_STG_NUM_BITS+:PER_STG_NUM_BITS]);
			assign stg_crc_bm[1][b_gv]     = ^(st_pipe_bus[1].tdata[(1*PER_STG_NUM_BITS)+:PER_STG_NUM_BITS] & B_GROUP1_MASK_PACKED[b_gv*PER_STG_NUM_BITS+:PER_STG_NUM_BITS])  ;
			assign stg_crc_bm[2][b_gv]     = ^(st_pipe_bus[2].tdata[(2*PER_STG_NUM_BITS)+:PER_STG_NUM_BITS] & B_GROUP2_MASK_PACKED[b_gv*PER_STG_NUM_BITS+:PER_STG_NUM_BITS])  ;
			assign stg_crc_bm[3][b_gv]     = ^(st_pipe_bus[3].tdata[(3*PER_STG_NUM_BITS)+:PER_STG_NUM_BITS] & B_GROUP3_MASK_PACKED[b_gv*PER_STG_NUM_BITS+:PER_STG_NUM_BITS])  ;
			assign mid_stg_crc_bm[0][b_gv] = ^(st_pipe_bus[0].tdata[(0*MID_STG_NUM_BITS)+:MID_STG_NUM_BITS] & MB_GROUP0_MASK_PACKED[b_gv*MID_STG_NUM_BITS+:MID_STG_NUM_BITS]);
			assign mid_stg_crc_bm[1][b_gv] = ^(st_pipe_bus[1].tdata[(1*MID_STG_NUM_BITS)+:MID_STG_NUM_BITS] & MB_GROUP1_MASK_PACKED[b_gv*MID_STG_NUM_BITS+:MID_STG_NUM_BITS]);
		end

		always_ff @(posedge clk) begin
			if(rst)
				stg_acc_crc_bm[0] <= '0;
			else
				stg_acc_crc_bm[0] <= stg_crc_bm[0];
		end
		always_ff @(posedge clk) begin
			if(rst)
				mid_stg_acc_crc_bm[0] <= '0;
			else
				mid_stg_acc_crc_bm[0] <= mid_stg_crc_bm[0];
		end
		always_ff @(posedge clk) begin
			if(rst)
				mid_stg_acc_crc_bm[1] <= '0;
			else
				mid_stg_acc_crc_bm[1] <= mid_stg_acc_crc_bm[0] ^ mid_stg_crc_bm[1];
		end

		for(a_gv =1 ;a_gv<=STG;a_gv++)
			always_ff @(posedge clk) begin
				st_pipe_bus[a_gv] <= st_pipe_bus[a_gv-1];
			end

		for(a_gv =1 ;a_gv<STG;a_gv++)
			always_ff @(posedge clk) begin
				stg_acc_crc_bm[a_gv] <= stg_crc_bm[a_gv] ^ stg_acc_crc_bm[a_gv-1] ;
			end

	endgenerate

/* synthesis translate_off */

   
  always_comb begin
    for (int i = 0; i < STG; i++)
      ref_bm_comb[i]     = func_group_bm(st_pipe_bus[i].tdata, i*GW, (i+1)*GW);
    for (int i = 0; i <= 1; i++)
      mid_ref_bm_comb[i] = func_group_bm(st_pipe_bus[i].tdata, i*MDW, (i+1)*MDW);
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < STG; i++) ref_acc_q[i] 	 <= '0;
    end else begin
      ref_acc_q[0] <= ref_bm_comb[0];
      for (int i = 1; i < STG; i++)begin
        ref_acc_q[i]     <= ref_acc_q[i-1] ^ ref_bm_comb[i];
      end
    end
  end

 always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i <=1; i++) mid_ref_acc_q[i] <= '0;
    end else begin
      mid_ref_acc_q[0]      <= mid_ref_bm_comb[0];
      for (int i = 1; i <= 1; i++)begin
        mid_ref_acc_q[i] <= mid_ref_acc_q[i-1] ^ mid_ref_bm_comb[i];
      end
    end
  end

/* synthesis translate_on  */
	logic [32-1:0][32-1:0] a_mat;

	assign func_crc_stat_am     = func_A(st_pipe_bus[STG].sof_vld ? CRC_INIT : crc_stat);// ^((st_pipe_bus[STG-1].sof_vld? CRC_INIT : crc_stat)& A_MASK_PACKED[a_gv*32 +: 32]);
	assign func_mid_crc_stat_am = func_A(st_pipe_bus[2].sof_vld   ? CRC_INIT : mid_crc_stat);
	generate 
		for (a_gv = 0; a_gv < 32; a_gv++) begin : blk_am_matrix
			assign crc_stat_am[a_gv] = ^((st_pipe_bus[STG].sof_vld    ? CRC_INIT : crc_stat)& A_MASK_PACKED[a_gv*32 +: 32]);
			assign a_mat[a_gv]       = A_MASK_PACKED[a_gv*32 +: 32];
			assign mid_crc_stat_am[a_gv] = ^((st_pipe_bus[2].sof_vld  ? CRC_INIT : mid_crc_stat)& A_MASK_PACKED[a_gv*32 +: 32]);
		end
	endgenerate

	// MAT_A XOR MAT_B
	assign merge_xor_mat      	   = crc_stat_am ^ stg_acc_crc_bm[D-1];
	assign func_merge_xor_mat 	   = func_crc_stat_am^ ref_acc_q[D-1];
	assign mid_merge_xor_mat  	   = mid_crc_stat_am ^ mid_stg_acc_crc_bm[1];
	assign func_mid_merge_xor_mat  = func_mid_crc_stat_am ^ mid_ref_acc_q[1];

	logic [NUM_BYTES_W:0] corr_vld_byte     ;
	logic       tlast_fnl_stg               ;
	logic [NUM_BYTES_W:0] mid_corr_vld_byte ;
	logic       mid_tlast_fnl_stg           ;
	logic [31:0] crc_out                    ;
	logic [31:0] crc_out_inv                ;
	logic [31:0] mid_crc_out                ;
	logic [31:0] mid_crc_out_inv            ;
	
	assign mid_corr_vld_byte = st_pipe_bus[2].vbyte_cnt;
	assign corr_vld_byte     = st_pipe_bus[STG].vbyte_cnt;
	//CORRECTION MATRIX SELECTION
	assign corr_mat          = CORR_PACKED[corr_vld_byte*1024 +:1024];
	assign tlast_fnl_stg     = st_pipe_bus[STG].tlast;
	assign mid_corr_mat      = CORR_PACKED[mid_corr_vld_byte*1024 +:1024];
	assign mid_tlast_fnl_stg = st_pipe_bus[2].tlast;

	logic [31:0] func_corr_crc    ;
	logic [31:0] mid_func_corr_crc;
	logic [31:0] func_crc_stat    ;
	logic [31:0] func_mid_crc_stat;

		assign  func_corr_crc      = func_corr_bit(func_merge_xor_mat,corr_vld_byte) ; 
		assign  mid_func_corr_crc  = func_corr_bit(func_mid_merge_xor_mat,mid_corr_vld_byte) ; 
	generate
		for (a_gv = 0; a_gv < 32; a_gv++) begin : blk_corr_crc
			assign corr_crc[a_gv]     = ^(merge_xor_mat & corr_mat[a_gv*32 +: 32]);
			assign mid_corr_crc[a_gv] = ^(mid_merge_xor_mat & mid_corr_mat[a_gv*32 +: 32]);
		end
	endgenerate

	always_ff @(posedge clk) begin
		if(rst) begin
			crc_stat <= '0;
		end else  if(st_pipe_bus[STG].tvalid) begin
			crc_stat <= tlast_fnl_stg       ? corr_crc : merge_xor_mat ;
		end
	end
	always_ff @(posedge clk) begin
		if(rst) begin
			func_crc_stat <= '0;
		end else if(st_pipe_bus[STG].tvalid) begin
			func_crc_stat <= tlast_fnl_stg  ? func_corr_crc : func_merge_xor_mat ;
		end
	end

	always_ff @(posedge clk) begin
		if(rst) begin
			mid_crc_stat <= '0;
		end
		 else if(st_pipe_bus[2].tvalid) begin
			mid_crc_stat <= mid_tlast_fnl_stg       ? mid_corr_crc : mid_merge_xor_mat ;
		end
	end
	always_ff @(posedge clk) begin
		if(rst) begin
			func_mid_crc_stat <= '0;
		end else if(st_pipe_bus[2].tvalid) begin
			func_mid_crc_stat <= mid_tlast_fnl_stg  ? mid_func_corr_crc : func_mid_merge_xor_mat ;
		end
	end

	assign crc_out_inv     = {crc_stat[7:0],crc_stat[15:8],crc_stat[23:16],crc_stat[31:24]};
	assign crc_out         =  /*crc_out_inv*/crc_stat ^ 32'hFFFF_FFFF ;

	assign mid_crc_out_inv = {mid_crc_stat[7:0],mid_crc_stat[15:8],mid_crc_stat[23:16],mid_crc_stat[31:24]};
	assign mid_crc_out     =  /*mid_crc_out_inv*/mid_crc_stat ^ 32'hFFFF_FFFF ;

	always_ff @(posedge clk) begin : proc_crc_blk
		if(rst) begin
			crc32_val <= '0;
			crc32_vld <= 0;
		end
		//else begin
		//	crc32_val <= st_pipe_bus[STG].tlast ? crc_out:crc32_val ;//stg_acc_crc_bm[STG] ;
		//	crc32_vld <= st_pipe_bus[STG].tlast;
		//end
		else begin
			crc32_val <= st_pipe_bus[3].tlast ? mid_crc_out:crc32_val ;//stg_acc_crc_bm[STG] ;
			crc32_vld <= st_pipe_bus[3].tlast;
		end
	end

//=================================================================================================
//                              MODEL
//=================================================================================================
  logic [31:0] state;
  logic [31:0] next_state;
  logic [31:0] fcs_comb;
  logic        fcs_vld_comb;

	logic  [2:0][31:0] mdl_pipe_fcs;
	logic  [2:0]       mdl_pipe_vld ;
	logic  [0:0][31:0] o_fcs;
	logic  [0:0]       o_fcs_vld ;
  always_comb begin
    logic [DW-1:0] masked;
    logic [31:0]   A_con, B_con, combined, corrected;
    int            nv;

    masked = mask_by_keep(i_tx_data, i_tx_tkeep);
    A_con  = a_advance(i_tx_valid& i_sof_in  ? CRC_INIT : state);

    B_con = '0;
    for (int g = 0; g < D; g++) B_con ^= b_group(masked, g);

    combined = A_con ^ B_con;
    nv       = count_keep(i_tx_tkeep);
    if (i_tx_valid && i_tx_tlast) begin
      corrected    = corr_rewind(combined, nv);
      next_state   = corrected;
      //fcs_comb     = {corrected[7:0],corrected[15:8],corrected[23:16],corrected[31:24]} ^ CRC_XOROUT;
      fcs_comb     = corrected ^ CRC_XOROUT;
      fcs_vld_comb = 1'b1;
    end else if (i_tx_valid) begin
      next_state   = combined;
      fcs_comb     = '0;
      fcs_vld_comb = 1'b0;
    end else begin
      next_state   = state;
      fcs_comb     = '0;
      fcs_vld_comb = 1'b0;
    end
  end

  //pipeline computed fcs of model to sync with rtl
  always_ff @(posedge clk) begin
    if (rst) begin
      state     <= CRC_INIT;
      o_fcs     <= '0;
      o_fcs_vld <= 1'b0;
    end else begin
      state     <= next_state;
      o_fcs     <= fcs_comb;
      o_fcs_vld <= fcs_vld_comb;
    end
    mdl_pipe_fcs<={mdl_pipe_fcs,o_fcs};
	  mdl_pipe_vld<={mdl_pipe_vld,o_fcs_vld};
  end

logic [31:0] fcs_cnt;
logic [31:0] fail_fcs_cnt;
always_ff @(posedge clk) begin : proc_fcs_cnt
	if(rst) begin
		 fcs_cnt <= 0;
		 fail_fcs_cnt<= 0;
	end
	else if(crc32_vld) begin
		 fcs_cnt  <= fcs_cnt +  crc32_vld;
		 fail_fcs_cnt<=fail_fcs_cnt +  mdl_pipe_fcs[2] != crc32_val ;
	end
end

  // ==========================================================================
  // 		ERROR DEBUG STAGE
  // ==========================================================================
  int             err_cnt_q;
  logic [STG-1:0] bm_bad_q, acc_bad_q;
  logic           any_bad_q;

  localparam int LOG_DEPTH = 8;
  int          log_idx;
  int          log_cyc  [0:LOG_DEPTH-1];
  int          log_stg  [0:LOG_DEPTH-1];
  logic        log_isbm [0:LOG_DEPTH-1];
  logic [31:0] log_got  [0:LOG_DEPTH-1];
  logic [31:0] log_exp  [0:LOG_DEPTH-1];
  int 		     cyc_cnt                 ;


  always_ff @(posedge clk) begin
    if (rst) begin
      bm_bad_q   <= '0;
      acc_bad_q  <= '0;
      any_bad_q  <= 1'b0;
      err_cnt_q  <= 0;
      cyc_cnt    <= 0;
      log_idx    <= 0;
    end else begin
      cyc_cnt <= cyc_cnt + 1;
      bm_bad_q  <= '0;
      acc_bad_q <= '0;

      for (int i = 0; i < STG; i++) begin
      
        if (st_pipe_bus[i].tvalid) begin
          if (stg_crc_bm[i] !== ref_bm_comb[i]) begin
            bm_bad_q[i] <= 1'b1;
            err_cnt_q   <= err_cnt_q + 1;
            if (err_cnt_q < 100) begin
              //$display("[t=%0t cyc=%0d] BM  mismatch STG %0d: dut=%08h ref=%08h",
              //         $time, cyc_cnt, i, stg_crc_bm[i], ref_bm_comb[i]);
              //record(cyc_cnt, i, 1'b1, stg_crc_bm[i], ref_bm_comb[i]);
            end
          end
        end

      
        if (st_pipe_bus[i].tvalid) begin
          if (stg_acc_crc_bm[i] !== ref_acc_q[i]) begin
            acc_bad_q[i] <= 1'b1;
            err_cnt_q    <= err_cnt_q + 1;
            if (err_cnt_q < 100) begin
              //$display("[t=%0t cyc=%0d] ACC mismatch STG %0d: dut=%08h ref=%08h",
              //         $time, cyc_cnt, i, stg_acc_crc_bm[i], ref_acc_q[i]);
              //record(cyc_cnt, i, 1'b0, stg_acc_crc_bm[i], ref_acc_q[i]);
            end
          end
        end
      end

      if (|bm_bad_q | |acc_bad_q) any_bad_q <= 1'b1;
    end
  end

  assign dbg_any_mismatch  = any_bad_q;
  assign dbg_stage_bm_bad  = bm_bad_q;
  assign dbg_stage_acc_bad = acc_bad_q;
  assign dbg_err_cnt       = err_cnt_q;


endmodule
