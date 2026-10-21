import mac_rtl_pkg::*;

module axis_slave #(
	parameter DATA_W = 1024,
	parameter USER_W = 129
) (
	input                         clk       , // Clock
	input                         rst_n     , // Asynchronous reset active low
	input  logic                  usr_tvalid,
	input  logic                  usr_tlast ,
	input  logic [DATA_WIDTH-1:0] usr_tdata  ,
	input  logic [    USER_W-1:0] usr_tuser ,
	output logic                  usr_tready,
	output logic                  mac_tvalid,
	output logic                  mac_tlast ,
	output logic [DATA_WIDTH-1:0] mac_tdata  ,
	output logic [    USER_W-1:0] mac_tuser ,
	input  logic                  mac_tready,
);

  	assign usr_tready  = mac_tready;

	always_ff @(posedge clk) begin : proc_bp_reg
		if(rst) begin
		mac_tvalid<= '0;
		mac_tlast<=  '0;
		mac_tdata<= '0;
		mac_tuser<='0; 
		end
		else if(mac_tready & mac_tvalid) begin
		mac_tvalid<= usr_tvalid;
		mac_tlast<=	 usr_tlast;
		mac_tdata<=  usr_tdata;
		mac_tuser<=	 usr_tuser; 
		end
		else if(mac_tready) begin
		mac_tvalid<='0;
		end
	end

endmodule : axis_slave