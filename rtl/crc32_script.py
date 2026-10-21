#!/usr/bin/env python3
"""
verify_systolic_pipeline.py
============================
Run with:
    python3 verify_systolic_pipeline.py            (default: quiet-ish)
    python3 verify_systolic_pipeline.py -v          (fully verbose)
    python3 verify_systolic_pipeline.py -v -v       (very verbose: prints
                                                       every cycle of a
                                                       small worked example)

Sections, in the order a reader (or a re-implementer) should go through
them:
  1. Golden reference (ground truth, bit-serial CRC-32/ISO-HDLC)
  2. Build the two core matrices A (state) and B (data)
  3. Sanity: does the systolic GROUP SPLIT of B still equal the
     full-width B? (this must hold before anything else can work --
     it's pure linearity, but it's cheap to check explicitly)
  4. Sanity: single-frame pipeline, small worked example, MAXIMALLY
     verbose (prints every register's value every cycle) -- this is the
     tool that caught the two real pipeline bugs during development
  5. Multi-frame, back-to-back, full-throughput streaming test (the
     actual claim under test: 1 beat accepted every cycle, D cycles of
     latency, zero stalls)
  6. Large randomized stress test across D = 1, 2, 3, 4
"""

import argparse
import random
import sys

# ----------------------------------------------------------------------
# Section 1: Golden reference (CRC-32/ISO-HDLC, i.e. standard Ethernet
# FCS -- reflected form, poly 0xEDB88320 which is the bit-reversal of
# the normal-form polynomial 0x04C11DB7).
# ----------------------------------------------------------------------
POLY_REFLECTED = 0xEDB88320
INIT = 0xFFFFFFFF
XOROUT = 0xFFFFFFFF
W = 1024          # beat width in bits (128 bytes)
BEAT_BYTES = W // 8


def step(crc: int, bit: int) -> int:
    """The one true primitive: a single reflected-CRC serial step."""
    fb = (crc ^ bit) & 1
    crc >>= 1
    if fb:
        crc ^= POLY_REFLECTED
    return crc


def crc32_final(data: bytes) -> int:
    """Golden bit-serial CRC-32, byte-by-byte, LSB-first per byte."""
    crc = INIT
    for byte in data:
        for i in range(8):
            crc = step(crc, (byte >> i) & 1)
    return (crc ^ XOROUT) & 0xFFFFFFFF


def bytes_to_int_lsb_first(data: bytes) -> int:
    """byte i -> bits [8i+7 : 8i] of the returned integer (byte 0 = LSB)."""
    v = 0
    for i, b in enumerate(data):
        v |= b << (8 * i)
    return v


# ----------------------------------------------------------------------
# Section 2: Build A (state matrix) and B (data matrix) for the FULL
# W-bit beat. These are the same matrices used throughout this project
# (matrix_gen.py) -- reproduced here so this file is fully standalone.
# ----------------------------------------------------------------------
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
    if verbose:
        print(f"  [Section 2] Built A: 32 columns, e.g. A_cols[0] = 0x{cols[0]:08x}")
    return cols


def build_B_columns(verbose: bool = False):
    """
    B_cols[j] = result of running state=0 through W serial steps with a
    single 1-bit at data position j (all other data bits 0).
    Answers: "how does data bit j alone push the state, over one beat?"
    """
    cols = []
    for j in range(W):
        crc = 0
        for pos in range(W):
            d = 1 if pos == j else 0
            crc = step(crc, d)
        cols.append(crc)
    if verbose:
        print(f"  [Section 2] Built B: {W} columns, e.g. B_cols[0] = 0x{cols[0]:08x}, "
              f"B_cols[{W-1}] = 0x{cols[W-1]:08x}")
    return cols


def apply_A(state: int, A_cols) -> int:
    ns = 0
    for i in range(32):
        if (state >> i) & 1:
            ns ^= A_cols[i]
    return ns


def apply_B(data: int, B_cols) -> int:
    ns = 0
    for j in range(W):
        if (data >> j) & 1:
            ns ^= B_cols[j]
    return ns


# ----------------------------------------------------------------------
# Section 3: Systolic group split -- divide B's W data-bit columns into
# D contiguous groups. A group's own "narrow" contribution, summed
# across all D groups, MUST equal the full apply_B(data) result -- this
# is a direct consequence of XOR-reduction distributing over any
# partition of the input bits, but it's cheap to check explicitly
# before trusting it in a bigger simulation.
# ----------------------------------------------------------------------
def group_bounds(D: int):
    """
    Returns a list of D (lo, hi) tuples partitioning [0, W) into D
    contiguous groups, as evenly as possible (W need not be divisible
    by D -- the first `W % D` groups get one extra bit).
    """
    base = W // D
    extra = W % D
    bounds = []
    pos = 0
    for i in range(D):
        width = base + (1 if i < extra else 0)
        bounds.append((pos, pos + width))
        pos += width
    assert pos == W
    return bounds


