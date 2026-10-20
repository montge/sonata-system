// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Simulation model of the UltraScale/UltraScale+ DNA_PORTE2 primitive, the 96-bit
// successor of the 7-series DNA_PORT. Same bit-serial interface: a READ pulse loads the
// device DNA, each SHIFT advances one bit out of DOUT (MSB first), DIN is shifted in.
module DNA_PORTE2 #(
  // Value loaded on READ; the real primitive returns the factory-programmed device DNA.
  parameter [95:0] SIM_DNA_VALUE = 96'h0
) (
  input   CLK,
  input   READ,
  input   SHIFT,
  input   DIN,
  output  DOUT
);

reg [95:0] dna;
always @(posedge CLK) begin
  if (READ) begin
    // This arbitrary number uniquely identifies the simulation model.
    dna <= (SIM_DNA_VALUE != 96'h0) ? SIM_DNA_VALUE : 96'h4b52_36305f1b_8a94d767_3289;
  end else if (SHIFT) begin
    // User can extend the DNA value.
    dna <= {dna[94:0], DIN};
  end
end
assign DOUT = dna[95];

endmodule
