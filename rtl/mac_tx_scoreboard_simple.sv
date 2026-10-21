// // =============================================================
// // Simplified MAC TX Scoreboard
// // - Captures AXI-Stream input packets
// // - Computes expected CRC-32
// // - Walks TXD/TXC byte-by-byte on the MII output
// // - Checks: START alignment, preamble/SFD/data/FCS, TERM, lengths
// // - Tracks input vs output and reports pass/fail
// // =============================================================
// module mac_tx_scoreboard_simple
// #(
//     parameter int BYTES       = 128,       // 1024-bit datapath
//     parameter int MIN_LEN     = 60,        // pad runt frames up to 60 bytes
//     parameter int VERBOSE     = 1,         // 0=summary, 1=errors, 2=per-frame
//     parameter int MAX_PRINT   = 20
// )(
//     input  logic                clk,
//     input  logic                rst_n,
//     // AXI-Stream input (from user)
//     input  logic                s_tvalid,
//     input  logic                s_tready,
//     input  logic                s_tlast,
//     input  logic [BYTES*8-1:0]  s_tdata,
//     input  logic [BYTES-1:0]    s_tkeep,
//     // MII output (1024-bit CDMII)
//     input  logic [BYTES*8-1:0]  txd,
//     input  logic [BYTES-1:0]    txc,
//     // Reporting
//     input  logic                report,     // pulse to print
//     output longint unsigned     n_err
// );

//     // ---------------- Control codes ----------------
//     localparam logic [7:0] IDLE  = 8'h07;
//     localparam logic [7:0] START = 8'hFB;
//     localparam logic [7:0] TERM  = 8'hFD;
//     localparam logic [7:0] SFD   = 8'hD5;
//     localparam logic [7:0] PRE   = 8'h55;

//     // ---------------- Types ----------------
//     typedef struct {
//         byte unsigned data[$];       // DA..payload (post-pad)
//         logic [31:0]  crc;           // computed FCS
//         longint       id;
//     } pkt_t;

//     // ---------------- State ----------------
//     longint unsigned cyc;
//     pkt_t            exp_q[$];        // expected frames pending on MII
//     pkt_t            cur_exp;         // frame currently being decoded
//     byte unsigned    cur_in_data[$];  // bytes accumulating on AXI

//     bit              in_frame;
//     bit              frame_has_exp;   // do we have a pending expected frame?
//     int              byte_idx;        // position after /S/ (0..frame_len-1)
//     int              frame_len;       // expected number of bytes /S/..before /T/
//     bit              frame_bad;

//     longint unsigned in_pkts, out_pkts, frames_ok, frames_bad, printed;
//     longint unsigned e_pre, e_data, e_fcs, e_term, e_len, e_bound, e_order, e_idle;

//     // ---------------- CRC-32 ----------------
//     function automatic logic [31:0] crc32(input byte unsigned d[$]);
//         logic [31:0] c = 32'hFFFFFFFF;
//         foreach (d[i]) begin
//             c = c ^ {24'h0, d[i]};
//             for (int b = 0; b < 8; b++)
//                 c = (c >> 1) ^ (32'hEDB88320 & {32{c[0]}});
//         end
//         return ~c;
//     endfunction

//     // ---------------- Expected byte at position j (after /S/) ----------------
//     //   j=0..5  : 0x55 preamble
//     //   j=6     : 0xD5 SFD
//     //   j=7..L+6: data
//     //   j=L+7..L+10: FCS (LE)
//     function automatic logic [7:0] wire_byte(pkt_t p, int j);
//         int L = p.data.size();
//         if (j < 6)         return PRE;
//         if (j == 6)        return SFD;
//         if (j < 7 + L)     return p.data[j - 7];
//         return p.crc[8*(j - (7+L)) +: 8];
//     endfunction

//     // Total bytes between /S/ and /T/ (excluding /T/)
//     //   1 (/S/) + 6 (PRE) + 1 (SFD) + L (data) + 4 (FCS)
//     function automatic int frame_bytes(pkt_t p);
//         return 1 + 6 + 1 + p.data.size() + 4;
//     endfunction

