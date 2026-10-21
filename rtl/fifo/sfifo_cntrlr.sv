///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2026 . All Rights Reserved.
// 
// This document and the information contained herein are proprietary and
// confidential to Logic Silicon Inc. No part of this file may be reproduced,
// distributed, disclosed, transmitted, or used in any form or by any means
// without the prior written permission of Logic Silicon Inc.
// 
// File Name     : sfifo_cntrlr.sv
// Author        : Najam Khalil
// Created Date  : 10-March-2026
// Version       : 1.0
// Description   : The sfifo_cntrlr module is a flexible
//                 FIFO (First-In, First-Out) controller designed to
//                 manage data flow between different parts of a
//                 digital system. It generates read and write pointers,
//                 along with full and empty flags, making it suitable
//                 for implementation using either flop-based or SRAM-based
//                 memory architectures. The design supports both Write FIFO
//                 (wr) and Read FIFO (rd) modes.
///////////////////////////////////////////////////////////////////////////////
module sfifo_cntrlr #(
  parameter DEPTH   = 16           ,
  parameter WIDTH   = $clog2(DEPTH),
  parameter FTHRESH = DEPTH        , // full threshold
  parameter ETHRESH = 0              // empty threshold
) (
  input  logic                   clk    ,
  input  logic                   arst_n ,
  // write domain
  input  logic                   wr     ,
  output logic [      WIDTH-1:0] wr_addr,
  output logic                   full   ,
  output logic                   tfull  ,
  output logic                   ovf    , // write when full
  // read domain
  input  logic                   rd     ,
  output logic [      WIDTH-1:0] rd_addr,
  output logic                   empty  ,
  output logic                   tempty ,
  output logic                   udf    , // read when empty
  // remaining signals
  output logic [$clog2(DEPTH):0] num_vld  // valid entries in fifo
);

  // -------------------------------------
  // Internal signals
  // -------------------------------------
  logic [WIDTH:0] entries;

  // -------------------------------------
  // Write Pointer Logic
  // -------------------------------------
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
      wr_addr <= '0;
    else if (wr && !full) begin
      if (wr_addr == (DEPTH - 1))
        wr_addr <= '0;
      else
        wr_addr <= wr_addr + 1;
    end
  end

  // -------------------------------------
  // Read Pointer Logic
  // -------------------------------------
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
      rd_addr <= '0;
    else if (rd && !empty) begin
      if (rd_addr == (DEPTH - 1))
        rd_addr <= '0;
      else
        rd_addr <= rd_addr + 1;
    end
  end

  // -------------------------------------
  // Full & Empty Logic
  // -------------------------------------
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
      entries <= '0;
    else begin
      if ((wr && !full) && !(rd && !empty))
        entries <= entries + 1'b1;
      else if (!(wr && !full) && (rd && !empty))
        entries <= entries - 1'b1;
    end
  end

  // Empty & Full flags
  assign empty = (entries == 0);
  assign full  = (entries == DEPTH);

  // -------------------------------------
  // extra Features
  // -------------------------------------
  assign num_vld = entries[$clog2(DEPTH):0];
  // threshold reach detection logic
  assign tfull  = (entries >= FTHRESH);
  assign tempty = (entries <= ETHRESH);
  // overflow detection logic
  always_ff @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
      ovf <= 0;
    end else begin
      if(full  && wr)
        ovf <= 1;
      else
        ovf <= 0;
    end
  end
  // underflow detection logic
  always_ff @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
      udf <= 0;
    end else begin
      if(empty && rd)
        udf <= 1;
      else
        udf <= 0;
    end
  end

  `ifdef INCLUDE_FPV // Formal property verification
    write_when_full: assert property (@(posedge clk) disable iff (!arst_n) !(full  |-> wr));
    read_when_empty: assert property (@(posedge clk) disable iff (!arst_n) !(empty |-> rd));
  `endif

endmodule
