// module mac_bw_monitor #(
//   parameter int BYTES  = 128,       // 1024-bit datapath
//   parameter int WINDOW = 781250     // cycles per window (1 ms at 781.25 MHz)
// )(
//   input  logic                clk, rst_n,
//   // user side (AXI-Stream)
//   input  logic                s_tvalid, s_tready, s_tlast,
//   input  logic [BYTES-1:0]    s_tkeep,
//   // MII side
//   input  logic [BYTES*8-1:0]  txd,
//   input  logic [BYTES-1:0]    txc,
//   // results, updated once per window
//   output logic                win_done,
//   output logic [47:0]         r_in_bytes, r_frames_in,
//   output logic [47:0]         r_out_bytes, r_frames_out,
//   output logic [47:0]         r_idle_bytes, r_idle_beats,
//   output logic [47:0]         r_stall_cycles
// );
//   // ---- per-cycle decode of the MII beat ----
//   int unsigned c_start, c_term, c_idle, c_data;
//   always_comb begin
//     c_start = 0; c_term = 0; c_idle = 0; c_data = 0;
//     for (int i = 0; i < BYTES; i++) begin
//       if (!txc[i])                                             c_data++;
//       else if (txd[8*i +: 8] == 8'h07)                         c_idle++;
//       else if (txd[8*i +: 8] == 8'hFB && (i % 8) == 0)         c_start++;
//       else if (txd[8*i +: 8] == 8'hFD)                         c_term++;
//     end
//   end
//   wire in_beat   = s_tvalid && s_tready;
//   wire idle_beat = (c_idle == BYTES);
//   // frame + FCS bytes on the wire = data bytes minus 7 preamble/SFD bytes per frame
//   wire [31:0] c_frame_fcs = c_data - 7*c_start;

//   // ---- accumulators ----
//   logic [31:0] cyc;
//   logic [47:0] a_in, a_fin, a_out, a_fout, a_idle, a_ibeat, a_stall;

//   always_ff @(posedge clk or negedge rst_n) begin
//     if (!rst_n) begin
//       cyc <= 0; win_done <= 0;
//       a_in <= 0; a_fin <= 0; a_out <= 0; a_fout <= 0;
//       a_idle <= 0; a_ibeat <= 0; a_stall <= 0;
//     end else begin
//       win_done <= 0;
//       a_in    <= a_in    + (in_beat ? $countones(s_tkeep) : 0);
//       a_fin   <= a_fin   + (in_beat && s_tlast);
//       a_out   <= a_out   + c_frame_fcs;          // includes 4-byte FCS
//       a_fout  <= a_fout  + c_term;               // count frames at /T/
//       a_idle  <= a_idle  + c_idle;
//       a_ibeat <= a_ibeat + idle_beat;
//       a_stall <= a_stall + (s_tvalid && !s_tready);
//       if (cyc == WINDOW-1) begin
//         cyc <= 0; win_done <= 1;
//         r_in_bytes <= a_in;   r_frames_in <= a_fin;
//         r_out_bytes <= a_out; r_frames_out <= a_fout;
//         r_idle_bytes <= a_idle; r_idle_beats <= a_ibeat;
//         r_stall_cycles <= a_stall;
//         a_in <= 0; a_fin <= 0; a_out <= 0; a_fout <= 0;
//         a_idle <= 0; a_ibeat <= 0; a_stall <= 0;
//       end else cyc <= cyc + 1;
//     end
//   end
// endmodule
// The window is a cycle count, not a time. WINDOW = 781250 is 1 ms only if the clock is 781.25 MHz, and at your 1 GHz it is 0.78125 ms. Everything that depends on time (Gb/s numbers) has to be recomputed for 1 GHz. Everything that is a ratio does not change.

// Why 781.25 MHz appeared in my numbers

// An 800G MII is 1024 bits wide, so the clock has to be:

// 800e9 bit/s ÷ 1024 bit = 781.25 MHz   (period 1.28 ns)

// At that clock the bus is 100% full at line rate: 128 bytes per cycle is exactly 800 Gb/s. My earlier factor bytes × 6.25 / W came from 8 / 1.28 ns.

