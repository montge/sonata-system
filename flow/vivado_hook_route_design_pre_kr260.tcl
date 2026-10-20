# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# NOTE: This hook is only run when included in the flow by "vivado_setup.tcl".
# KR260 variant of vivado_hook_route_design_pre.tcl (system clock is the PS
# IP's pl_clk0, named clk_pl_0; see vivado_hook_opt_design_pre_kr260.tcl).

# Clear the clock over-constraint for the routing stage.
set sys_clks [get_clocks -quiet clk_pl_0]
if {[llength $sys_clks] == 0} {
  set sys_clks [get_clocks -quiet -of_objects \
    [get_pins -quiet -hierarchical -filter {NAME =~ *PS8_i/PLCLK[0]}]]
}
foreach c $sys_clks {
  set_clock_uncertainty -setup 0 $c
}
