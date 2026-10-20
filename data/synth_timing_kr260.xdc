## Copyright lowRISC contributors.
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

# KR260-specific (AMD Kria K26 SOM) timing constraints for top_kr260.
#
# This file is for timing constraints to be applied *before* synthesis,
# i.e. timing constraints on top-level ports. It stands alone: the
# synth_kr260 target reads it INSTEAD of synth_timing_common.xdc and
# synth_timing.xdc, because those name ports (mainClk, usrusb_*, lcd_*, ...)
# and PLL pins (u_clkgen/pll/CLKOUT*) that top_kr260 does not have. The
# sections that do apply to the KR260 are carried over from
# synth_timing_common.xdc with the same methodology; see that file for the
# full explanation of the I/O delay method and the ASCII timing diagrams.
#
# STATUS: [Vivado] verification pending. This file has not been read by
# Vivado yet. Lines marked CHECK depend on names or values that only a
# Vivado session can confirm:
#   - the clock names clk_pl_0 / clk_pl_1 that the zynq_ultra_ps_e IP's own
#     XDC creates for pl_clk0 / pl_clk1 (check with `report_clocks` after
#     `open_run` or `synth_design`);
#   - the hierarchical pin name of the PS8 primitive's PLCLK[0] output used
#     as the source of the generated SPI clocks;
#   - the trace-length terms, which are Sonata board numbers used as
#     placeholders until the KR260 carrier's lengths are known.
#
# See UG949 and UG903 for information on setting various timing constraints.

#### Recommended timing constraints sequence from UG949 ####
## Timing Assertions Section
# Primary clocks
# Virtual clocks
# Generated clocks
# Delay for external MMCM/PLL feedback loop
# Clock Uncertainty and Jitter
# Input and output delay constraints
# Clock Groups and Clock False Paths
## Timing Exceptions Section
# False Paths
# Max Delay / Min Delay
# Multicycle Paths
# Case Analysis
# Disable Timing


#### Timing Assertions Section ####

### Primary clocks ###
# clk_sys (pl_clk0, 40 MHz) and clk_usb (pl_clk1, 48 MHz) are outputs of the
# Zynq UltraScale+ PS IP instantiated as u_ps in top_kr260 and configured by
# flow/kr260_ps.tcl. The IP ships its own XDC, which creates these clocks on
# the PS8 primitive's PLCLK[0] and PLCLK[1] pins with the periods that follow
# from the PL0/PL1 FREQMHZ settings; Vivado names them clk_pl_0 and clk_pl_1.
# So there is NO create_clock for them here. CHECK the names (see header).
#
# The rate the PS actually drives at run time is set by the device-tree
# overlay that loads the bitstream, not by anything in this file.
#
# JTAG tck: external probe on PMOD1 (J2). Same limit as Sonata.
# create_clock -name tck -period 33.333 [get_ports tck_i] ;# 33 ns = 30 MHz (FT4232HQ max, too fast for us?)
create_clock -name tck     -period 66.666 [get_ports tck_i]   ;# 66 ns = 15 MHz (next step down from FT4232HQ max)

### Virtual clocks ###
# Handy period variables. CHECK clk_pl_0 / clk_pl_1 exist by this point:
# IP XDCs are normally processed EARLY, i.e. before this file.
set clk_sys_ns [get_property PERIOD [get_clocks clk_pl_0]]
set clk_usb_ns [get_property PERIOD [get_clocks clk_pl_1]]
set tck_ns     [get_property PERIOD [get_clocks tck]]
# SPI hosts can run as fast as half the rate of clk_sys
set sclk_ns [expr {2 * $clk_sys_ns}]
# Virtual clock with the system clock period, for the asynchronous
# interfaces (UART, GPIO, I2C) that are constrained loosely against it.
create_clock -name vclk_sys -period $clk_sys_ns

### Generated clocks ###
# The SPI hosts forward clk_sys divided by 2 on their SCLK ports. Their
# master clock pin is the PS8 primitive's PLCLK[0] output inside the PS IP
# (hierarchy u_ps/inst/PS8_i in the IP's wrapper). CHECK this lookup returns
# exactly one pin; `get_pins -of_objects [get_clocks clk_pl_0]` is the
# fallback if the hierarchy differs.
set clk_sys_source_pin [get_pins -hierarchical -filter {NAME =~ *PS8_i/PLCLK[0]}]
# I/O clocks
create_generated_clock -source $clk_sys_source_pin -divide_by 2 \
                       -name clk_pmod0_spi [get_ports {pmod0[3]}] ;# PMOD 0 SPI clk (KR260 PMOD2, J18)