// What changes at 1 GHz

// A 1024-bit bus at 1 GHz moves 1024 Gb/s, which is 1.28× the 800G line rate. So your TB is not really an 800G MII. It is a 1.024T-capable interface, and 800G corresponds to 100 bytes per cycle (78.125% of the bus).

// Quantity	At 781.25 MHz	At 1 GHz
// Clock period	1.28 ns	1.0 ns
// Bus capacity	800 Gb/s	1024 Gb/s
// 800G = bytes per cycle	128 (full)	100 (78.125%)
// Goodput (Gb/s)	bytes × 6.25 / W	bytes × 8 / W
// Ideal goodput for size L, saturated	800 × L/(L+24)	1024 × L/(L+24)
// 1 ms window (W)	781,250	1,000,000

// Ideal at 1 GHz for the sizes I gave earlier:

// L	Ideal goodput at 1 GHz
// 60	731.4 Gb/s
// 1514	1008.6 Gb/s
// 9000	1021.2 Gb/s
// What this means for pass/fail

// Do not compare a 1 GHz run against the 800G ideal and call a pass. The comparison is only meaningful in one of these two ways:

// Set the TB clock to 781.25 MHz (period 1.28 ns). This is the right check for 800G because the bus has no headroom, so any stall, alignment loss or DIC bug shows up as missing throughput. Use timescale 1ns/1ps and a half-period of 640 ps, which is exact. This is what I'd recommend.
// Stay at 1 GHz and use a clock-independent target. Measure bytes per cycle and require in_bytes / W ≥ 100 × L/(L+24). That is the 800G requirement expressed per cycle. It passes if the design can sustain at least 800G, but it hides bugs that cost less than 22% of the bus, so it is a weaker test.

// Also note that at 1 GHz your output wire rate would exceed 800G. If you also model a PHY or receiving checker that assumes 800G, you would be overrunning it.

// Choosing the window

// Time only sets the scale, so pick the window for statistics:

// Long enough for boundary error to vanish. A frame straddling the window edge causes about ±1 frame of error. For 60-byte frames (about 1.5 beats each) a window of 100,000 cycles has around 67,000 frames, so the error is about 0.0015%. You don't need 1 ms.
// Long enough for the slowest pattern to repeat. DIC alignment repeats every few frames. For jumbo 9000-byte frames (about 71 beats each) 100,000 cycles is still more than a thousand frames.
// Then report ratios, which don't depend on the clock:
// Wire utilisation: 1 − idle_bytes / (128 × W)
// Efficiency: data bytes on the wire / (128 × W). At 781.25 MHz a saturated 60-byte run should show about 71.4% wire efficiency (60/84). Note this is payload bytes only, not the FCS.
// Small change to the monitor

// Add the clock period as a parameter and compute Gb/s from it, so the same code works at either clock:

// systemverilog
// parameter real CLK_PERIOD_NS = 1.28;   // 1.0 for your 1 GHz TB
// // in the report/testbench, per window:
// //   goodput_gbps = (r_in_bytes * 8.0) / (WINDOW * CLK_PERIOD_NS);
// //   ideal_gbps   = (128.0 * 8.0 / CLK_PERIOD_NS) * L / (L + 24.0);

// Here the ideal_gbps line uses the full bus capacity (1024 / period) and scales by L/(L+24). It gives 800 × L/(L+24) at 1.28 ns and 1024 × L/(L+24) at 1.0 ns.

// To decide between the two options: if your real target clock in the FPGA is not 781.25 MHz (for example the Agilex fabric will not close 781 MHz on a 1024-bit path), tell me what you plan to run at and I'll redo the target numbers for that clock.
// `timescale 1ns/1ps
// module mac_bw_monitor #(
//   parameter int  BYTES     = 128,
//   parameter real PERIOD_NS = 1.28          // 781.25 MHz
// )(
//   input  logic               clk, rst_n,
//   input  logic               clear,        // re-arm: discard results, wait for next frame
//   input  logic               report,       // pulse when the run is done and drained
//   // DUT input (AXI-Stream)
//   input  logic               s_tvalid, s_tready, s_tlast,
//   input  logic [BYTES-1:0]   s_tkeep,
//   // DUT output (MII)
//   input  logic [BYTES*8-1:0] txd,
//   input  logic [BYTES-1:0]   txc
// );
//   localparam logic [7:0] IDLE = 8'h07, START = 8'hFB, TERM = 8'hFD;