def group_contribution(data_int: int, group_idx: int, bounds, B_cols) -> int:
    lo, hi = bounds[group_idx]
    ns = 0
    for j in range(lo, hi):
        if (data_int >> j) & 1:
            ns ^= B_cols[j]
    return ns


def check_group_split_matches_full(D: int, B_cols, verbose: bool) -> bool:
    """Section 3's sanity check, for a random data word."""
    rng = random.Random(1)
    data = rng.getrandbits(W)
    bounds = group_bounds(D)
    group_sum = 0
    for g in range(D):
        group_sum ^= group_contribution(data, g, bounds, B_cols)
    full = apply_B(data, B_cols)
    ok = (group_sum == full)
    if verbose:
        print(f"  [Section 3] D={D}, group bounds={bounds}")
        print(f"    group-split sum = 0x{group_sum:08x}")
        print(f"    full apply_B    = 0x{full:08x}")
        print(f"    MATCH: {ok}")
    return ok


# ----------------------------------------------------------------------
# Section 4: Full systolic pipeline model (single frame, maximally
# verbose option). This is the exact structure translated into
# crc32_1024b_engine_pipelined.sv:
#   - stage 0: fresh incoming data, group 0, no incoming accumulator
#   - stages 1..D-1: read a DELAYED copy of an earlier beat's raw data
#     (own dedicated register per stage), compute that stage's group,
#     XOR onto the running accumulator carried from the previous stage
#   - sop/tlast/valid_bytes pipelined through the SAME D-stage delay,
#     in lockstep with the data
#   - A(old_state) recomputed FRESH, combinationally, every cycle --
#     verified sufficient with NO extra register on this path
# ----------------------------------------------------------------------
def frame_to_beats(data: bytes):
    """Split a frame into (chunk, is_last_beat, n_valid_bytes) tuples."""
    beats = []
    n = len(data)
    full, rem = divmod(n, BEAT_BYTES)
    for i in range(full):
        chunk = data[i * BEAT_BYTES:(i + 1) * BEAT_BYTES]
        is_last = (rem == 0 and i == full - 1)
        beats.append((chunk, is_last, BEAT_BYTES))
    if rem:
        chunk = data[full * BEAT_BYTES:] + bytes(BEAT_BYTES - rem)
        beats.append((chunk, True, rem))
    if n == 0:
        beats.append((bytes(BEAT_BYTES), True, 0))
    return beats


def build_correction_table(A_cols, verbose: bool = False):
    """
    129 correction matrices (one per valid-byte-count 0..128), needed for
    the tail-beat byte-enable correction (see the earlier design-log
    documents for the full derivation -- this is the same mechanism as
    crc32_1024b_engine.sv's CORR_PACKED, here recomputed standalone).
    """
    def state_matrix_k_steps(k):
        cols = []
        for i in range(32):
            crc = 1 << i
            for _ in range(k):
                crc = step(crc, 0)
            cols.append(crc)
        return cols

    def gf2_invert(M):
        n = 32
        A = [row[:] for row in M]
        I = [[1 if i == j else 0 for j in range(n)] for i in range(n)]
        for col in range(n):
            piv = next(r for r in range(col, n) if A[r][col] == 1)
            A[col], A[piv] = A[piv], A[col]
            I[col], I[piv] = I[piv], I[col]
            for r in range(n):
                if r != col and A[r][col] == 1:
                    A[r] = [a ^ b for a, b in zip(A[r], A[col])]
                    I[r] = [a ^ b for a, b in zip(I[r], I[col])]
        return I

    def cols_to_matrix(cols):
        return [[(cols[c] >> r) & 1 for c in range(32)] for r in range(32)]

    def matrix_to_cols(M):
        cols = []
        for c in range(32):
            val = 0
            for r in range(32):
                if M[r][c]:
                    val |= (1 << r)
            cols.append(val)
        return cols

    table = {}
    for n_bytes in range(BEAT_BYTES + 1):
        k = W - n_bytes * 8
        cols = state_matrix_k_steps(k)
        Minv = gf2_invert(cols_to_matrix(cols))
        table[n_bytes] = matrix_to_cols(Minv)
    if verbose:
        print(f"  [Section 4] Built {len(table)} correction matrices "
              f"(0..{BEAT_BYTES} valid bytes)")
    return table