create_generated_clock -source $clk_sys_source_pin -divide_by 2 \
                       -name clk_pmod1_spi [get_ports {pmod1[3]}] ;# PMOD 1 SPI clk (KR260 PMOD3, J19)
create_generated_clock -source $clk_sys_source_pin -divide_by 2 \
                       -name clk_rpi_spi0 [get_ports rph_g11_sclk] ;# R-Pi SPI0 clk
create_generated_clock -source $clk_sys_source_pin -divide_by 2 \
                       -name clk_rpi_spi1 [get_ports rph_g21_sclk] ;# R-Pi SPI1 clk

### Delay for external MMCM/PLL feedback loop ###
# N/A - no PLL or MMCM in the programmable logic; the PS PLLs are inside the
# PS IP.

### Clock Uncertainty and Jitter ###
# The PS IP's XDC covers its own clock outputs; nothing to add. The Sonata
# set_input_jitter on mainClk does not apply (no clock input port).

### Input and output delay constraints ###
# Same methodology as synth_timing_common.xdc; see there for the
# explanation of the setup/hold diagrams and the trace-delay estimates
# (0.010 ns/mm for max, 0.004 ns/mm for min).

## Debug-module JTAG on PMOD1 (J2), external probe.
# Synchronous w/tck. Inputs to be sampled on rising edge. Output to be driven
# on falling edge. Same assumptions as Sonata: inputs valid from only a few
# nanoseconds before the rising clk edge to just before the falling edge.
set_input_delay -clock tck -max [expr {$tck_ns - 3.0              }] [get_ports td_i]
set_input_delay -clock tck -min [expr {          $tck_ns/2.0 - 2.0}] [get_ports td_i]
set_input_delay -clock tck -max [expr {$tck_ns - 3.0              }] [get_ports tms_i]
set_input_delay -clock tck -min [expr {          $tck_ns/2.0 - 2.0}] [get_ports tms_i]
# Require the output to be valid at the probe from 11 ns (FT4232HQ setup
# requirement, the kind of probe Sonata's flow assumes) before the rising
# clk edge to a quarter of a clock period after it. The probe is off-board on
# flying leads here; keep Sonata's 30 mm trace term and, as upstream, assume
# an off-board JTAG driver accounts for cable delay or runs slower. CHECK.
set jtag_trce_dly_max [expr { 30 * 2 * 0.010}]
set jtag_trce_dly_min [expr { 30 * 2 * 0.004}]
set_output_delay -clock tck -max [expr {$jtag_trce_dly_max + 11.0       }] [get_ports td_o]
set_output_delay -clock tck -min [expr {$jtag_trce_dly_min - $tck_ns/4.0}] [get_ports td_o]

## UART 0 console on PMOD1 (J2) - essentially asynchronous, x16 oversampled
# UART RX is 16x oversampled and uses a 2-flop synchroniser; TX matches the
# RX baud rate. At 921600 baud and 40 MHz a bit is about 43 clock cycles, so
# the I/O timing cannot matter. Zero I/O delays here and a generous
# multicycle constraint in the timing exceptions section, as Sonata does.
set_input_delay -clock vclk_sys -max 0 [get_ports ser0_rx]
set_input_delay -clock vclk_sys -min 0 [get_ports ser0_rx]
set_output_delay -clock vclk_sys -max 0 [get_ports ser0_tx]
set_output_delay -clock vclk_sys -min 0 [get_ports ser0_tx]