//   logic [63:0] cyc;
//   always_ff @(posedge clk or negedge rst_n)
//     if (!rst_n) cyc <= 0; else cyc <= cyc + 1;

//   // ---------------- input side ----------------
//   logic        in_started;
//   logic [63:0] in_first, in_last, in_bytes, in_frames, in_stall;
//   wire         in_beat = s_tvalid && s_tready;

//   // ---------------- output side: per-beat decode ----------------
//   logic        out_started;
//   logic [63:0] out_first_cyc, out_first_pos, out_last_pos;
//   logic [63:0] tot_idle, tot_data, tot_s, tot_t;        // running, since first /S/
//   logic [63:0] snap_idle, snap_data, snap_s, snap_t;    // as of the last /T/

//   logic        started_c, any_T;
//   int unsigned first_S_idx, last_T_idx;
//   logic [31:0] b_idle, b_data, b_s, b_t;   // whole beat, counted only after start
//   logic [31:0] u_idle, u_data, u_s, u_t;   // same, but up to and including the last /T/

//   always_comb begin
//     started_c = out_started;  any_T = 0;  first_S_idx = 0;  last_T_idx = 0;
//     b_idle = 0; b_data = 0; b_s = 0; b_t = 0;
//     u_idle = 0; u_data = 0; u_s = 0; u_t = 0;
//     for (int i = 0; i < BYTES; i++) begin
//       logic is_s, is_t, is_i, is_d;
//       is_s = txc[i] && (txd[8*i +: 8] == START) && (i % 8 == 0);
//       is_t = txc[i] && (txd[8*i +: 8] == TERM);
//       is_i = txc[i] && (txd[8*i +: 8] == IDLE);
//       is_d = !txc[i];
//       if (!started_c && is_s) begin started_c = 1; first_S_idx = i; end
//       if (started_c) begin                 // bytes before the first /S/ are ignored
//         if (is_i) b_idle++;
//         if (is_d) b_data++;
//         if (is_s) b_s++;
//         if (is_t) b_t++;
//         if (is_t) begin
//           any_T = 1;  last_T_idx = i;
//           u_idle = b_idle; u_data = b_data; u_s = b_s; u_t = b_t;
//         end
//       end
//     end
//   end

//   // ---------------- accumulators ----------------
//   always_ff @(posedge clk) begin
//     if (!rst_n || clear) begin
//       in_started <= 0; in_first <= 0; in_last <= 0;
//       in_bytes <= 0; in_frames <= 0; in_stall <= 0;
//       out_started <= 0; out_first_cyc <= 0; out_first_pos <= 0; out_last_pos <= 0;
//       tot_idle <= 0; tot_data <= 0; tot_s <= 0; tot_t <= 0;
//       snap_idle <= 0; snap_data <= 0; snap_s <= 0; snap_t <= 0;
//     end else begin
//       // input: starts on the first accepted beat
//       if (in_beat) begin
//         if (!in_started) begin in_started <= 1; in_first <= cyc; end
//         in_last   <= cyc;
//         in_bytes  <= in_bytes  + $countones(s_tkeep);
//         in_frames <= in_frames + s_tlast;
//       end
//       if (in_started && s_tvalid && !s_tready) in_stall <= in_stall + 1;

//       // output: starts at the first /S/
//       if (!out_started && started_c) begin
//         out_started   <= 1;
//         out_first_cyc <= cyc;
//         out_first_pos <= cyc * BYTES + first_S_idx;
//       end
//       if (started_c) begin
//         tot_idle <= tot_idle + b_idle;  tot_data <= tot_data + b_data;
//         tot_s    <= tot_s    + b_s;     tot_t    <= tot_t    + b_t;
//         if (any_T) begin                 // freeze counts at the newest /T/
//           out_last_pos <= cyc * BYTES + last_T_idx;
//           snap_idle <= tot_idle + u_idle;  snap_data <= tot_data + u_data;
//           snap_s    <= tot_s    + u_s;     snap_t    <= tot_t    + u_t;
//         end
//       end
//     end
//   end