//     // ---------------- Error helper ----------------
//     task automatic err(input string cls, input string msg);
//         n_err++;
//         if (VERBOSE > 0 && printed < MAX_PRINT) begin
//             printed++;
//             $display("[SB][ERR] cyc=%0d %-10s %s", cyc, cls, msg);
//         end
//     endtask

//     // ---------------- Reset ----------------
//     task automatic reset_all();
//         cyc = 0; n_err = 0;
//         exp_q.delete(); cur_in_data.delete();
//         in_frame = 0; frame_has_exp = 0;
//         byte_idx = 0; frame_len = 0; frame_bad = 0;
//         in_pkts = 0; out_pkts = 0; frames_ok = 0; frames_bad = 0; printed = 0;
//         e_pre = 0; e_data = 0; e_fcs = 0; e_term = 0;
//         e_len = 0; e_bound = 0; e_order = 0; e_idle = 0;
//     endtask

//     // ---------------- Capture AXI packet ----------------
//     task automatic capture_input();
//         if (!(s_tvalid && s_tready)) return;

//         for (int i = 0; i < BYTES; i++)
//             if (s_tkeep[i]) cur_in_data.push_back(s_tdata[8*i +: 8]);

//         if (s_tlast) begin
//             pkt_t p;
//             while (p.data.size() < MIN_LEN) p.data.push_back(8'h00);   // runt pad
//             foreach (cur_in_data[i]) p.data.push_back(cur_in_data[i]);
//             p.crc = crc32(p.data);
//             p.id  = in_pkts;
//             exp_q.push_back(p);
//             cur_in_data.delete();
//             in_pkts++;
//         end
//     endtask

//     // ---------------- Start a frame on MII ----------------
//     task automatic start_frame(input int byte_pos);
//         if (byte_pos % 8 != 0) begin
//             e_bound++; err("BOUNDARY",
//                 $sformatf("/S/ at byte %0d, not 64-bit lane aligned", byte_pos));
//         end

//         if (exp_q.size() == 0) begin
//             e_order++; err("ORDER", "/S/ with no pending input packet");
//             frame_has_exp = 0;
//         end else begin
//             cur_exp       = exp_q.pop_front();
//             frame_len     = frame_bytes(cur_exp);
//             byte_idx      = 0;
//             frame_bad     = 0;
//             frame_has_exp = 1;
//         end
//         in_frame = 1;
//         out_pkts++;
//     endtask

//     // ---------------- End a frame on MII ----------------
//     task automatic end_frame(input int byte_pos);
//         if (frame_has_exp) begin
//             if (byte_idx != frame_len) begin
//                 e_len++; frame_bad = 1;
//                 err("LENGTH",
//                     $sformatf("frame %0d: got %0d bytes, expected %0d",
//                               cur_exp.id, byte_idx, frame_len));
//             end
//             if (frame_bad) frames_bad++; else frames_ok++;
//         end
//         if (VERBOSE > 1 && frame_has_exp)
//             $display("[SB] frame %0d %s : %0d bytes",
//                      cur_exp.id, frame_bad ? "BAD" : "ok ", byte_idx);

//         in_frame = 0;
//         frame_has_exp = 0;
//     endtask

//     // ---------------- Walk the MII output ----------------
//     task automatic check_mii();
//         for (int i = 0; i < BYTES; i++) begin
//             logic [7:0] ad = txd[8*i +: 8];
//             bit         ac = txc[i];