## PMOD 0 (KR260 PMOD2, J18)
#   SPI (or I^2C or UART or GPIO, but let us assume SPI is most critical)
# Carried over from Sonata. Trace distance is Sonata's ~20-25 mm; the KR260
# carrier's is unknown (CHECK), only the min-delay term depends on it.
set pmod0_spi_trce_dly_min [expr {20 * 2 * 0.004}]
set_input_delay -clock clk_pmod0_spi -max [expr {$sclk_ns - 22                         }] [get_ports {pmod0[2]}] ;# CIPO
set_input_delay -clock clk_pmod0_spi -min [expr {$sclk_ns/2.0 + $pmod0_spi_trce_dly_min}] [get_ports {pmod0[2]}]
set_output_delay -clock clk_pl_0 -max [expr {$clk_sys_ns - 14}] [get_ports {pmod0[3]}] ;# SCLK
set_output_delay -clock clk_pl_0 -min 0                         [get_ports {pmod0[3]}]
set_output_delay -clock clk_pmod0_spi -max [expr {$sclk_ns - 6           }] [get_ports {pmod0[1]}] ;# COPI
set_output_delay -clock clk_pmod0_spi -min [expr {           $sclk_ns/2.0}] [get_ports {pmod0[1]}]
set_output_delay -clock clk_pmod0_spi -max [expr {$sclk_ns - 6           }] [get_ports {pmod0[0] pmod0[6] pmod0[7]}] ;# chip selects
set_output_delay -clock clk_pmod0_spi -min [expr {           $sclk_ns/2.0}] [get_ports {pmod0[0] pmod0[6] pmod0[7]}]
#   GPIO/PWM (that are not SPI)
# Could be human-scale or processor-scale (bit-bashing) time periods.
# Put a multicycle constraint on them both in the timing exceptions section,
# and zero I/O delays here.
set pmod0_gpio_names {pmod0[4] pmod0[5]}
set_input_delay -clock vclk_sys -max 0 [get_ports $pmod0_gpio_names]
set_input_delay -clock vclk_sys -min 0 [get_ports $pmod0_gpio_names]
set_output_delay -clock vclk_sys -max 0 [get_ports $pmod0_gpio_names]
set_output_delay -clock vclk_sys -min 0 [get_ports $pmod0_gpio_names]

## PMOD 1 (KR260 PMOD3, J19)
# Same as PMOD 0. Sonata's trace distance of ~25-30 mm kept as placeholder (CHECK).
set pmod1_spi_trce_dly_min [expr {25 * 2 * 0.004}]
set_input_delay -clock clk_pmod1_spi -max [expr {$sclk_ns - 22                         }] [get_ports {pmod1[2]}] ;# CIPO
set_input_delay -clock clk_pmod1_spi -min [expr {$sclk_ns/2.0 + $pmod1_spi_trce_dly_min}] [get_ports {pmod1[2]}]
set_output_delay -clock clk_pl_0 -max [expr {$clk_sys_ns - 14}] [get_ports {pmod1[3]}] ;# SCLK
set_output_delay -clock clk_pl_0 -min 0                         [get_ports {pmod1[3]}]
set_output_delay -clock clk_pmod1_spi -max [expr {$sclk_ns - 6           }] [get_ports {pmod1[1]}] ;# COPI
set_output_delay -clock clk_pmod1_spi -min [expr {           $sclk_ns/2.0}] [get_ports {pmod1[1]}]
set_output_delay -clock clk_pmod1_spi -max [expr {$sclk_ns - 6           }] [get_ports {pmod1[0] pmod1[6] pmod1[7]}] ;# chip selects
set_output_delay -clock clk_pmod1_spi -min [expr {           $sclk_ns/2.0}] [get_ports {pmod1[0] pmod1[6] pmod1[7]}]
#   GPIO/PWM (that are not SPI)
# Use same methodology as PMOD 0 GPIO
set pmod1_gpio_names {pmod1[4] pmod1[5]}
set_input_delay -clock vclk_sys -max 0 [get_ports $pmod1_gpio_names]
set_input_delay -clock vclk_sys -min 0 [get_ports $pmod1_gpio_names]
set_output_delay -clock vclk_sys -max 0 [get_ports $pmod1_gpio_names]
set_output_delay -clock vclk_sys -min 0 [get_ports $pmod1_gpio_names]

## PMOD C (KR260 PMOD4, J20) - asynchronous GPIO
# Use same methodology as PMOD 0 GPIO

