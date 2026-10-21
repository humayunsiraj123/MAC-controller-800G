///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2026 . All Rights Reserved.
// 
// This document and the information contained herein are proprietary and
// confidential to Logic Silicon Inc. No part of this file may be reproduced,
// distributed, disclosed, transmitted, or used in any form or by any means
// without the prior written permission of Logic Silicon Inc.
// 
// File Name     : sfifo.sv
// Author        : Najam Khalil
// Created Date  : 10-March-2026
// Version       : 1.0
// Description   : FIFO wrapper
///////////////////////////////////////////////////////////////////////////////
// add support for first world fall throught
module sfifo #(
  parameter DEPTH      = 16   ,
  parameter DATA_WIDTH = 32   ,
  parameter FTHRESH    = DEPTH, // full threshold
  parameter ETHRESH    = 0    , // empty threshold
  parameter LATENCY    = 0    , // Read Latency used to add flop at output cycle/ mimic ecc latency in case of sram
  parameter RST_INIT   = 0    , // 0: means memory will not be initialized, 1: memory will be initialized with INIT Val, consumes cycle till depth
  parameter INIT_VAL   = '0     // Used to initialize memory with specific value, only used when RST_INIT==1
) (
  input  logic                   clk      ,
  input  logic                   arst_n   ,
  // write domain
  input  logic                   wr       , // write into fifo
  input  logic [ DATA_WIDTH-1:0] wr_data  ,
  output logic                   full     ,
  output logic                   tfull    , // threshold full
  output logic                   ovf      , // write when full
  // read domain
  input  logic                   rd       , // read from fifo
  output logic [ DATA_WIDTH-1:0] rd_data  ,
  output logic                   empty    ,
  output logic                   tempty   , // threshold empty
  output logic                   udf      , // read when empty
  // remaining signals
  output logic [$clog2(DEPTH):0] num_vld  , // valid entries
  output logic                   init_done, // initialization done ack
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
    .FTHRESH(FTHRESH),   // full threshold
    .ETHRESH(ETHRESH)    // empty threshold
  ) sfifo_cntrlr_inst (
    .clk    (clk    ),
    .arst_n (arst_n ),
    // write domain
    .wr     (wr     ),
    .wr_addr(wr_addr),
    .full   (full   ),
    .tfull  (tfull  ),
    .ovf    (ovf    ),
    // read domain
    .rd     (rd     ),
    .rd_addr(rd_addr),
    .empty  (empty  ),
    .tempty (tempty ),
    .udf    (udf    ),
    // remainging signals
    .num_vld(num_vld)
  );
  // -------------------------------------
  // Memory Wrapper
  // -------------------------------------
  two_port_mem #(
    .DATA_WIDTH(DATA_WIDTH),   // Memroy Data DATA_WIDTH
    .DEPTH     (DEPTH     ),   // Memory Depth
    .LATENCY   (LATENCY   ),   // Read Latency used to add flop at output cycle/ mimic ecc latency in case of sram
    .RST_INIT  (RST_INIT  ),   // 0: means memory will not be initialized, 1: memory will be initialized with INIT Val, consumes cycle till depth
    .INIT_VAL  (INIT_VAL  )    // Used to initialize memory with specific value, only used when RST_INIT==1
  ) two_port_mem_inst (
    .rd_clk   (clk         ),
    .wr_clk   (clk         ),
    .arst_n   (arst_n      ),
    .me       ('1          ),   // memory enable
    .wr       (wr && !full ),   // 1: write enable | 0: disable write
    .wr_addr  (wr_addr     ),   // write address channel
    .wr_data  (wr_data     ),   // write data
    .rd       (rd && !empty),   // 1: read enable  | 0: disable read
    .rd_addr  (rd_addr     ),   // read address channel
    .rd_data  (rd_data     ),   // read data
    .init_done(init_done   ),   // initialization done ack
    .sec      (sec         ),
    .ded      (ded         )
  );
endmodule : sfifo