//             if (!in_frame) begin
//                 // Expect idle or /S/
//                 if (ac && ad == START) begin
//                     start_frame(i);
//                 end
//                 else if (!(ac && ad == IDLE)) begin
//                     e_idle++;
//                     err("IDLE",
//                         $sformatf("byte %0d: expected IDLE 07/c1, got %02h/c%0b",
//                                   i, ad, ac));
//                 end
//             end
//             else begin
//                 // Inside a frame: expect /T/, /S/, or expected content
//                 if (ac && ad == TERM) begin
//                     end_frame(i);
//                 end
//                 else if (ac && ad == START) begin
//                     err("BOUNDARY", "/S/ before /T/ (previous frame truncated)");
//                     end_frame(i);
//                     start_frame(i);
//                 end
//                 else if (frame_has_exp && byte_idx < frame_len) begin
//                     logic [7:0] ed = wire_byte(cur_exp, byte_idx);
//                     if (ad !== ed || ac !== 0) begin
//                         frame_bad = 1;
//                         if (byte_idx < 7) begin
//                             e_pre++;
//                             err("PREAMBLE",
//                                 $sformatf("frame %0d byte %0d: exp %02h/c0, got %02h/c%0b",
//                                           cur_exp.id, byte_idx, ed, ad, ac));
//                         end
//                         else if (byte_idx < frame_len - 4) begin
//                             e_data++;
//                             err("DATA",
//                                 $sformatf("frame %0d payload[%0d]: exp %02h, got %02h",
//                                           cur_exp.id, byte_idx - 7, ed, ad));
//                         end
//                         else begin
//                             e_fcs++;
//                             err("FCS",
//                                 $sformatf("frame %0d FCS[%0d]: exp %02h, got %02h",
//                                           cur_exp.id, byte_idx - (frame_len - 4), ed, ad));
//                         end
//                     end
//                     byte_idx++;
//                 end
//                 else begin
//                     // Past expected length: /T/ was due
//                     e_len++; frame_bad = 1;
//                     err("LENGTH",
//                         $sformatf("frame %0d byte %0d: expected /T/",
//                                   frame_has_exp ? cur_exp.id : -1, byte_idx));
//                     in_frame = 0;
//                     frame_has_exp = 0;
//                 end
//             end
//         end
//     endtask

//     // ---------------- Summary ----------------
//     task automatic print_summary();
//         $display("================================================");
//         $display("[SB] MAC TX Scoreboard Summary");
//         $display("------------------------------------------------");
//         $display("[SB] Input  packets : %0d", in_pkts);
//         $display("[SB] Output frames : %0d", out_pkts);
//         $display("[SB] Frames OK      : %0d", frames_ok);
//         $display("[SB] Frames BAD     : %0d", frames_bad);
//         $display("[SB] Pending on MII : %0d", exp_q.size());
//         $display("[SB] Errors: pre=%0d data=%0d fcs=%0d term=%0d len=%0d bound=%0d order=%0d idle=%0d",
//                  e_pre, e_data, e_fcs, e_term, e_len, e_bound, e_order, e_idle);
//         $display("[SB] Total errors   : %0d", n_err);
//         if (n_err == 0 && exp_q.size() == 0 && !in_frame)
//             $display("[SB] RESULT: PASS");
//         else
//             $display("[SB] RESULT: FAIL");
//         $display("================================================");
//     endtask

//     // ---------------- Main ----------------
//     always @(posedge clk) begin
//         if (!rst_n) begin
//             reset_all();
//         end
//         else begin
//             capture_input();
//             check_mii();
//             cyc++;
//             if (report) print_summary();
//         end
//     end

//     final print_summary();

// endmodule


// =====================================================================
//  Unified MAC TX Scoreboard
//  - CRC matches the RTL parallel CRC (A ⊕ B → rewind → swap → XOR)
//  - Builds expected wire image: /S/ + PRE(6) + SFD + DATA + FCS(4) + /T/
//  - Walks TXD/TXC byte-by-byte → handles multiple frames per beat
//  - Tracks IPG, boundary alignment, length, FCS, preamble, order
// =====================================================================