## R-Pi Header
##   GPIO/SPI0 bus
# Carried over from Sonata (its ~3-10 mm trace distance kept, CHECK).
set rph_spi0_trce_dly_min [expr {3 * 2 * 0.004}]
set_input_delay -clock clk_rpi_spi0 -max [expr {$sclk_ns - 16                        }] [get_ports rph_g9_cipo] ;# CIPO
set_input_delay -clock clk_rpi_spi0 -min [expr {$sclk_ns/2.0 + $rph_spi0_trce_dly_min}] [get_ports rph_g9_cipo]
set_output_delay -clock clk_pl_0 -max [expr {$clk_sys_ns - 14}] [get_ports rph_g11_sclk] ;# SCLK
set_output_delay -clock clk_pl_0 -min 0                         [get_ports rph_g11_sclk]
set_output_delay -clock clk_rpi_spi0 -max [expr {$sclk_ns - 6           }] [get_ports rph_g10_copi] ;# COPI
set_output_delay -clock clk_rpi_spi0 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g10_copi]
set_output_delay -clock clk_rpi_spi0 -max [expr {$sclk_ns - 6           }] [get_ports rph_g8_ce0] ;# chip select 0
set_output_delay -clock clk_rpi_spi0 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g8_ce0]
set_output_delay -clock clk_rpi_spi0 -max [expr {$sclk_ns - 6           }] [get_ports rph_g7_ce1] ;# chip select 1
set_output_delay -clock clk_rpi_spi0 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g7_ce1]
##   GPIO/SPI1 bus
# Carried over from Sonata (its ~5-15 mm trace distance kept, CHECK).
set rph_spi1_trce_dly_min [expr {5 * 2 * 0.004}]
set_input_delay -clock clk_rpi_spi1 -max [expr {$sclk_ns - 16                        }] [get_ports rph_g19_cipo] ;# CIPO
set_input_delay -clock clk_rpi_spi1 -min [expr {$sclk_ns/2.0 + $rph_spi1_trce_dly_min}] [get_ports rph_g19_cipo]
set_output_delay -clock clk_pl_0 -max [expr {$clk_sys_ns - 14}] [get_ports rph_g21_sclk] ;# SCLK
set_output_delay -clock clk_pl_0 -min 0                         [get_ports rph_g21_sclk]
set_output_delay -clock clk_rpi_spi1 -max [expr {$sclk_ns - 6           }] [get_ports rph_g20_copi] ;# COPI
set_output_delay -clock clk_rpi_spi1 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g20_copi]
set_output_delay -clock clk_rpi_spi1 -max [expr {$sclk_ns - 6           }] [get_ports rph_g18] ;# chip select 0
set_output_delay -clock clk_rpi_spi1 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g18]
set_output_delay -clock clk_rpi_spi1 -max [expr {$sclk_ns - 6           }] [get_ports rph_g17] ;# chip select 1
set_output_delay -clock clk_rpi_spi1 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g17]
set_output_delay -clock clk_rpi_spi1 -max [expr {$sclk_ns - 6           }] [get_ports rph_g16_ce2] ;# chip select 2
set_output_delay -clock clk_rpi_spi1 -min [expr {           $sclk_ns/2.0}] [get_ports rph_g16_ce2]
##   GPIO/I2C bus
# I2C Fast-mode Plus (1 MHz) is slow compared with the system clock: zero
# I/O delays here, multicycle constraints in the timing exceptions section.
set_input_delay -clock vclk_sys -max 0 [get_ports {rph_g2_sda rph_g3_scl}]
set_input_delay -clock vclk_sys -min 0 [get_ports {rph_g2_sda rph_g3_scl}]
set_output_delay -clock vclk_sys -max 0 [get_ports {rph_g2_sda rph_g3_scl}]
set_output_delay -clock vclk_sys -min 0 [get_ports {rph_g2_sda rph_g3_scl}]
##   UART
# Use same methodology as UART 0
set_input_delay -clock vclk_sys -max 0 [get_ports rph_rxd0]
set_input_delay -clock vclk_sys -min 0 [get_ports rph_rxd0]
set_output_delay -clock vclk_sys -max 0 [get_ports rph_txd0]
set_output_delay -clock vclk_sys -min 0 [get_ports rph_txd0]
##   Other GPIO
# Use same methodology as PMOD 0 GPIO
set rph_gpio_names {rph_g4 rph_g5 rph_g6 rph_g12 rph_g13 rph_g22 rph_g23 rph_g24 rph_g25 rph_g26 rph_g27}
set_input_delay -clock vclk_sys -max 0 [get_ports $rph_gpio_names]
set_input_delay -clock vclk_sys -min 0 [get_ports $rph_gpio_names]
set_output_delay -clock vclk_sys -max 0 [get_ports $rph_gpio_names]
set_output_delay -clock vclk_sys -min 0 [get_ports $rph_gpio_names]
##   ID_SC/SD - I2C bus for HAT ID EEPROM
# Use same methodology as the R-Pi I2C bus
set_input_delay -clock vclk_sys -max 0 [get_ports {rph_g1 rph_g0}] ;# rph_g1 = ID_SC
set_input_delay -clock vclk_sys -min 0 [get_ports {rph_g1 rph_g0}] ;# rph_g0 = ID_SD
set_output_delay -clock vclk_sys -max 0 [get_ports {rph_g1 rph_g0}]
set_output_delay -clock vclk_sys -min 0 [get_ports {rph_g1 rph_g0}]

