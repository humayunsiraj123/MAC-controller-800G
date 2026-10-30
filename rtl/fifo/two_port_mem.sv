
module two_port_mem #(
  parameter DATA_WIDTH = 8            , 
  parameter DEPTH      = 16           , 
  parameter ADDR_WIDTH = $clog2(DEPTH), 
  parameter LATENCY    = 1            , 
  parameter RST_INIT   = 0            , 
  parameter INIT_VAL   = '0             
) (
  input  logic                  rd_clk   ,
  input  logic                  wr_clk   ,
  input  logic                  arst_n   ,
  input  logic                  me       , 
  input  logic                  wr       , 
  input  logic [ADDR_WIDTH-1:0] wr_addr  , 
  input  logic [DATA_WIDTH-1:0] wr_data  , 
  input  logic                  rd       , 
  input  logic [ADDR_WIDTH-1:0] rd_addr  , 
  output logic [DATA_WIDTH-1:0] rd_data  , 
  output logic                  init_done, 
  output logic                  sec      ,
  output logic                  ded
);

  // Memory array (flop-based)
  logic [DATA_WIDTH-1:0] mem[DEPTH];
  // Initialization counter
  logic [ADDR_WIDTH:0] init_cnt;
  // Generate block to enable disable
  // reset Sequence
  generate
    if(RST_INIT) begin
  
      // init_cnt register
  
      always_ff @(posedge wr_clk or negedge arst_n) begin
        if (!arst_n)
          init_cnt <= '0;
        else if (!init_done)
          init_cnt <= init_cnt + 1;
      end
  
      // init_done register
  
      always_ff @(posedge wr_clk or negedge arst_n) begin
        if (!arst_n)
          init_done <= 1'b0;
        else if (!init_done && (init_cnt == DEPTH-1))
          init_done <= 1'b1;
      end
    end
    else begin
      assign init_done = 1'b1 ;
      assign init_cnt  = DEPTH-1 ;
    end
  endgenerate
  // Memory write (init + normal write)
  always_ff @(posedge wr_clk or negedge arst_n) begin
    if(arst_n) begin
      if (!init_done) begin
        mem[init_cnt[ADDR_WIDTH-1:0]] <= INIT_VAL;
      end
      else if (me && wr) begin
        mem[wr_addr] <= wr_data;
      end
    end
  end

  // Read data register
  genvar gen_i;
  generate
    if(LATENCY==0) begin
      assign rd_data = (init_done && me) ? mem[rd_addr] : INIT_VAL ;
    end
    else if(LATENCY==1) begin
      always_ff @(posedge rd_clk or negedge arst_n) begin
        if (!arst_n)
          rd_data <= INIT_VAL;
        else if (init_done && me && rd)
          rd_data <= mem[rd_addr];
      end
    end
    else begin
      logic [DATA_WIDTH-1:0] rd_data_ltncy_arr[LATENCY];

      always_ff @(posedge rd_clk or negedge arst_n) begin
        if(!arst_n) begin
          rd_data_ltncy_arr[0] <= INIT_VAL;
        end else begin
          rd_data_ltncy_arr[0] <= (init_done&&me&&rd)?mem[rd_addr] : INIT_VAL ;
        end
      end

      for(gen_i=1;gen_i<LATENCY;gen_i++) begin
        always_ff @(posedge rd_clk or negedge arst_n) begin
          if(!arst_n) begin
            rd_data_ltncy_arr[gen_i] <= INIT_VAL;
          end else begin
            rd_data_ltncy_arr[gen_i] <= rd_data_ltncy_arr[gen_i-1];
          end
        end
      end

      assign rd_data = rd_data_ltncy_arr[LATENCY-1];
    end
  endgenerate

  // Sec Ded Signals which are used in case
  // Actual Memory
  assign sec = '0 ;
  assign ded = '0 ;
endmodule
