// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Lint/simulation stand-in for the Zynq UltraScale+ processing system (PS) that top_kr260
// instantiates for its clocks and reset.
//
// The real module of this name is the Vivado IP "zynq_ultra_ps_e_0" that flow/kr260_ps.tcl
// generates in the synth_kr260 flow; it is configured there to drive pl_clk0 at 40 MHz,
// pl_clk1 at 48 MHz and the active-low pl_resetn0 from the PS. This file exists only so that
// the lint_kr260 target can elaborate top_kr260. It must never be in a synthesis
// fileset: it would shadow the IP, and the programmable logic would be left without a clock.
//
// The outputs are plain constants; nothing here models the PS.
module zynq_ultra_ps_e_0 (
  output logic pl_clk0,
  output logic pl_clk1,
  output logic pl_resetn0
);
  assign pl_clk0    = 1'b0;
  assign pl_clk1    = 1'b0;
  assign pl_resetn0 = 1'b0;
endmodule : zynq_ultra_ps_e_0