def apply_matrix_cols(cols, vec32: int) -> int:
    out = 0
    for i in range(32):
        if (vec32 >> i) & 1:
            out ^= cols[i]
    return out


def crc32_systolic_pipeline(frames, D, A_cols, B_cols, corr_table,
                             verbose_cycles: bool = False):
    """
    The full pipeline model. Returns a list of FCS values, one per input
    frame, in order.

    verbose_cycles=True prints every register's state every cycle -- only
    useful/readable for a SMALL number of beats (this is literally the
    debugging tool that caught the pipeline-fill and tvalid-freeze bugs
    during development; kept here so the same technique is available for
    any future change to this design).
    """
    bounds = group_bounds(D)

    beat_stream = []
    for frame in frames:
        for i, (chunk, is_last, vb) in enumerate(frame_to_beats(frame)):
            beat_stream.append((bytes_to_int_lsb_first(chunk), i == 0, is_last, vb))
    n_beats = len(beat_stream)

    # Pipeline registers
    data_regs = [0] * D        # data_regs[i-1] used by stage i (i=1..D-1)
    sop_regs = [False] * D
    tlast_regs = [False] * D
    vb_regs = [0] * D
    acc_regs = [0] * D

    state_q = INIT
    fcs_results = []

    total_cycles = n_beats + D + 1
    for t in range(total_cycles):
        # ---- What's arriving THIS cycle (a bubble once beats run out) ----
        if t < n_beats:
            data_t, sop_t, tlast_t, vb_t = beat_stream[t]
        else:
            data_t, sop_t, tlast_t, vb_t = 0, False, False, 0

        # ---- Stage 0: fresh data, group 0, no incoming accumulator ----
        new_acc = [0] * D
        new_acc[0] = group_contribution(data_t, 0, bounds, B_cols)

        # ---- Stages 1..D-1: delayed data, own group, accumulate ----
        for i in range(1, D):
            new_acc[i] = acc_regs[i - 1] ^ group_contribution(
                data_regs[i - 1], i, bounds, B_cols)

        # ---- Combine stage: uses the FULLY accumulated B result (D
        # ---- cycles old) and A(old_state), old_state computed FRESH
        # ---- this cycle from state_q (no extra register on this path)
        Bres_q = acc_regs[D - 1]
        sop_dly = sop_regs[D - 1]
        tlast_dly = tlast_regs[D - 1]
        vb_dly = vb_regs[D - 1]

        old_state_eff = INIT if sop_dly else state_q
        combined = apply_A(old_state_eff, A_cols) ^ Bres_q

        if tlast_dly:
            corrected = apply_matrix_cols(corr_table[vb_dly], combined)
            fcs_results.append((corrected ^ XOROUT) & 0xFFFFFFFF)
            next_state = corrected
        else:
            next_state = combined

        if verbose_cycles:
            data_short = f"0x{data_t:0{W//4}x}"
            if len(data_short) > 18:
                data_short = data_short[:10] + "..." + data_short[-6:]
            print(f"  t={t:3d} | data_t={data_short:>19s} sop_t={int(sop_t)} "
                  f"tlast_t={int(tlast_t)} vb_t={vb_t:3d} | "
                  f"state_q(before)=0x{state_q:08x} | "
                  f"Bres_q=0x{Bres_q:08x} sop_dly={int(sop_dly)} "
                  f"tlast_dly={int(tlast_dly)} | combined=0x{combined:08x}"
                  + (f" -> FCS=0x{fcs_results[-1]:08x}" if tlast_dly else ""))

        # ---- Register updates (non-blocking: all reads above already
        # ---- happened using the OLD values; now advance) ----
        data_regs = [data_t] + data_regs[:-1]
        sop_regs = [sop_t] + sop_regs[:-1]
        tlast_regs = [tlast_t] + tlast_regs[:-1]
        vb_regs = [vb_t] + vb_regs[:-1]
        acc_regs = new_acc
        state_q = next_state

    return fcs_results


