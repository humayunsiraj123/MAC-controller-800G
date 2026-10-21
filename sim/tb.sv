`timescale 1ps / 1ps

module tb;

    // ---------------- Parameters ----------------
    parameter int     DWIDTH             = 1024;
    parameter int     PIPE_LVL           = 0;
    parameter int     REV_PIPE_EN_ONEHOT = 32'hffffffff;
    parameter string  CRC_NAME           = "crc-32";
    parameter int     CRC_WIDTH          = 32;
    parameter longint CRC_POLY           = 32'h04c11db7;
    parameter longint INIT               = 32'hffffffff;
    parameter longint XOR_OUT            = 32'hffffffff;
    parameter int     REFIN              = 1;
    parameter int     REFOUT             = 1;

    // ---------------- Test parameters ----------------
    localparam int NUM_PACKETS = 50000;
    localparam int MIN_BEATS   = 1;
    localparam int MAX_BEATS   = 7;
    localparam int MAX_GAP     = 3;      // 0 => back-to-back, up to 3 idle cycles between packets
    localparam int STRB_W      = DWIDTH / 8;
 
    // ---------------- Clock / reset ----------------
    logic clk = 0;
    logic rst = 1;
    always #391 clk = ~clk; //800MHZ clock //782 //

    // ---------------- AXI-Stream signals ----------------
    logic [DWIDTH-1:0]    i_axis_tdata;
    logic [STRB_W-1:0]    i_axis_tkeep;
    logic [STRB_W:0]      i_axis_tuser;
    logic                 i_axis_tlast;
    logic                 i_axis_tvalid;
    logic [CRC_WIDTH-1:0] o_crc_axis_tdata;
    logic                 o_crc_axis_tvalid;

    // ---------------- CRC configuration ----------------
    logic                 ref_in, ref_out;
    logic [CRC_WIDTH-1:0] crc_init_val, xor_out;
    logic bp_user;
    assign ref_in  = REFIN[0];
    assign ref_out = REFOUT[0];
       
    function automatic logic [CRC_WIDTH-1:0] reverse_bits(input logic [CRC_WIDTH-1:0] v);
        for (int i = 0; i < CRC_WIDTH; i++) reverse_bits[i] = v[CRC_WIDTH-1-i];
    endfunction

    assign crc_init_val = ref_in  ? reverse_bits(INIT[CRC_WIDTH-1:0])    : INIT[CRC_WIDTH-1:0];
    assign xor_out      = ref_out ? reverse_bits(XOR_OUT[CRC_WIDTH-1:0]) : XOR_OUT[CRC_WIDTH-1:0];

    // ---------------- Software CRC reference ----------------
    function automatic logic [7:0] rev8(input logic [7:0] b);
        for (int i = 0; i < 8; i++) rev8[i] = b[7-i];
    endfunction

    function automatic logic [CRC_WIDTH-1:0] sw_crc(
        input logic [7:0] bytes [],
        input int         nbytes
    );
        logic [CRC_WIDTH-1:0] crc;
        logic [7:0]           b;
        logic                 fb;
        crc = INIT[CRC_WIDTH-1:0];
        for (int k = 0; k < nbytes; k++) begin
            b = bytes[k];
            if (ref_in) b = rev8(b);
            for (int j = 7; j >= 0; j--) begin
                fb  = crc[CRC_WIDTH-1] ^ b[j];
                crc = crc << 1;
                if (fb) crc = crc ^ CRC_POLY[CRC_WIDTH-1:0];
            end
        end
        if (ref_out) crc = reverse_bits(crc);
        crc = crc ^ XOR_OUT[CRC_WIDTH-1:0];
        return crc;
    endfunction
    // ---------------- DUT ----------------
    // tbps_crc_axis #(
    //     .DWIDTH(DWIDTH),
    //     .PIPE_LVL(PIPE_LVL),
    //     .REV_PIPE_EN_ONEHOT(REV_PIPE_EN_ONEHOT),
    //     .CRC_WIDTH(CRC_WIDTH),
    //     .CRC_POLY(CRC_POLY[CRC_WIDTH-1:0])
    // ) dut (
    //     .clk(clk),
    //     .rst(rst),
    //     .crc_init_val(crc_init_val),
    //     .xor_out(xor_out),
    //     .ref_in(ref_in),
    //     .ref_out(ref_out),
    //     .i_axis_tdata(i_axis_tdata),
    //     .i_axis_tkeep(i_axis_tkeep),
    //     .i_axis_tlast(i_axis_tlast),
    //     .i_axis_tvalid(i_axis_tvalid),
    //     .o_crc_axis_tdata(o_crc_axis_tdata),
    //     .o_crc_axis_tvalid(o_crc_axis_tvalid),
    //     .bp_user(bp_user)
    // );
 
    logic i_axis_tready;
    assign bp_user = i_axis_tready;
    logic [    DWIDTH-1:0] mii_txd;
    logic [(DWIDTH/8)-1:0] mii_txc;
    mac_controller #(
        .DWIDTH   (DWIDTH                 ),
        .CRC_WIDTH(CRC_WIDTH              ),
        .CRC_POLY (CRC_POLY[CRC_WIDTH-1:0])
    ) dut (
        .clk               (clk               ),
        .rst               (rst               ),
        .i_axis_tdata (i_axis_tdata ),
       // .i_axis_tkeep (i_axis_tkeep ),   // TODO: Check connection ! Signal/port not matching : Expecting logic [DWIDTH/8-1:0]  -- Found logic [STRB_W-1:0]
        .i_axis_tlast (i_axis_tlast ),
        .i_axis_tvalid(i_axis_tvalid),
        .i_axis_user  (i_axis_tuser),
        .crc_init_val      (crc_init_val      ),
        .xor_out           (xor_out           ),
        .ref_in            (ref_in            ),
        .ref_out           (ref_out           ),
        .o_mii_txd         (mii_txd           ),
        .o_mii_txc         (mii_txc           ),
        .i_axis_tready     (i_axis_tready     )
    );

    // ---------------- Shared result tracking ----------------
    int                   pass_cnt = 0;
    int                   fail_cnt = 0;
    logic [CRC_WIDTH-1:0] exp_queue [$];

    // ---------------- Drive one beat ----------------
    task automatic drive_beat(
        input logic [DWIDTH-1:0] d,
        input logic [STRB_W-1:0] k,
        input logic              l
    );
        i_axis_tdata  = d;
        i_axis_tkeep  = k;
        i_axis_tlast  = l;
        i_axis_tvalid = 1;
        if(~bp_user)@(posedge clk);
        @(posedge clk);
    endtask
// Send one beat, but keep tvalid high across beats.
// Return only after the beat has been accepted.
clocking cb @(posedge clk);
    input bp_user;
endclocking

task automatic send_beat(
    input logic [DWIDTH-1:0] d,
    input logic [STRB_W-1:0] k,
    input logic              s,
    input logic              l
);
    // 1) Place the beat on the bus
    i_axis_tdata  = d;
    i_axis_tkeep  = k;
    i_axis_tlast  = l;
    i_axis_tvalid = 1;
    i_axis_tuser  = {s,k};

    // 2) Advance one clock, then hold while DUT asserts backpressure.
    //    Because bp_user is registered, at each posedge it holds the
    //    value the DUT uses that same edge -- no extra sync needed.
    // do begin
    // @(posedge clk); 
    // #0;
    // end
    // while (bp_user);
   // while (!bp_user) @(posedge clk);   // hold while busy
      do begin
        @(posedge clk);
    end while (bp_user==0);
    // At this point, at the last posedge, bp_user was 0,
    // so the beat was accepted. tvalid stays 1 for the next beat.
endtask


// task automatic send_beat(
//     input logic [DWIDTH-1:0] d,
//     input logic [STRB_W-1:0] k,
//     input logic              l
// );
//     i_axis_tdata  = d;
//     i_axis_tkeep  = k;
//     i_axis_tlast  = l;
//     i_axis_tvalid = 1;

//     do @(cb); while (cb.bp_user);
// endtask

// task automatic axis_send(
//     input logic [DWIDTH-1:0] d,
//     input logic [STRB_W-1:0] k,
//     input logic              l
// );
//     // Present the beat
//     i_axis_tdata  = d;
//     i_axis_tkeep  = k;
//     i_axis_tlast  = l;
//     i_axis_tvalid = 1;

//     // Wait for the handshake: sample tready at posedge
//     do @(posedge clk); while (!bp_user);

//     // Handshake complete: beat accepted
//     i_axis_tvalid = 0;  // optional: create a gap, or keep high for back-to-back
// endtask


    // ---------------- Monitor: check CRC outputs ----------------
    initial begin
        logic                 prev_vld;
        logic [CRC_WIDTH-1:0] exp;
        prev_vld = 0;
        forever begin
            @(posedge clk);
            #1;                            // let NBA updates settle before sampling
            if (!rst && o_crc_axis_tvalid && !prev_vld) begin
                if (exp_queue.size() == 0) begin
                    $display("[%0t] UNEXPECTED CRC: got %h with empty expected queue",
                             $time, o_crc_axis_tdata);
                    fail_cnt++;
                end else begin
                    exp = exp_queue.pop_front();
                    if (o_crc_axis_tdata !== exp) begin
                        $display("[%0t] FAIL: exp=%h got=%h", $time, exp, o_crc_axis_tdata);
                        fail_cnt++;
                    end else begin
                        $display("[%0t] PASS: crc=%h", $time, o_crc_axis_tdata);
                        pass_cnt++;
                    end
                end
            end
            prev_vld = o_crc_axis_tvalid;
        end
    end

    // ---------------- Driver: mixed-size packets, small / no gaps ----------------
    initial begin
        int                nbeats;
        int                last_keep;
        int                total_bytes;
        int                byte_idx;
        int                b;
        int                beat;
        int                lane;
        int                gap;
        logic [DWIDTH-1:0] beat_data;
        logic [STRB_W-1:0] beat_keep;
        logic [7:0]        pkt [];

        // Init inputs
        i_axis_tdata  = '0;
        i_axis_tkeep  = '0;
        i_axis_tlast  = 0;
        i_axis_tvalid = 0;
        i_axis_tuser = '0;

        // Reset
        rst = 1;
        repeat (10) @(posedge clk);
        rst = 0;
        repeat (3)  @(posedge clk);

        $display("=========================================");
        $display("  Back-to-back / small-gap AXI-Stream test");
        $display("  DWIDTH=%0d  PIPE_LVL=%0d  CRC_WIDTH=%0d",
                 DWIDTH, PIPE_LVL, CRC_WIDTH);
        $display("  NUM_PACKETS=%0d  BEATS=%0d..%0d  MAX_GAP=%0d",
                 NUM_PACKETS, MIN_BEATS, MAX_BEATS, MAX_GAP);
        $display("=========================================");

        for (int p = 0; p < NUM_PACKETS; p++) begin
            // -------- Pick random packet geometry --------
            `ifdef  FULL_BEATS
            nbeats      = $urandom_range(MIN_BEATS, MAX_BEATS);
            last_keep   = $urandom_range(STRB_W, STRB_W);
            `elsif  PERF
            nbeats      = 1;//$urandom_range(MIN_BEATS, MAX_BEATS);
            last_keep   = STRB_W/($urandom_range(1,2));//$urandom_range(STRB_W, STRB_W);
            `elsif  PERF1
            nbeats      = 1;//$urandom_range(MIN_BEATS, MAX_BEATS);
            last_keep   = STRB_W;///($urandom_range(1,2));//$urandom_range(STRB_W, STRB_W);
             `elsif PERF2  
            nbeats      = 1;//$urandom_range(MIN_BEATS, MAX_BEATS);
            last_keep   = 104;//$urandom_range(STRB_W, STRB_W);
            `elsif  SMALL_FRAME
            nbeats      = $urandom_range(1, 1);
            last_keep   = 60;//{60{1'b1}};//$urandom_range(STRB_W, STRB_W);
            `else 
            nbeats      = $urandom_range(MIN_BEATS, MAX_BEATS);
            last_keep   = $urandom_range(1, STRB_W);
            last_keep   = nbeats==1 & last_keep<60  ? (60+$urandom_range(1,60)) :last_keep; 
            `endif
            //last_keep   = $urandom_range(1, STRB_W);
            total_bytes = (nbeats - 1) * STRB_W + last_keep;
            // /total_bytes = total_bytes<60 ? 60 : total_bytes; 
            pkt = new[total_bytes];
            for (b = 0; b < total_bytes; b++) pkt[b] = b<8 ? 8'hAB: p+b/8  ;//$urandom_range(0, 255);

            // Push expected CRC BEFORE driving. The DUT may output it
            // as soon as the last beat is captured, even while we are
            // already driving the next packet.
            exp_queue.push_back(sw_crc(pkt, total_bytes));
            
            // -------- Drive all beats of this packet --------
            byte_idx = 0;
            // if(bp_user)
            //     begin
            //         i_axis_tdata  = '0;
            //         i_axis_tkeep  = '0;
            //         i_axis_tlast  = 0;
            //         i_axis_tvalid = 0;
            //         @(posedge clk);
            //         $display("bp_userrrrrrrrrrrrrrrrrrrrrrrrrrrr",);
            //     end
            // else 
            // begin
            for (beat = 0; beat < nbeats; beat++) begin
                beat_data = '0;
                if (beat == nbeats - 1)
                    beat_keep = (last_keep == STRB_W)
                                ? {STRB_W{1'b1}}
                                : ((STRB_W'(1) << last_keep) - 1);
                else
                    beat_keep = {STRB_W{1'b1}};

                for (lane = 0; lane < STRB_W; lane++) begin
                    if (beat_keep[lane] && byte_idx < total_bytes) begin
                        beat_data[lane*8 +: 8] = pkt[byte_idx];
                        byte_idx++;
                    end
                end
                // if(bp_user)
                //     begin
                //      i_axis_tdata  = beat_data;
                //      i_axis_tkeep  = beat_keep;
                //      i_axis_tlast  = (beat == nbeats-1);
                //      i_axis_tvalid = 1;
                //      @(posedge clk);
                //     end
                // else
                   // drive_beat(beat_data, beat_keep, (beat == nbeats-1));
                   send_beat(beat_data, beat_keep,beat==0,(beat == nbeats-1));
            end
            //end

            // -------- Gap between packets --------
            gap = 0;//bp_user==0 ;//'0;//$urandom_range(0, MAX_GAP);
            //$display("[%0t] Pkt %0d: beats=%0d last_keep=%0d bytes=%0d gap=%0d%s",
            //         $time, p, nbeats, last_keep, total_bytes, gap,
            //         (gap == 0) ? "  (back-to-back)" : "");

            if (gap > 0) begin
                i_axis_tvalid = 0;
                i_axis_tlast  = 0;
                i_axis_tkeep  = '0;
                i_axis_tuser  ='0;  
                repeat (gap) @(posedge clk);
            end
            // gap == 0  => tvalid stays high, tlast was asserted on the
            //              previous beat, so the next beat's first cycle
            //              is interpreted by the DUT as the start of the
            //              next packet. True back-to-back AXI-Stream.
        end

        // Deassert after last packet
        i_axis_tvalid = 0;
        i_axis_tlast  = 0;
        i_axis_tkeep  = '0;
        i_axis_tuser  = '0;  

        // Wait for all outstanding CRCs
        while (exp_queue.size() > 0) @(posedge clk);
        repeat (20) @(posedge clk);

        $display("=========================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_cnt, fail_cnt);
        $display("=========================================");
        $finish;
    end

    // ---------------- Global watchdog ----------------
    initial begin
        #0.2ms;
        $display("GLOBAL TIMEOUT");
        $finish;
    end

endmodule  