//   // ---------------- report ----------------
//   task automatic print_report;
//     real in_cycles, span, in_gbps, out_gbps, avg_ipg, lat_ns;
//      real occ, bpf, line_util, out_cycles, line_min_cycles;
//     longint unsigned payload;
//     if (!in_started || !out_started || snap_t == 0) begin
//       $display("[BW] no traffic measured"); return;
//     end
//     in_cycles = in_last - in_first + 1;
//     in_gbps   = in_bytes * 8.0 / (in_cycles * PERIOD_NS);
//     span      = out_last_pos - out_first_pos + 1;               // bytes, /S/ .. /T/ inclusive
//     payload   = snap_data - 11 * snap_t;                        // minus 7 preamble/SFD and 4 FCS per frame
//     out_gbps  = payload * 8.0 * BYTES / (span * PERIOD_NS);
//     avg_ipg   = (snap_t > 1) ? ((snap_t - 1) + snap_idle) / (snap_t - 1.0) : 0.0;

//     //occ             = in_bytes * 1.0 / (in_beats * BYTES);          // AXIS byte occupancy
//     //bpf             = in_bytes * 1.0 / in_frames;                   // avg bytes per frame
//     //line_util       = 100.0 * (span - snap_idle) / span;            // real wire utilisation
//     //out_cycles      = span / BYTES;
//     //line_min_cycles = (in_bytes + 24.0 * in_frames) / BYTES;        // cycles the line needs at 100% load
//     //lat_ns    = (out_first_cyc - in_first) * PERIOD_NS;

//     $display("[BW] frames in/out      : %0d / %0d", in_frames, snap_t);
//     $display("[BW] input rate         : %8.2f Gb/s over %0d cycles (stalls %0d)",
//              in_gbps, in_cycles, in_stall);
//     $display("[BW] output goodput     : %8.2f Gb/s over %0d wire bytes", out_gbps, span);
//     $display("[BW] wire efficiency    : %6.2f %% of 800G", 100.0 * out_gbps / 800.0);
//     $display("[BW] avg IPG (incl /T/) : %6.3f bytes  (spec >= 12, ~12 when saturated)", avg_ipg);
//     $display("[BW] latency first in->/S/ : %0.1f ns", lat_ns);
//     if (snap_idle + snap_data + snap_s + snap_t != span)
//       $error("[BW] byte accounting mismatch: %0d vs span %0d",
//              snap_idle + snap_data + snap_s + snap_t, span);
//     if (snap_s != snap_t) $error("[BW] /S/ count %0d != /T/ count %0d", snap_s, snap_t);
//     if (in_frames != snap_t) $error("[BW] frames lost or not yet drained");
//     if (in_bytes != payload) $display("[BW] note: in_bytes %0d != out payload %0d (padding or drain)",
//                                       in_bytes, payload);
//   endtask

// // new accumulator: in_beats <= in_beats + 1;  (in the in_beat block, cleared with the others)
//   always @(posedge report) print_report();
// endmodule


