module sfifo #(
  parameter DEPTH      = 16   ,
  parameter DATA_WIDTH = 32   ,
  parameter FTHRESH    = DEPTH, 
  parameter ETHRESH    = 0    , 
  parameter LATENCY    = 0    , 
  parameter RST_INIT   = 0    , 
  parameter INIT_VAL   = '0     
) (
  input  logic                   clk      ,
  input  logic                   arst_n   ,
  input  logic                   wr       , 
  input  logic [ DATA_WIDTH-1:0] wr_data  ,
  output logic                   full     ,
  output logic                   tfull    , 
  output logic                   ovf      , 
  input  logic                   rd       , 
  output logic [ DATA_WIDTH-1:0] rd_data  ,
  output logic                   empty    ,
  output logic                   tempty   , 
  output logic                   udf      , 
  output logic [$clog2(DEPTH):0] num_vld  , 
  output logic                   init_done, 
  output logic                   sec      ,
  output logic                   ded
);
  // -------------------------------------
  // Local signals
  // -------------------------------------
  logic [$clog2(DEPTH)-1:0] wr_addr;
  logic [$clog2(DEPTH)-1:0] rd_addr;
  // -------------------------------------
  // Controller instance
  // -------------------------------------
  sfifo_cntrlr #(
    .DEPTH  (DEPTH  ),
    .FTHRESH(FTHRESH),   
    .ETHRESH(ETHRESH)    
  ) sfifo_cntrlr_inst (
    .clk    (clk    ),
    .arst_n (arst_n ),
    .wr     (wr     ),
    .wr_addr(wr_addr),
    .full   (full   ),
    .tfull  (tfull  ),
    .ovf    (ovf    ),
    .rd     (rd     ),
    .rd_addr(rd_addr),
    .empty  (empty  ),
    .tempty (tempty ),
    .udf    (udf    ),
    .num_vld(num_vld)
  );
 

  two_port_mem #(
    .DATA_WIDTH(DATA_WIDTH),   
    .DEPTH     (DEPTH     ),   
    .LATENCY   (LATENCY   ),   
    .RST_INIT  (RST_INIT  ),   
    .INIT_VAL  (INIT_VAL  )    
  ) two_port_mem_inst (
    .rd_clk   (clk         ),
    .wr_clk   (clk         ),
    .arst_n   (arst_n      ),
    .me       ('1          ),   
    .wr       (wr && !full ),   
    .wr_addr  (wr_addr     ),   
    .wr_data  (wr_data     ),   
    .rd       (rd && !empty),   
    .rd_addr  (rd_addr     ),   
    .rd_data  (rd_data     ),   
    .init_done(init_done   ),   
    .sec      (sec         ),
    .ded      (ded         )
  );
endmodule : sfifo