### Clock Groups and Clock False Paths ###
# clk_pl_0 (clk_sys) and clk_pl_1 (clk_usb) come from separate PS dividers
# with no fixed phase relationship, and the design crosses between them only
# through prim_flop_2sync / prim_fifo_async. JTAG tck is completely
# asynchronous to both. The generated SPI clocks belong with clk_pl_0.
# CHECK that get_clocks finds clk_pl_0 and clk_pl_1 (see header).
set_clock_groups -asynchronous \
  -group [get_clocks tck] \
  -group [get_clocks -include_generated_clocks clk_pl_0] \
  -group [get_clocks -include_generated_clocks clk_pl_1]


#### Timing Exceptions Section ####

### False Paths ###

## User LEDs on header pins - human-scale asynchronous
set_false_path -to [get_ports {usrLed[*]}]

## PMOD 0 & 1
# Ignore setup paths from PMOD multi-use ports that can be UART RX (but we are
# modelling as an SPI port) to UART TX ports.
# These are caused by the UART line loopback combined with pinmux.
set_false_path -setup -from [get_ports {pmod0[2] pmod1[2]}] -to [get_clocks vclk_sys]
# Ignore hold paths from UART RX ports to the PMOD multi-use ports that can be
# UART TX (but we are modelling as an SPI port).
# These are caused by the UART line loopback combined with pinmux.
set_false_path -hold -from [get_clocks vclk_sys] -to [get_ports {pmod0[1] pmod1[1]}]

## prim_flop_2sync
# Set false_path timing exceptions on 2-stage synchroniser inputs.
# Target the inputs because the flops inside are clocked by the destination.
# Mostly redundant with the asynchronous clock groups above, kept for parity
# with Sonata and for any synchroniser fed from within the same group.
#
# Reliant on the hierarchical pin names of the synchronisers remaining
# unchanged during synthesis due to use of DONT_TOUCH or KEEP_HIERARCHY.
set sync_cells [get_cells -hier -filter {ORIG_REF_NAME == prim_flop_2sync}]
set sync_pins [get_pins -filter {REF_PIN_NAME =~ d_i*} -of $sync_cells]
# Filter out any that do not have a real timing path (fail to find leaf cell).
set sync_endpoints [filter [all_fanout -endpoints_only -flat $sync_pins] IS_LEAF]
set_false_path -to $sync_endpoints

## prim_fifo_async and prim_fifo_async_simple
# Set false_path timing exceptions on asynchronous fifo outputs.
# Target the outputs because the storage elements are clocked by the source
# clock domain (but made safe to read from the destination clock domain
# thanks to the gray-coded read/write pointers and surrounding logic).
#
# Reliant on the hierarchical pin names used here remaining unchanged during
# synthesis by setting DONT_TOUCH or KEEP_HIERARCHY earlier in the flow.
set async_fifo_cells [get_cells -hier -regexp -filter {ORIG_REF_NAME =~ {prim_fifo_async(_simple)?}}]
set async_fifo_pins [get_pins -filter {REF_PIN_NAME =~ rdata_o*} -of $async_fifo_cells]
set async_fifo_startpoints [all_fanin -startpoints_only -flat $async_fifo_pins]
# Specify `-through` as well as `-from` to avoid including non-rdata_o paths,
# such as paths from the read pointers that stay internal or exit via rvalid_o.
set_false_path -from $async_fifo_startpoints -through $async_fifo_pins

### Max Delay / Min Delay ###

