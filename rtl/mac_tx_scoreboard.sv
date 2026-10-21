`timescale 1ns/1ps
// =============================================================================
//  MAC TX scoreboard  (AXI-Stream in  ->  800GMII-style TXD/TXC out)
//
//  INPUT  : every AXIS packet is extracted (tkeep-aware) into a queue of expected packets.
//           FCS comes from  (a) internal CRC-32, or (b) your CRC model via push_crc().
//  MODEL  : for every packet, the expected wire image is
//             /S/(FB,c1) | 55 x6 | D5 | data[] (+pad) | FCS[4] | /T/(FD,c1)
//           and everything outside a frame must be 07 / TXC=1 (idle).
//  OUTPUT : txd/txc are walked byte by byte. Each byte is compared with what the model
//           creates (data AND control bit). Where a frame starts is the DUT's choice, but
//           it is checked for legality: lane-0 alignment, ordering, IPG, DIC.
//  TRACKS : per-byte mismatches (preamble / data / FCS / control / length), frame boundaries,
//           frame order, missing or extra frames, IPG min/avg/max, DIC, latency.
// =============================================================================
package mac_sb_pkg;
  class pkt_c;
    byte unsigned    data[$];      // user bytes DA..payload (after optional pad)
    longint unsigned id, sop_cyc, eop_cyc;
    int unsigned     in_len;       // bytes seen on AXIS (before pad)
    logic [31:0]     crc_int;      // internal CRC-32 value, e.g. 0xCBF43926 for "123456789"
    logic [31:0]     crc;          // CRC used for the expected FCS
  endclass

  function automatic logic [31:0] crc32_q(input byte unsigned d[$]);
    logic [31:0] c;
    c = 32'hFFFFFFFF;
    foreach (d[i]) begin
      c = c ^ {24'h0, d[i]};
      for (int b = 0; b < 8; b++) c = (c >> 1) ^ (32'hEDB88320 & {32{c[0]}});
    end
    return ~c;
  endfunction
endpackage


module mac_tx_scoreboard
  import mac_sb_pkg::*;
#(
  parameter int  BYTES     = 128,    // 1024-bit datapath
  parameter real PERIOD_NS = 1.28,   // 781.25 MHz
  parameter int  IPG_NOM   = 12,     // 96 bit times, /T/ counted inside the gap
  parameter int  IPG_MIN   = 9,      // shortest single gap allowed   (set per Clause 81/170)
  parameter int  DIC_MAX   = 15,      // deficit idle count limit      (set per Clause 81/170)
  parameter int  MIN_LEN   = 60,     // DA..payload bytes before FCS
  parameter bit  PAD_RUNT  = 0,      // model pads short frames with zeros up to MIN_LEN
  parameter bit  CRC_SRC   = 1,      // 0 = internal CRC-32, 1 = take FCS from push_crc() queue
  parameter bit  FCS_LE    = 1,      // 1: wire order = crc[7:0] first (standard)
  parameter int  VERBOSE   = 1,      // 0 summary only, 1 + errors, 2 + one line per frame
  parameter int  MAX_PRINT = 20,
  parameter int  MAX_EXTRA = 16384     // bytes tolerated past the expected /T/ before the frame is cut
)(
  input  logic                clk, rst_n,
  input  logic                report,           // pulse to print the summary (also printed at end of sim)
  // DUT input (AXI-Stream)
  input  logic                s_tvalid, s_tready, s_tlast,
  input  logic [BYTES*8-1:0]  s_tdata,
  input  logic [BYTES-1:0]    s_tkeep,
  // DUT output (xMII)
  input  logic [BYTES*8-1:0]  txd,
  input  logic [BYTES-1:0]    txc,
  output longint unsigned     n_err
);
  localparam logic [7:0] IDLE = 8'h07, START = 8'hFB, TERM = 8'hFD, SFD = 8'hD5, PRE = 8'h55;

  longint unsigned cyc;
  pkt_c            exp_q[$];
  logic [31:0]     crc_q[$];
  pkt_c            cur_in, cur_out;

  // counters
  longint unsigned in_pkts, out_s, out_t, frames_ok, frames_bad, printed, lane_pr, summary_done;
  longint unsigned e_pre, e_data, e_fcs, e_ctrl, e_len, e_bound, e_order, e_in, e_crcq, crc_diff, e_summary;
  // output FSM
  bit              in_frm, frm_bad, extra_seen, have_t, have_s;
  int              j, M, fm_cnt;
  longint unsigned prev_t_pos, prev_s_pos, s_pos_cur, s_cyc_cur;
  // IPG / slot / latency
  longint unsigned gaps, ipg_sum, ipg_min, ipg_max, ipg_short, ipg_long, ipg_below, dic_viol, slot_min, slot_max;
  longint          dic, dic_max;
  longint unsigned lat_n, lat_sop_sum, lat_sop_min, lat_sop_max;
  longint          lat_eop_min, lat_eop_max;
  // per-beat expected image (what the model creates) for context printing
  logic [7:0]      exp_d [BYTES];
  logic            exp_c [BYTES];
  
  // ---------------------------------------------------------------- helpers
  function void push_crc(input logic [31:0] c);          // call from your CRC model, once per packet, in packet order
    crc_q.push_back(c);
  endfunction

  function automatic logic [7:0] wire_byte(input pkt_c p, input int jj);   // byte j after /S/
    int L; int m;
    L = p.data.size();
    if (jj < 6)      return PRE;
    if (jj == 6)     return SFD;
    if (jj < 7 + L)  return p.data[jj - 7];
    m = jj - (7 + L);
    return FCS_LE ? p.crc[8*m +: 8] : p.crc[24 - 8*m +: 8];
  endfunction

  task automatic perr_q(input string cls, input string msg, input bit show);   // always counts, prints only if show
    n_err++;
    if (show && VERBOSE > 0 && printed < MAX_PRINT) begin
      printed++;
      $display("[SB][ERR] cyc %0d  %-8s %s", cyc, cls, msg);
    end
  endtask
  task automatic perr(input string cls, input string msg);
    perr_q(cls, msg, 1'b1);
  endtask

  task automatic reset_all();
    cyc = 0; exp_q.delete(); crc_q.delete(); cur_in = null; cur_out = null;
    in_pkts = 0; out_s = 0; out_t = 0; frames_ok = 0; frames_bad = 0; printed = 0; lane_pr = 0; summary_done = 0; n_err = 0;
    e_pre = 0; e_data = 0; e_fcs = 0; e_ctrl = 0; e_len = 0; e_bound = 0; e_order = 0; e_in = 0; e_crcq = 0; crc_diff = 0; e_summary = 0;
    in_frm = 0; frm_bad = 0; extra_seen = 0; have_t = 0; have_s = 0; j = 0; M = 0; fm_cnt = 0;
    prev_t_pos = 0; prev_s_pos = 0; s_pos_cur = 0; s_cyc_cur = 0;
    gaps = 0; ipg_sum = 0; ipg_min = '1; ipg_max = 0; ipg_short = 0; ipg_long = 0; ipg_below = 0; dic_viol = 0;
    slot_min = '1; slot_max = 0; dic = 0; dic_max = 0;
    lat_n = 0; lat_sop_sum = 0; lat_sop_min = '1; lat_sop_max = 0; lat_eop_min = 64'sh7FFFFFFFFFFFFFFF; lat_eop_max = -64'sh7FFFFFFFFFFFFFFF;
  endtask

  task automatic finish_in();                             // AXIS packet complete -> expected packet
    cur_in.in_len  = cur_in.data.size();
    cur_in.eop_cyc = cyc;
    if (PAD_RUNT) while (cur_in.data.size() < MIN_LEN) cur_in.data.push_back(8'h00);
    cur_in.crc_int = crc32_q(cur_in.data);
    cur_in.crc     = cur_in.crc_int;
    exp_q.push_back(cur_in);
    cur_in = null;
    in_pkts++;
  endtask

  task automatic start_frame(input int bi, input longint unsigned pos);   // /S/ seen at byte bi
    longint unsigned gap, slot;
    longint lat_e;
    if (bi % 8 != 0) begin
      e_bound++; perr("BOUNDARY", $sformatf("/S/ in byte %0d of the beat, not byte 0 of a 64-bit lane", bi));
    end
    if (exp_q.size() == 0) begin
      e_order++; cur_out = null;
      perr("ORDER", "frame on MII but no complete input packet is pending (started before tlast, or extra frame)");
    end else begin
      cur_out = exp_q.pop_front();
      if (CRC_SRC) begin                                  // FCS from the external CRC model
        if (crc_q.size() == 0) begin
          e_crcq++; cur_out.crc = cur_out.crc_int;
          perr("CRCQ", $sformatf("frame %0d: CRC queue empty when the frame started on MII", cur_out.id));
        end else begin
          cur_out.crc = crc_q.pop_front();
          if (cur_out.crc != cur_out.crc_int) begin
            crc_diff++;
            perr("CRCMODEL", $sformatf("frame %0d: CRC model %08h != internal %08h", cur_out.id, cur_out.crc, cur_out.crc_int));
          end
        end
      end
      lat_e = longint'(cyc) - longint'(cur_out.eop_cyc);
      lat_n++; lat_sop_sum += cyc - cur_out.sop_cyc;
      if (cyc - cur_out.sop_cyc < lat_sop_min) lat_sop_min = cyc - cur_out.sop_cyc;
      if (cyc - cur_out.sop_cyc > lat_sop_max) lat_sop_max = cyc - cur_out.sop_cyc;
      if (lat_e < lat_eop_min) lat_eop_min = lat_e;
      if (lat_e > lat_eop_max) lat_eop_max = lat_e;
    end
    M = (cur_out != null) ? 7 + cur_out.data.size() + 4 : 0;   // bytes between /S/ and /T/
    if (have_t) begin                                     // gap: /T/ .. last idle, /T/ counted
      gap = pos - prev_t_pos;
      gaps++; ipg_sum += gap;
      if (gap < ipg_min) ipg_min = gap;
      if (gap > ipg_max) ipg_max = gap;
      if (gap < IPG_NOM) ipg_short++;
      if (gap > IPG_NOM) ipg_long++;
      if (gap < IPG_MIN) begin
        ipg_below++; perr_q("IPG", $sformatf("gap %0d B < IPG_MIN %0d", gap, IPG_MIN), ipg_below <= 3);
      end
      dic = dic + (IPG_NOM - longint'(gap));              // DIC: +deleted, -inserted, never below 0
      if (dic < 0) dic = 0;
      if (dic > dic_max) dic_max = dic;
      if (dic > DIC_MAX) begin
        dic_viol++; perr_q("DIC", $sformatf("running deficit %0d > DIC_MAX %0d (average IPG falling below %0d)", dic, DIC_MAX, IPG_NOM), dic_viol <= 3);
      end
    end
    if (have_s) begin
      slot = pos - prev_s_pos;
      if (slot < slot_min) slot_min = slot;
      if (slot > slot_max) slot_max = slot;
    end
    prev_s_pos = pos; have_s = 1; s_pos_cur = pos; s_cyc_cur = cyc;
    in_frm = 1; j = 0; frm_bad = 0; extra_seen = 0; fm_cnt = 0; out_s++;
  endtask

  task automatic end_frame(input longint unsigned pos);  // /T/ seen
    if (frm_bad) frames_bad++; else frames_ok++;
    if (fm_cnt > 3 && VERBOSE > 0 && cur_out != null)
      $display("[SB]      frame %0d: %0d byte mismatches in total (first 3 shown)", cur_out.id, fm_cnt);
    if (VERBOSE > 1 && cur_out != null)
      $display("[SB] frame %0d %s: S@%0d T@%0d  wire bytes S..T %0d, user len %0d (in %0d)",
               cur_out.id, frm_bad ? "BAD" : "ok ", s_pos_cur, pos, pos - s_pos_cur + 1, cur_out.data.size(), cur_out.in_len);
    in_frm = 0; have_t = 1; prev_t_pos = pos; out_t++;
  endtask

  // ---------------------------------------------------------------- main
  always @(posedge clk) begin
    bit              in_beat, contiguous;
    logic [7:0]      ad, ed;
    logic            ac, ec;
    longint unsigned pos;
    int              first_mm, region;
    string           rname;

    if (!rst_n) reset_all();
    else begin
      // ======================= INPUT: extract each packet =======================
      in_beat = s_tvalid && s_tready;
      if (in_beat) begin
        if (cur_in == null) begin cur_in = new(); cur_in.id = in_pkts; cur_in.sop_cyc = cyc; end
        contiguous = ((s_tkeep & (s_tkeep + 1'b1)) == '0);
        if (!contiguous)                   begin e_in++; perr("INPUT", "tkeep not contiguous from byte 0"); end
        if (!s_tlast && s_tkeep != '1)     begin e_in++; perr("INPUT", "tkeep not full on a non-last beat"); end
        for (int i = 0; i < BYTES; i++) if (s_tkeep[i]) cur_in.data.push_back(s_tdata[8*i +: 8]);
        if (s_tlast) finish_in();
      end

      // ======================= OUTPUT: walk txd/txc byte by byte =======================
      first_mm = -1;
      for (int i = 0; i < BYTES; i++) begin
        ad = txd[8*i +: 8];  ac = txc[i];  pos = cyc * BYTES + i;
        ed = IDLE;  ec = 1;                               // default expectation: idle

        if (!in_frm) begin
          if (ac && ad == START) begin
            ed = START; ec = 1;
            start_frame(i, pos);
          end else if (!(ac && ad == IDLE)) begin
            e_ctrl++; if (first_mm < 0) first_mm = i;
            perr("IDLE", $sformatf("outside a frame: expected 07/c1, got %02h/c%0b (byte %0d)", ad, ac, i));
          end
        end else begin
          if (ac && ad == TERM) begin                     // ---- Terminate
            ed = TERM; ec = 1;
            if (cur_out != null && j != M) begin
              e_len++; frm_bad = 1; if (first_mm < 0) first_mm = i;
              perr("LENGTH", $sformatf("frame %0d: /T/ after %0d bytes, expected %0d (user len %0d + 7 preamble + 4 FCS)",
                                       cur_out.id, j, M, cur_out.data.size()));
            end
            end_frame(pos);
          end else if (ac && ad == START) begin           // ---- /S/ before /T/
            e_bound++; frm_bad = 1; if (first_mm < 0) first_mm = i;
            perr("BOUNDARY", "/S/ received before /T/ (previous frame truncated)");
            end_frame(pos);
            ed = START; ec = 1;
            start_frame(i, pos);
          end else begin                                  // ---- byte that must be frame content
            if (cur_out != null && j < M) begin
              ed = wire_byte(cur_out, j);  ec = 0;
              if (j < 7)                     begin region = 0; rname = "PREAMBLE"; end
              else if (j < M - 4)            begin region = 1; rname = "DATA";     end
              else                           begin region = 2; rname = "FCS";      end
              if (ad !== ed || ac !== ec) begin
                frm_bad = 1; fm_cnt++; if (fm_cnt == 1 && first_mm < 0) first_mm = i;
                case (region) 0: e_pre++; 1: e_data++; default: e_fcs++; endcase
                perr_q(rname, $sformatf("frame %0d byte %0d%s: exp %02h/c%0b act %02h/c%0b",
                      cur_out.id, j, (region == 1) ? $sformatf(" (payload offset %0d)", j - 7) :
                                     (region == 2) ? $sformatf(" (FCS byte %0d)", j - (M - 4)) : "",
                      ed, ec, ad, ac), fm_cnt <= 3);
              end
            end else if (cur_out != null) begin           // past the expected end: /T/ was due here
              ed = TERM; ec = 1;
              if (!extra_seen) begin
                extra_seen = 1; e_len++; frm_bad = 1; if (first_mm < 0) first_mm = i;
                perr("LENGTH", $sformatf("frame %0d: no /T/ at expected position (byte %0d), got %02h/c%0b",
                                         cur_out.id, M, ad, ac));
              end
            end
            j++;
            if (j > M + MAX_EXTRA) begin                  // runaway: cut the frame so we can resync
              frm_bad = 1; e_len++; perr("LENGTH", "no /T/ found, frame cut");
              end_frame(pos);
            end
          end
        end
        exp_d[i] = ed;  exp_c[i] = ec;
      end

      // lane context for the first mismatch in this beat: what the DUT sent vs what the model creates
      if (first_mm >= 0 && VERBOSE > 0 && lane_pr < MAX_PRINT) begin
        int ln; logic [63:0] ed64, ad64; logic [7:0] ec8, ac8;
        ln = first_mm / 8;
        lane_pr++;
        for (int k = 0; k < 8; k++) begin
          ed64[8*k +: 8] = exp_d[ln*8 + k];  ec8[k] = exp_c[ln*8 + k];
          ad64[8*k +: 8] = txd[8*(ln*8 + k) +: 8];  ac8[k] = txc[ln*8 + k];
        end
        $display("[SB]      lane %0d  model TXD=%016h TXC=%02h | rtl TXD=%016h TXC=%02h", ln, ed64, ec8, ad64, ac8);
      end
      
      cyc = cyc + 1;
      if (report) print_summary();
    end
  end

  // ---------------------------------------------------------------- summary
  task automatic print_summary();
    longint unsigned pending;
    real avg_ipg, lat_avg;
    if (summary_done != 0) return;
    summary_done = 1;
    pending = exp_q.size();
    if (pending != 0)      begin e_summary++; n_err++; $display("[SB][ERR] %0d input packets never appeared on the MII (missing/not drained)", pending); end
    if (in_frm)            begin e_summary++; n_err++; $display("[SB][ERR] a frame was still open (no /T/) at the end"); end
    if (cur_in != null)    $display("[SB][WARN] an AXIS packet was still being received at the end");
    if (gaps != 0 && ipg_sum + DIC_MAX < IPG_NOM * gaps) begin
      e_summary++; n_err++; $display("[SB][ERR] average IPG %0.3f B is below %0d B by more than DIC_MAX", real'(ipg_sum) / gaps, IPG_NOM);
    end
    avg_ipg = (gaps != 0) ? real'(ipg_sum) / gaps : 0.0;
    lat_avg = (lat_n != 0) ? real'(lat_sop_sum) / lat_n : 0.0;
    $display("[SB] ============================ scoreboard summary ============================");
    $display("[SB] frames  in %0d | /S/ %0d | /T/ %0d | ok %0d | bad %0d | pending %0d",
             in_pkts, out_s, out_t, frames_ok, frames_bad, pending);
    $display("[SB] errors  preamble %0d | data %0d | FCS %0d | idle/ctrl %0d | length %0d | boundary %0d | order %0d | input %0d | crc-queue %0d | crc-model %0d",
             e_pre, e_data, e_fcs, e_ctrl, e_len, e_bound, e_order, e_in, e_crcq, crc_diff);
    if (gaps != 0) begin
      $display("[SB] IPG     /T/..next /S/ (/T/ counted) min/avg/max = %0d/%0.3f/%0d B | <%0d: %0d | >%0d: %0d | below IPG_MIN %0d",
               ipg_min, avg_ipg, ipg_max, IPG_NOM, ipg_short, IPG_NOM, ipg_long, ipg_below);
      $display("[SB]        DIC max %0d (limit %0d, violations %0d) | /S/-to-/S/ slot min/max %0d/%0d B",
               dic_max, DIC_MAX, dic_viol, slot_min, slot_max);
    end
    if (lat_n != 0)
      $display("[SB] latency first AXIS beat -> /S/: min/avg/max = %0d/%0.1f/%0d cycles | last beat -> /S/: min/max = %0d/%0d cycles",
               lat_sop_min, lat_avg, lat_sop_max, lat_eop_min, lat_eop_max);
    if (n_err == 0) $display("[SB] RESULT: PASS");
    else            $display("[SB] RESULT: FAIL  (%0d errors)", n_err);
  endtask

  final print_summary();
endmodule
