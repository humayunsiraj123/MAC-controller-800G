package mac_rtl_pkg;
	localparam DATA_W   = 1024         ;
	localparam CTRL_W   = DATA_W/8     ;
	localparam LANE_W   = 64           ;
	localparam NUM_LANE = DATA_W/LANE_W;
	localparam SOF_WORD = 64'hD5_55_55_55_55_55_55_FB;
	localparam EOF_BYTE = 8'hFD;
	localparam ERR_BYTE = 8'hFC;
	localparam IDL_BYTE = 8'h07;

endpackage : mac_rtl_pkg