`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// MAC TX bandwidth monitor  (AXI-Stream in  ->  xMII out)
//   * Input window : opens at the first accepted *start-of-frame* beat after clear,
//                    closes at the tlast of frame N. Only complete frames count.
//   * Output window: opens at the /S/ of the SAME frame (matched by frame index),
//                    closes at its /T/ of frame N. Idle between frames is counted.
//   * Time base    : N frames occupy N slots = (first /S/ .. last /T/) + the
//                    mandatory (IPG_NOM-1) idle bytes that follow the last /T/.
// -----------------------------------------------------------------------------
module mac_bw_monitor #(
  parameter int  BYTES     = 128,    // 1024-bit datapath
  parameter real PERIOD_NS = 1.28,   // 781.25 MHz -> 800 Gb/s
  parameter int  IPG_NOM   = 12,     // 96 bit times, /T/ counted inside the IPG
  parameter int  IPG_MIN   = 9,      // shortest single gap allowed (set per Clause 170)
  parameter int  DIC_MAX   = 3,      // deficit idle count limit    (set per Clause 170)
  parameter int  MIN_LEN   = 60      // DA..payload bytes before FCS
)(
  input  logic               clk, rst_n,
  input  logic               clear,      // arm: measure from the next frame that arrives on AXIS
  input  logic [31:0]        n_frames,   // window length in frames, sampled on clear/reset. 0 = use 'report'
  input  logic               report,     // force the report (needed when n_frames == 0)
  // DUT input (AXI-Stream)
  input  logic               s_tvalid, s_tready, s_tlast,
  input  logic [BYTES-1:0]   s_tkeep,
  // DUT output (xMII)
  input  logic [BYTES*8-1:0] txd,
  input  logic [BYTES-1:0]   txc
);
  localparam logic [7:0] IDLE = 8'h07, START = 8'hFB, TERM = 8'hFD;
  localparam int FRAME_OVH = 13;     // S + 7 preamble/SFD + 4 FCS + T  (bytes inside S..T that are not payload)

  typedef struct {
    longint unsigned idle, data, s, t, other, idle_beats;
    longint unsigned first_pos, last_pos;
    longint unsigned gaps, ipg_sum, ipg_min, ipg_max, ipg_short, ipg_long, ipg_below_min;
    longint          dic, dic_max;
    longint unsigned dic_viol;
    longint unsigned len_min, len_max, len_sum, runts;
    longint unsigned slot_min, slot_max;
    longint unsigned lat_n, lat_sum, lat_min, lat_max;
  } st_t;

  st_t run, snap;                    // snap = copy of run taken at every /T/ inside the window

  longint unsigned cyc;
  logic            armed, reported;
  int unsigned     n_cfg;
  // input side
  logic            in_sop, in_open, in_done;
  longint unsigned in_sop_cnt, in_start_idx, in_first_cyc, in_last_cyc;
  longint unsigned in_bytes, in_frames, in_beats, cur_bytes, cur_beats;
  longint unsigned stall_run, gap_run, in_stall, in_gap;
  longint unsigned sop_q[$];
  // output side
  logic            out_open, out_done, in_frm_o, have_t, have_s;
  longint unsigned out_s_idx, out_first_cyc, prev_t_pos, prev_s_pos, cur_s_pos, proto_err;

  function automatic void init_run();
    run = '{default: 0};
    run.ipg_min = '1; run.len_min = '1; run.slot_min = '1; run.lat_min = '1;
    snap = run;
  endfunction

  function automatic void clear_window();
    in_open = 0; in_done = 0; out_open = 0; out_done = 0; have_t = 0; have_s = 0;
    in_first_cyc = 0; in_last_cyc = 0; in_bytes = 0; in_frames = 0; in_beats = 0;
    cur_bytes = 0; cur_beats = 0; stall_run = 0; gap_run = 0; in_stall = 0; in_gap = 0;
    sop_q.delete();
    init_run();
  endfunction

  task automatic perr(input string msg, input longint unsigned cy, input int bi);
    proto_err++;
    if (proto_err <= 5) $error("[BW] xMII protocol: %s (cyc %0d, byte %0d)", msg, cy, bi);
  endtask

  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    bit              in_beat;
    logic [7:0]      b;
    logic            c, is_s, is_t, is_i, is_d;
    longint unsigned pos, ipg, slot, flen, lat;
    int unsigned     nidle_l;

    if (!rst_n) begin
      cyc = 0; armed = 1; reported = 0; n_cfg = n_frames;
      in_sop = 1; in_sop_cnt = 0; out_s_idx = 0; in_frm_o = 0; proto_err = 0;
      prev_t_pos = 0; prev_s_pos = 0; cur_s_pos = 0; out_first_cyc = 0; in_start_idx = 0;
      clear_window();
    end else begin
      if (clear) begin armed = 1; reported = 0; n_cfg = n_frames; clear_window(); end

      // ============================ INPUT (AXIS) ============================
      in_beat = s_tvalid && s_tready;
      if (in_beat && in_sop) begin                       // accepted start-of-frame beat
        if (armed) begin
          armed = 0; in_open = 1; in_start_idx = in_sop_cnt; in_first_cyc = cyc;
        end
        if (in_open && !in_done) sop_q.push_back(cyc);
        in_sop_cnt++;
      end
      if (in_beat) begin
        if (in_open && !in_done) begin
          cur_bytes += $countones(s_tkeep);
          cur_beats++;
          if (s_tlast) begin                             // frame complete -> commit it
            in_bytes += cur_bytes; in_beats += cur_beats; in_frames++;
            cur_bytes = 0; cur_beats = 0; in_last_cyc = cyc;
            in_stall = stall_run; in_gap = gap_run;
            if (n_cfg != 0 && in_frames == n_cfg) in_done = 1;
          end
        end
        in_sop = s_tlast;
      end
      if (in_open && !in_done) begin
        if (s_tvalid && !s_tready) stall_run++;
        if (!s_tvalid)             gap_run++;
      end

      // ============================ OUTPUT (xMII) ===========================
      nidle_l = 0;
      for (int i = 0; i < BYTES; i++) begin
        b    = txd[8*i +: 8];
        c    = txc[i];
        pos  = cyc * BYTES + i;
        is_s = c && (b == START) && (i % 8 == 0);        // /S/ only in byte 0 of a 64-bit lane
        is_t = c && (b == TERM);
        is_i = c && (b == IDLE);
        is_d = !c;

        // ---- xMII protocol checker (always on) ----
        if (is_s) begin
          if (in_frm_o) perr("/S/ inside a frame", cyc, i);
          in_frm_o = 1;
        end else if (is_t) begin
          if (!in_frm_o) perr("/T/ outside a frame", cyc, i);
          in_frm_o = 0;
        end else if (c && in_frm_o)        perr("control/idle byte inside a frame", cyc, i);
        else if (!c && !in_frm_o)          perr("data byte outside a frame", cyc, i);
        else if (c && !is_i)               perr("unexpected control char (misaligned /S/, /E/, ordered set)", cyc, i);

        // ---- open the output window at the /S/ of the frame the input window started with ----
        if (is_s && in_open && !out_open && !out_done && out_s_idx == in_start_idx) begin
          out_open = 1; out_first_cyc = cyc; run.first_pos = pos; have_t = 0; have_s = 0;
        end
        if (is_s) out_s_idx++;

        // ---- measurement ----
        if (out_open && !out_done) begin
          if      (is_i) begin run.idle++; nidle_l++; end
          else if (is_d) run.data++;
          else if (is_s) run.s++;
          else if (is_t) run.t++;
          else           run.other++;

          if (is_s) begin
            if (have_t) begin                            // gap: /T/ .. last idle before this /S/, /T/ counted
              ipg = pos - prev_t_pos;
              run.gaps++;  run.ipg_sum += ipg;
              if (ipg < run.ipg_min) run.ipg_min = ipg;
              if (ipg > run.ipg_max) run.ipg_max = ipg;
              if (ipg < IPG_NOM) run.ipg_short++;
              if (ipg > IPG_NOM) run.ipg_long++;
              if (ipg < IPG_MIN) run.ipg_below_min++;
              run.dic = run.dic + (IPG_NOM - longint'(ipg));   // DIC: +deleted, -inserted, never below 0
              if (run.dic < 0) run.dic = 0;
              if (run.dic > run.dic_max) run.dic_max = run.dic;
              if (run.dic > DIC_MAX) run.dic_viol++;
            end
            if (have_s) begin
              slot = pos - prev_s_pos;                   // /S/ to /S/ distance
              if (slot < run.slot_min) run.slot_min = slot;
              if (slot > run.slot_max) run.slot_max = slot;
            end
            if (sop_q.size() != 0) begin                 // latency: first input beat -> /S/
              lat = cyc - sop_q.pop_front();
              run.lat_n++; run.lat_sum += lat;
              if (lat < run.lat_min) run.lat_min = lat;
              if (lat > run.lat_max) run.lat_max = lat;
            end
            cur_s_pos = pos; prev_s_pos = pos; have_s = 1;
          end

          if (is_t) begin
            flen = pos - cur_s_pos + 1 - FRAME_OVH;      // user bytes DA..end of payload/pad
            run.len_sum += flen;
            if (flen < run.len_min) run.len_min = flen;
            if (flen > run.len_max) run.len_max = flen;
            if (flen < MIN_LEN)     run.runts++;
            have_t = 1; prev_t_pos = pos;
            run.last_pos = pos;
            snap = run;                                  // consistent copy up to this /T/
            if (n_cfg != 0 && run.t == n_cfg) out_done = 1;
          end
        end
      end
      if (nidle_l == BYTES) run.idle_beats++;            // beat fully inside the window and entirely idle

      cyc = cyc + 1;
      if (!reported && ((n_cfg != 0 && in_done && out_done) || report)) begin
        reported = 1;
        print_report();
      end
    end
  end

  // ---------------------------------------------------------------------------
  task automatic print_report;
    longint N, payload, span, wire_total, nominal, excess, in_cyc, nominal_in, spare_src, src_share, dut_share;
    real    line_gbps, t_ns, goodput, mac_rate, wire_rate, util, mfps, mfps_max, avg_ipg, avg_len, lat_avg, in_gbps;
    N = snap.t;
    if (!in_open || N == 0) begin
      $display("[BW] no traffic measured"); return;
    end
    payload    = longint'(snap.data) - 11 * N;                      // data bytes = 7 preamble/SFD + payload + 4 FCS per frame
    span       = longint'(snap.last_pos) - longint'(snap.first_pos) + 1;
    wire_total = span + (IPG_NOM - 1);                              // add the mandatory idle after the last /T/
    nominal    = payload + (4 + 8 + IPG_NOM) * N;                   // payload + FCS + preamble/SFD + 12 B IPG
    excess     = wire_total - nominal;                              // >0 idle beyond the standard minimum, <0 DIC savings
    t_ns       = real'(wire_total) / BYTES * PERIOD_NS;
    line_gbps  = BYTES * 8.0 / PERIOD_NS;
    goodput    = payload * 8.0 / t_ns;
    mac_rate   = (payload + 4 * N) * 8.0 / t_ns;
    wire_rate  = nominal * 8.0 / t_ns;
    util       = 100.0 * nominal / wire_total;
    mfps       = N / t_ns * 1e3;
    mfps_max   = (BYTES / PERIOD_NS) / (real'(nominal) / N) * 1e3;
    in_cyc     = longint'(in_last_cyc) - longint'(in_first_cyc) + 1;
    in_gbps    = in_bytes * 8.0 / (in_cyc * PERIOD_NS);
    nominal_in = longint'(in_bytes) + (4 + 8 + IPG_NOM) * longint'(in_frames);
    spare_src  = BYTES * in_cyc - nominal_in;                       // line capacity the source never offered
    src_share  = (spare_src < 0) ? 0 : spare_src;
    if (src_share > excess) src_share = (excess > 0) ? excess : 0;
    dut_share  = excess - src_share;
    avg_ipg    = (snap.gaps != 0) ? real'(snap.ipg_sum) / snap.gaps : 0.0;
    avg_len    = real'(snap.len_sum) / N;
    lat_avg    = (snap.lat_n != 0) ? real'(snap.lat_sum) / snap.lat_n * PERIOD_NS : 0.0;

    $display("[BW] ================= bandwidth report: %0d frames =================", N);
    $display("[BW] INPUT  (AXIS): cyc %0d .. %0d = %0d cycles, %0d beats, %0d bytes, avg %0.1f B/frame",
             in_first_cyc, in_last_cyc, in_cyc, in_beats, in_bytes, real'(in_bytes) / in_frames);
    $display("[BW]   offered rate %0.2f Gb/s | tready-low cycles %0d | tvalid-low cycles %0d",
             in_gbps, in_stall, in_gap);
    $display("[BW] OUTPUT (MII) : first /S/ cyc %0d, last /T/ cyc %0d, frame len min/avg/max = %0d/%0.1f/%0d B",
             out_first_cyc, snap.last_pos / BYTES, snap.len_min, avg_len, snap.len_max);
    $display("[BW]   span /S/..last /T/ = %0d B  + %0d B mandatory tail = %0d B = %0.2f beats = %0.1f ns",
             span, IPG_NOM - 1, wire_total, real'(wire_total) / BYTES, t_ns);
    $display("[BW]   bytes by type: data %0d | /S/ %0d | /T/ %0d | idle %0d | other %0d | fully idle beats %0d",
             snap.data, snap.s, snap.t, snap.idle, snap.other, snap.idle_beats);
    $display("[BW] WIRE BYTE BREAKDOWN (%0d B):", wire_total);
    $display("[BW]   payload %0d | FCS %0d | preamble+SFD %0d | minimum IPG %0d | EXCESS idle %0d B (%0.2f beats, %0.2f %% of wire)",
             payload, 4 * N, 8 * N, IPG_NOM * N, excess, real'(excess) / BYTES, 100.0 * excess / wire_total);
    $display("[BW]   excess split (estimate): source/AXIS-limited %0d B | DUT (alignment, DIC, stalls) %0d B",
             src_share, dut_share);
    $display("[BW] RATES:");
    $display("[BW]   goodput (payload)            %8.2f Gb/s = %6.2f %% of %0.0f Gb/s",
             goodput, 100.0 * goodput / line_gbps, line_gbps);
    $display("[BW]   DA..FCS                      %8.2f Gb/s", mac_rate);
    $display("[BW]   preamble+FCS+min IPG counted %8.2f Gb/s  -> line utilisation %0.2f %% (100 %% = saturated)",
             wire_rate, util);
    $display("[BW]   frame rate %0.2f Mfps (max for this mix %0.2f Mfps)", mfps, mfps_max);
    if (snap.gaps != 0)
      $display("[BW] IPG (/T/..next /S/, /T/ counted): min/avg/max = %0d/%0.3f/%0d B | <12: %0d | =12: %0d | >12: %0d | below IPG_MIN: %0d",
               snap.ipg_min, avg_ipg, snap.ipg_max, snap.ipg_short,
               snap.gaps - snap.ipg_short - snap.ipg_long, snap.ipg_long, snap.ipg_below_min);
    $display("[BW]   running DIC max %0d (limit %0d) | /S/-to-/S/ slot min/max %0d/%0d B",
             snap.dic_max, DIC_MAX, snap.slot_min, snap.slot_max);
    if (snap.lat_n != 0)
      $display("[BW] LATENCY first input beat -> /S/: min/avg/max = %0d/%0.1f/%0d cycles (%0.1f ns avg)",
               snap.lat_min, real'(snap.lat_sum) / snap.lat_n, snap.lat_max, lat_avg);

    // ---- checks ----
    if (snap.idle + snap.data + snap.s + snap.t + snap.other != span)
      $error("[BW] byte accounting mismatch: %0d vs span %0d", snap.idle + snap.data + snap.s + snap.t + snap.other, span);
    if (snap.s != snap.t)       $error("[BW] /S/ count %0d != /T/ count %0d", snap.s, snap.t);
    if (in_frames != snap.t)    $warning("[BW] frames in %0d != out %0d (not drained, or frames lost)", in_frames, snap.t);
    if (in_bytes != payload)    $warning("[BW] input bytes %0d != output payload %0d (padding, drops or not drained)", in_bytes, payload);
    if (snap.runts != 0)        $error("[BW] %0d frames shorter than %0d B before FCS", snap.runts, MIN_LEN);
    if (snap.ipg_below_min != 0)$error("[BW] %0d gaps below IPG_MIN=%0d", snap.ipg_below_min, IPG_MIN);
    if (snap.dic_viol != 0)     $error("[BW] running IPG deficit exceeded DIC_MAX=%0d (%0d times): average IPG < 12", DIC_MAX, snap.dic_viol);
    if (proto_err != 0)         $error("[BW] %0d xMII protocol errors", proto_err);
  endtask
endmodule