# ----------------------------------------------------------------------
# Section 5 & 6: driver / test harness
# ----------------------------------------------------------------------
def run_all_checks(verbosity: int):
    verbose = verbosity >= 1
    very_verbose = verbosity >= 2

    print("=" * 78)
    print("Systolic CRC-32 pipeline validation")
    print("=" * 78)

    print("\n[Section 1] Golden reference sanity check (ASCII '123456789')")
    check_val = crc32_final(b"123456789")
    print(f"  crc32_final(b'123456789') = 0x{check_val:08x}  "
          f"(expected 0xCBF43926, the published CRC-32/ISO-HDLC check value)")
    assert check_val == 0xCBF43926, "Golden reference itself is broken -- stop here."
    print("  OK.")

    print("\n[Section 2] Building A and B matrices (this takes a few seconds)...")
    A_cols = build_A_columns(verbose=verbose)
    B_cols = build_B_columns(verbose=verbose)
    print("  OK.")

    print("\n[Section 3] Group-split sanity check (does splitting B into D "
          "groups and summing the parts equal the full-width B?)")
    for D in [1, 2, 3, 4]:
        ok = check_group_split_matches_full(D, B_cols, verbose=verbose)
        print(f"  D={D}: {'OK' if ok else 'FAIL -- STOP, this must pass before anything else'}")
        assert ok

    print("\n[Section 4] Building the 129-entry tail-beat correction table...")
    corr_table = build_correction_table(A_cols, verbose=verbose)
    print("  OK.")

    if very_verbose:
        print("\n[Section 4b] MAXIMALLY VERBOSE small worked example (D=3, "
              "3 tiny frames, every cycle printed)")
        print("  This is the exact debugging technique that caught the two "
              "real pipeline bugs during development:")
        print("    Bug A: state_q corrupted during pipeline fill (fixed by "
              "gating the commit to start exactly at cycle D)")
        print("    Bug B: pipeline froze on tvalid=0 in the RTL translation "
              "(fixed by making advance unconditional, tvalid only gates "
              "what's fed into stage 0)")
        print("  -- this Python model never had Bug B's failure mode (it has "
              "no tvalid concept at all), which is exactly why Bug B was "
              "only caught once real RTL simulation was run; this print "
              "block is kept here to show what a healthy trace looks like.")
        small_frames = [bytes([0x11, 0x22, 0x33]), bytes([0xAA]), bytes(range(200))]
        crc32_systolic_pipeline(small_frames, D=3, A_cols=A_cols, B_cols=B_cols,
                                 corr_table=corr_table, verbose_cycles=True)

    print("\n[Section 5] Multi-frame, back-to-back, full-throughput streaming test")
    print("  (this is the ACTUAL claim under test: does presenting one new")
    print("   beat every single cycle -- no stalls -- still produce the")
    print("   correct FCS for every frame, given only D cycles of latency?)")
    for D in [1, 2, 3, 4]:
        random.seed(D * 55 + 9)
        frames = []
        for n in range(1, 130):
            frames.append(bytes(random.randrange(256) for _ in range(n)))
        for _ in range(200):
            n = random.randint(1, 6 * BEAT_BYTES)
            frames.append(bytes(random.randrange(256) for _ in range(n)))
        golden = [crc32_final(f) for f in frames]
        got = crc32_systolic_pipeline(frames, D, A_cols, B_cols, corr_table)
        match = (got == golden)
        print(f"  D={D} (group width={W//D if W%D==0 else 'uneven'} bits/stage): "
              f"{len(frames)} frames -> {'OK' if match else 'FAIL'}")
        if not match:
            for i, (g, x) in enumerate(zip(golden, got)):
                if g != x:
                    print(f"    first mismatch: frame {i}, len={len(frames[i])}, "
                          f"got=0x{x:08x} expected=0x{g:08x}")
                    break
        assert match

    print("\n[Section 6] Large randomized stress test (D=3 and D=4, ~1600 frames each)")
    for D in [3, 4]:
        random.seed(D * 999 + 1)
        frames = []
        for n in range(1, 130):
            frames.append(bytes(random.randrange(256) for _ in range(n)))
        for _ in range(1500):
            n = random.randint(1, 8 * BEAT_BYTES)
            frames.append(bytes(random.randrange(256) for _ in range(n)))
        golden = [crc32_final(f) for f in frames]
        got = crc32_systolic_pipeline(frames, D, A_cols, B_cols, corr_table)
        match = (got == golden)
        print(f"  D={D}: {len(frames)} frames -> {'OK' if match else 'FAIL'}")
        assert match

    print("\n" + "=" * 78)
    print("ALL CHECKS PASSED.")
    print("=" * 78)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                      formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-v", "--verbose", action="count", default=0,
                         help="repeat for more verbosity (-v, -v -v)")
    args = parser.parse_args()
    run_all_checks(args.verbose)