## Reset async-assert sync-deassert CDC - async path to synchroniser reset pins
# Use max_delay rather than false_path to avoid big skew between clock domains.
# Note: set_clock_groups has priority over set_max_delay (UG903), so this only
# bounds the paths that stay inside one clock group; kept for parity with
# Sonata.
#
# Reliant on the hierarchical pin names used here remaining unchanged during
# synthesis by setting DONT_TOUCH or KEEP_HIERARCHY earlier in the flow.
set rst_sync_cells [get_cells u_rst_sync/* -filter {ORIG_REF_NAME == prim_flop_2sync}]
set rst_sync_pins [get_pins -filter {REF_PIN_NAME =~ rst_ni} -of $rst_sync_cells]
# Filter out any that do not have a real timing path (fail to find leaf cell).
set rst_sync_endpoints [filter [all_fanout -endpoints_only -flat $rst_sync_pins] IS_LEAF]
set_max_delay $clk_sys_ns -to $rst_sync_endpoints

### Multicycle Paths ###

## SPI interfaces
# Data is clocked by the SPI host no faster than half the rate of the system clk.
set header_spi_mulcycs 2
## PMOD 0 SPI
set pmod0_spi_mulcycs $header_spi_mulcycs
set_multicycle_path        $pmod0_spi_mulcycs       -setup -start -to [get_ports {pmod0[0] pmod0[1] pmod0[3] pmod0[6] pmod0[7]}]
set_multicycle_path [expr {$pmod0_spi_mulcycs - 1}] -hold  -start -to [get_ports {pmod0[0] pmod0[1] pmod0[3] pmod0[6] pmod0[7]}]
set_multicycle_path        $pmod0_spi_mulcycs       -setup -end -from [get_ports {pmod0[2]}]
set_multicycle_path [expr {$pmod0_spi_mulcycs - 1}] -hold  -end -from [get_ports {pmod0[2]}]
## PMOD 1 SPI
set pmod1_spi_mulcycs $header_spi_mulcycs
set_multicycle_path        $pmod1_spi_mulcycs       -setup -start -to [get_ports {pmod1[0] pmod1[1] pmod1[3] pmod1[6] pmod1[7]}]
set_multicycle_path [expr {$pmod1_spi_mulcycs - 1}] -hold  -start -to [get_ports {pmod1[0] pmod1[1] pmod1[3] pmod1[6] pmod1[7]}]
set_multicycle_path        $pmod1_spi_mulcycs       -setup -end -from [get_ports {pmod1[2]}]
set_multicycle_path [expr {$pmod1_spi_mulcycs - 1}] -hold  -end -from [get_ports {pmod1[2]}]
## R-Pi SPI0
set rph_spi0_mulcycs $header_spi_mulcycs
set_multicycle_path        $rph_spi0_mulcycs       -setup -start -to [get_ports {rph_g10_copi rph_g8_ce0 rph_g7_ce1}]
set_multicycle_path [expr {$rph_spi0_mulcycs - 1}] -hold  -start -to [get_ports {rph_g10_copi rph_g8_ce0 rph_g7_ce1}]
set_multicycle_path        $rph_spi0_mulcycs       -setup -end -from [get_ports rph_g9_cipo]
set_multicycle_path [expr {$rph_spi0_mulcycs - 1}] -hold  -end -from [get_ports rph_g9_cipo]
## R-Pi SPI1
set rph_spi1_mulcycs $header_spi_mulcycs
set_multicycle_path        $rph_spi1_mulcycs       -setup -start -to [get_ports {rph_g20_copi rph_g18 rph_g17 rph_g16_ce2}]
set_multicycle_path [expr {$rph_spi1_mulcycs - 1}] -hold  -start -to [get_ports {rph_g20_copi rph_g18 rph_g17 rph_g16_ce2}]
set_multicycle_path        $rph_spi1_mulcycs       -setup -end -from [get_ports rph_g19_cipo]
set_multicycle_path [expr {$rph_spi1_mulcycs - 1}] -hold  -end -from [get_ports rph_g19_cipo]

## UART interfaces
## UART 0 console - essentially asynchronous, x16 oversampled
# UART RX and TX are run 16x faster than the baud rate.
# Allow them to be captured or output over the course of half a bit-period.
set header_uart_mulcycs 8
set ser0_mulcycs $header_uart_mulcycs
set_multicycle_path        $ser0_mulcycs       -setup -from [get_ports ser0_rx]
set_multicycle_path [expr {$ser0_mulcycs - 1}] -hold  -from [get_ports ser0_rx]
set_multicycle_path        $ser0_mulcycs       -setup -to [get_ports ser0_tx]
set_multicycle_path [expr {$ser0_mulcycs - 1}] -hold  -to [get_ports ser0_tx]
## R-Pi Header UART - use same methodology as UART 0
set rph_ser_mulcycs $header_uart_mulcycs
set_multicycle_path        $rph_ser_mulcycs       -setup -from [get_ports rph_rxd0]
set_multicycle_path [expr {$rph_ser_mulcycs - 1}] -hold  -from [get_ports rph_rxd0]
set_multicycle_path        $rph_ser_mulcycs       -setup -to [get_ports rph_txd0]
set_multicycle_path [expr {$rph_ser_mulcycs - 1}] -hold  -to [get_ports rph_txd0]

## I2C interfaces
# Some timings of clock and data pulses are run-time programmable in units
# of system clock cycles; two cycles balances repeatable user-programmable
# timing against relaxed physical timing (as Sonata).
set header_i2c_mulcycs 2
## R-Pi Header I2C
set rph_i2c_mulcycs $header_i2c_mulcycs
set_multicycle_path        $rph_i2c_mulcycs       -setup -from [get_ports {rph_g2_sda rph_g3_scl}]
set_multicycle_path [expr {$rph_i2c_mulcycs - 1}] -hold  -from [get_ports {rph_g2_sda rph_g3_scl}]
set_multicycle_path        $rph_i2c_mulcycs       -setup -to [get_ports {rph_g2_sda rph_g3_scl}]
set_multicycle_path [expr {$rph_i2c_mulcycs - 1}] -hold  -to [get_ports {rph_g2_sda rph_g3_scl}]
## R-Pi Hat ID EEPROM I2C
set rph_id_mulcycs $header_i2c_mulcycs
set_multicycle_path        $rph_id_mulcycs       -setup -from [get_ports {rph_g1 rph_g0}]
set_multicycle_path [expr {$rph_id_mulcycs - 1}] -hold  -from [get_ports {rph_g1 rph_g0}]
set_multicycle_path        $rph_id_mulcycs       -setup -to [get_ports {rph_g1 rph_g0}]
set_multicycle_path [expr {$rph_id_mulcycs - 1}] -hold  -to [get_ports {rph_g1 rph_g0}]

## GPIO
# Could be human-scale or processor-scale (bit-bashing) time periods.
# Allow two cycles so that known high-speed ports get place & route priority.
set header_gpio_mulcycs 2
## PMOD 0 GPIO
set pmod0_gpio_mulcycs $header_gpio_mulcycs
set_multicycle_path        $pmod0_gpio_mulcycs       -setup -from [get_ports $pmod0_gpio_names]
set_multicycle_path [expr {$pmod0_gpio_mulcycs - 1}] -hold  -from [get_ports $pmod0_gpio_names]
set_multicycle_path        $pmod0_gpio_mulcycs       -setup -to [get_ports $pmod0_gpio_names]
set_multicycle_path [expr {$pmod0_gpio_mulcycs - 1}] -hold  -to [get_ports $pmod0_gpio_names]
## PMOD 1 GPIO
set pmod1_gpio_mulcycs $header_gpio_mulcycs
set_multicycle_path        $pmod1_gpio_mulcycs       -setup -from [get_ports $pmod1_gpio_names]
set_multicycle_path [expr {$pmod1_gpio_mulcycs - 1}] -hold  -from [get_ports $pmod1_gpio_names]
set_multicycle_path        $pmod1_gpio_mulcycs       -setup -to [get_ports $pmod1_gpio_names]
set_multicycle_path [expr {$pmod1_gpio_mulcycs - 1}] -hold  -to [get_ports $pmod1_gpio_names]
## PMOD C
## R-Pi Header GPIO
set rph_gpio_mulcycs $header_gpio_mulcycs
set_multicycle_path        $rph_gpio_mulcycs       -setup -from [get_ports $rph_gpio_names]
set_multicycle_path [expr {$rph_gpio_mulcycs - 1}] -hold  -from [get_ports $rph_gpio_names]
set_multicycle_path        $rph_gpio_mulcycs       -setup -to [get_ports $rph_gpio_names]
set_multicycle_path [expr {$rph_gpio_mulcycs - 1}] -hold  -to [get_ports $rph_gpio_names]

### Case Analysis ###
# none at present

### Disable Timing ###
# none at present