module mac_tx_scoreboard_simple #(
    parameter int DW         = 1024,
    parameter int KW         = DW/8,        // 128 bytes
    parameter int D          = 16,          // CRC byte groups
    parameter int MDW        = DW/D,        // 64 bits/group
    parameter int BEAT_BYTES = KW,
    parameter int MIN_LEN    = 60,
    parameter int IPG_NOM    = 12,
    parameter int IPG_MIN    = 9,
    parameter int DIC_MAX    = 3,
    parameter int VERBOSE    = 1,
    parameter int MAX_PRINT  = 20
)(
    input  logic              clk,
    input  logic              rst_n,
    // AXI slave (user -> DUT)
    input  logic              s_tvalid,
    input  logic              s_tready,
    input  logic              s_tlast,
    input  logic [DW-1:0]     s_tdata,
    input  logic [KW-1:0]     s_tkeep,
    // MII output (DUT -> line)
    input  logic [DW-1:0]     txd,
    input  logic [KW-1:0]     txc,
    input  logic              report,
    output longint unsigned   n_err
);

    // ------------- Control characters -------------
    localparam logic [7:0] IDLE  = 8'h07;
    localparam logic [7:0] START = 8'hFB;
    localparam logic [7:0] TERM  = 8'hFD;
    localparam logic [7:0] SFD   = 8'hD5;
    localparam logic [7:0] PRE   = 8'h55;

    // ------------- CRC constants -------------
    localparam logic [31:0] CRC_INIT   = 32'hFFFFFFFF;
    localparam logic [31:0] CRC_XOROUT = 32'hFFFFFFFF;
    localparam logic [31:0] CRC_POLY   = 32'hEDB88320;

    // =================================================================
    //  CRC model (matches RTL)
    // =================================================================
    function automatic logic [31:0] crc_step(input logic [31:0] c, input logic b);
        logic fb;
        fb = c[0] ^ b;
        return (c >> 1) ^ (fb ? CRC_POLY : 32'h0);
    endfunction

    function automatic logic [31:0] crc_rstep(input logic [31:0] c);
        logic fb;
        logic [30:0] t;
        fb = c[31];
        t  = c[30:0] ^ (fb ? CRC_POLY[30:0] : 31'h0);
        return {t, fb};
    endfunction

    function automatic logic [DW-1:0] mask_by_keep(input logic [DW-1:0] d,
                                                   input logic [KW-1:0] k);
        logic [DW-1:0] m = '0;
        for (int b = 0; b < KW; b++)
            if (k[b]) m[8*b +: 8] = d[8*b +: 8];
        return m;
    endfunction

    function automatic int count_keep(input logic [KW-1:0] k);
        int n = 0;
        for (int b = 0; b < KW; b++) n += int'(k[b]);
        return n;
    endfunction

    function automatic logic [31:0] a_advance(input logic [31:0] st);
        logic [31:0] s = st;
        for (int k = 0; k < DW; k++) s = crc_step(s, 1'b0);
        return s;
    endfunction

    function automatic logic [31:0] b_group(input logic [DW-1:0] d, int g);
        logic [31:0] s = '0;
        int lo = g * MDW;
        int hi = lo + MDW;
        for (int k = 0; k < DW; k++)
            s = crc_step(s, (k >= lo && k < hi) ? d[k] : 1'b0);
        return s;
    endfunction

    function automatic logic [31:0] corr_rewind(input logic [31:0] c,
                                                input int n_valid);
        logic [31:0] s = c;
        int k = (BEAT_BYTES - n_valid) * 8;
        for (int i = 0; i < k; i++) s = crc_rstep(s);
        return s;
    endfunction

    // Reference bit-serial CRC over a padded byte stream.
    // Returns the RTL-equivalent value: byte-swap(corrected) ^ CRC_XOROUT.
    function automatic logic [31:0] rtl_fcs(input byte unsigned d[$]);
        logic [31:0] c = CRC_INIT;
        int n = d.size();
        for (int i = 0; i < n; i++)
            for (int b = 0; b < 8; b++)
                c = crc_step(c, d[i][b]);
        return {c[7:0], c[15:8], c[23:16], c[31:24]} ^ CRC_XOROUT;
    endfunction

    // =================================================================
    //  Expected packet
    // =================================================================
    typedef struct {
        byte unsigned data[$];      // padded payload
        logic [31:0]  fcs;          // RTL-order FCS (already byte-swapped+XORed)
        longint       id;
    } pkt_t;

    // Expected byte at position j (0-based, after /S/)
    //  j = 0..5        : 6 more 0x55 preamble
    //  j = 6           : SFD (0xD5)
    //  j = 7..7+L-1    : data
    //  j = 7+L..10+L   : FCS  (MSB-first: fcs[31:24], fcs[23:16], fcs[15:8], fcs[7:0])
    function automatic logic [7:0] wire_byte(pkt_t p, int j);
        int L = p.data.size();
        if (j < 6)              return PRE;
        if (j == 6)             return SFD;
        if (j < 7 + L)          return p.data[j - 7];
        case (j - (7 + L))
            0: return p.fcs[31:24];
            1: return p.fcs[23:16];
            2: return p.fcs[15:8];
            3: return p.fcs[7:0];
        endcase
        return 8'h00;
    endfunction

    // Bytes between /S/ and /T/ (exclusive of both)
    function automatic int frame_bytes(pkt_t p);
        return 6 + 1 + p.data.size() + 4;   // PRE(6) + SFD + L + FCS(4)
    endfunction

    // =================================================================
    //  Scoreboard state
    // =================================================================
    longint unsigned cyc;
    pkt_t            exp_q[$];
    pkt_t            cur_exp;
    byte unsigned    cur_in_data[$];

    bit              in_frame;
    bit              has_exp;
    int              byte_idx;          // index after /S/
    int              frame_len;         // expected length after /S/
    bit              frame_bad;

    // Counters
    longint unsigned in_pkts, out_pkts, frames_ok, frames_bad, printed;
    longint unsigned e_pre, e_data, e_fcs, e_len, e_bound, e_order, e_idle;
    longint unsigned ipg_sum, ipg_cnt, ipg_min, ipg_max;

    bit              have_prev_t;
    longint unsigned prev_t_pos;

    // =================================================================
    //  Helpers
    // =================================================================
    task automatic err(input string cls, input string msg);
        n_err++;
        if (VERBOSE > 0 && printed < MAX_PRINT) begin
            printed++;
            $display("[SB][ERR] cyc=%0d %-10s %s", cyc, cls, msg);
        end
    endtask

    task automatic reset_all();
        cyc = 0; n_err = 0;
        exp_q.delete(); cur_in_data.delete();
        in_frame = 0; has_exp = 0;
        byte_idx = 0; frame_len = 0; frame_bad = 0;
        in_pkts = 0; out_pkts = 0; frames_ok = 0; frames_bad = 0; printed = 0;
        e_pre =0; e_data =0; e_fcs =0; e_len =0; e_bound =0; e_order =0; e_idle =0; 
        ipg_sum = 0; ipg_cnt = 0; ipg_min = '1; ipg_max = 0;
        have_prev_t = 0; prev_t_pos = 0;
    endtask

    // ------------- AXI capture -------------
    task automatic capture_input();
        if (!(s_tvalid && s_tready)) return;
        for (int i = 0; i < KW; i++)
            if (s_tkeep[i]) cur_in_data.push_back(s_tdata[8*i +: 8]);
        if (s_tlast) begin
            pkt_t p;
            foreach (cur_in_data[i]) p.data.push_back(cur_in_data[i]);
            while (p.data.size() < MIN_LEN) p.data.push_back(8'h00);   // runt pad
            p.fcs = rtl_fcs(p.data);                                    // matches RTL
            //p.fcs = {p.fcs[7:0],p.fcs[15:8],p.fcs[23:16],p.fcs[31:24]};
            p.id  = in_pkts;
            exp_q.push_back(p);
            cur_in_data.delete();
            in_pkts++;
        end
    endtask

    // ------------- Frame boundaries on MII -------------
    task automatic start_frame(input int byte_pos, input longint unsigned pos);
        if (byte_pos % 8 != 0) begin
            e_bound++;
            err("BOUNDARY",
                $sformatf("/S/ at byte %0d (not 64-bit lane aligned)", byte_pos));
        end
        // IPG: distance from previous /T/ to this /S/ (includes /T/)
        if (have_prev_t) begin
            longint unsigned gap = pos - prev_t_pos;
            ipg_sum += gap;
            if (ipg_cnt == 0 || gap < ipg_min) ipg_min = gap;
            if (gap > ipg_max) ipg_max = gap;
            ipg_cnt++;
        end

        if (exp_q.size() == 0) begin
            e_order++;
            err("ORDER", "/S/ with no pending input packet");
            has_exp = 0;
        end else begin
            cur_exp   = exp_q.pop_front();
            frame_len = frame_bytes(cur_exp);
            byte_idx  = 0;
            frame_bad = 0;
            has_exp   = 1;
        end
        in_frame = 1;
        out_pkts++;
    endtask

    task automatic end_frame(input longint unsigned pos);
        if (has_exp) begin
            if (byte_idx != frame_len) begin
                e_len++;
                frame_bad = 1;
                err("LENGTH",
                    $sformatf("frame %0d: got %0d bytes after /S/, expected %0d",
                              cur_exp.id, byte_idx, frame_len));
            end
            if (frame_bad) frames_bad++; else frames_ok++;
        end
        in_frame    = 0;
        has_exp     = 0;
        have_prev_t = 1;
        prev_t_pos  = pos;
    endtask

    // ------------- Walk MII output byte-by-byte -------------
    task automatic check_mii();
        for (int i = 0; i < KW; i++) begin
            logic [7:0] ad = txd[8*i +: 8];
            bit         ac = txc[i];
            longint unsigned pos = cyc * KW + i;

            if (!in_frame) begin
                if (ac && ad == START) begin
                    start_frame(i, pos);
                end
                else if (!(ac && ad == IDLE)) begin
                    e_idle++;
                    err("IDLE",
                        $sformatf("byte %0d: exp IDLE 07/c1, got %02h/c%0b",
                                  i, ad, ac));
                end
            end
            else begin
                // Inside a frame
                if (ac && ad == TERM) begin
                    end_frame(pos);
                end
                else if (ac && ad == START) begin
                    err("BOUNDARY", "/S/ before /T/ (truncated frame)");
                    end_frame(pos);
                    start_frame(i, pos);
                end
                else if (has_exp && byte_idx < frame_len) begin
                    logic [7:0] ed = wire_byte(cur_exp, byte_idx);
                    if (ad !== ed || ac !== 0) begin
                        frame_bad = 1;
                        if (byte_idx < 7) begin
                            e_pre++;
                            err("PREAMBLE",
                                $sformatf("frame %0d byte %0d: exp %02h, got %02h/c%0b",
                                          cur_exp.id, byte_idx, ed, ad, ac));
                        end
                        else if (byte_idx < frame_len - 4) begin
                            e_data++;
                            err("DATA",
                                $sformatf("frame %0d payload[%0d]: exp %02h, got %02h",
                                          cur_exp.id, byte_idx - 7, ed, ad));
                        end
                        else begin
                            e_fcs++;
                            err("FCS",
                                $sformatf("frame %0d FCS[%0d]: exp %02h, got %02h",
                                          cur_exp.id,
                                          byte_idx - (frame_len - 4), ed, ad));
                        
                            //$stop()
                        end
                    end
                    byte_idx++;
                end
                else begin
                    e_len++; frame_bad = 1;
                    err("LENGTH",
                        $sformatf("expected /T/ at byte %0d, got %02h/c%0b",
                                  byte_idx, ad, ac));
                    in_frame = 0;
                    has_exp  = 0;
                end
            end
        end
    endtask

    // ------------- Report -------------
    task automatic print_summary();
        real avg_ipg = (ipg_cnt > 0) ? real'(ipg_sum) / ipg_cnt : 0.0;
        $display("======================================================");
        $display("[SB] MAC TX Scoreboard Summary");
        $display("------------------------------------------------------");
        $display("[SB] cyc              : %0d", cyc);
        $display("[SB] Input  packets   : %0d", in_pkts);
        $display("[SB] Output frames   : %0d", out_pkts);
        $display("[SB] Frames OK        : %0d", frames_ok);
        $display("[SB] Frames BAD       : %0d", frames_bad);
        $display("[SB] Pending on MII   : %0d", exp_q.size());
        $display("[SB] Errors: pre=%0d data=%0d fcs=%0d len=%0d bound=%0d order=%0d idle=%0d",
                 e_pre, e_data, e_fcs, e_len, e_bound, e_order, e_idle);
        if (ipg_cnt > 0)
            $display("[SB] IPG /T/../S/ min/avg/max = %0d/%0.2f/%0d bytes",
                     ipg_min, avg_ipg, ipg_max);
        $display("[SB] Total errors     : %0d", n_err);
        if (n_err == 0 && exp_q.size() == 0 && !in_frame)
            $display("[SB] RESULT: PASS");
        else
            $display("[SB] RESULT: FAIL");
        $display("======================================================");
    endtask

    // ------------- Main -------------
    always @(posedge clk) begin
        if (!rst_n) reset_all();
        else begin
            capture_input();
            check_mii();
            cyc++;
            if (report) print_summary();
        end
    end

    final print_summary();

endmodule