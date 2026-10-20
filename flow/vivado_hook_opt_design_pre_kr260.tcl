# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# NOTE: This hook is only run when included in the flow by "vivado_setup.tcl".
# KR260 variant of vivado_hook_opt_design_pre.tcl: the system clock is the
# Zynq PS IP's pl_clk0, which the IP's own constraints name clk_pl_0 (to be
# confirmed in the first Vivado run, see data/synth_timing_kr260.xdc), not a
# clock called clk_sys. The over-constraint is only an optimisation aid, so a
# missing or renamed clock must not fail impl_1.

# Over-constrain the clock used by the core during early implementation stages
# to avoid/reduce post-route timing violations. Cleared before route_design by
# vivado_hook_route_design_pre_kr260.tcl. See the Sonata hook for the rationale.
set sys_clks [get_clocks -quiet clk_pl_0]
if {[llength $sys_clks] == 0} {
  set sys_clks [get_clocks -quiet -of_objects \
    [get_pins -quiet -hierarchical -filter {NAME =~ *PS8_i/PLCLK[0]}]]
}
if {[llength $sys_clks] == 0} {
  puts "WARNING: KR260 opt_design hook: system clock not found, no over-constraint applied"
}
foreach c $sys_clks {
  set_clock_uncertainty -setup 0.8 $c
}
