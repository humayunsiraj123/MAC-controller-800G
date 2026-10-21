module fwft_fifo_wrapper #(
  parameter DATA_WIDTH = 32,
  parameter DEPTH      = 16,
  parameter LATENCY    = 0
) (
  input  logic                  clk    ,
  input  logic                  rst ,
  input  logic [DATA_WIDTH-1:0] wr_data,
  input  logic                  wr_en  ,
  output logic                  full   ,
  output logic [DATA_WIDTH-1:0] rd_data,
  input  logic                  rd_en  ,
  output logic                  empty
);



  logic [DATA_WIDTH-1:0] sc_rd_data;
  logic                  sc_rd_en  ;
  logic                  sc_empty  ;

  logic [DATA_WIDTH-1:0] middle_reg  ;
  logic                  middle_valid;

  logic                   tfull, ovf, tempty, udf;
  logic [$clog2(DEPTH):0] num_vld  ;
  logic                   init_done, sec, ded;

  logic invld_data_out;
  logic out_take_sc   ;
  logic mid_take_sc   ;

  assign full = tfull;

  sfifo #(
    .DEPTH     (DEPTH     ),
    .DATA_WIDTH(DATA_WIDTH),
    .FTHRESH   (DEPTH-2   ),   // full threshold
    .LATENCY   (0         )
  ) sfifo_i (
    .clk      (clk       ),
    .arst_n   (~rst      ),
    .wr       (wr_en     ),
    .wr_data  (wr_data   ),
    .full     (/*full*/  ),
    .tfull    (tfull     ),
    .ovf      (ovf       ),
    .rd       (sc_rd_en  ),
    .rd_data  (sc_rd_data),
    .empty    (sc_empty  ),
    .tempty   (tempty    ),
    .udf      (udf       ),
    .num_vld  (num_vld   ),
    .init_done(init_done ),
    .sec      (sec       ),
    .ded      (ded       )
  );

//prefechting logic
//fifo must read proactivly and generate respective  valid and empty
//fifo reading whenw to fill either middle or out word on read or sc_fifo has somethign
  assign invld_data_out = empty | rd_en;
  assign sc_rd_en = !sc_empty && (!middle_valid || invld_data_out);
  //if fifo  user read and middle is invalid direcctly deliver the out_word
  assign out_take_sc = sc_rd_en && invld_data_out && !middle_valid;
  //middle fill  if user noy ready but scfifo not empty
  assign mid_take_sc = sc_rd_en && !out_take_sc;

  always_ff @(posedge clk) begin
    if (rst) begin
      middle_valid <= 1'b0;
      middle_reg   <= '0;
      rd_data      <= '0;
      empty        <= 1'b1;
    end else begin
      if (mid_take_sc) begin 
        middle_reg   <= sc_rd_data;
        middle_valid <= 1'b1;
      end else if (invld_data_out && middle_valid) begin
        middle_valid <= 1'b0;
      end
      if (out_take_sc) begin
        rd_data <= sc_rd_data;
        empty   <= 1'b0;
      end else if (invld_data_out && middle_valid) begin
        rd_data <= middle_reg;
        empty   <= 1'b0;
      end else if (invld_data_out) begin
        empty <= 1'b1;
      end
    end
  end

endmodule