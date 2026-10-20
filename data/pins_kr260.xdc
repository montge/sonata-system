## SPDX-License-Identifier: Apache-2.0
## Physical (pin) constraints for the sonata-system KR260 top level,
## rtl/fpga/top_kr260.sv, on the AMD Kria K26 SOM (xck26-sfvc784-2LV-c)
## mounted on the KR260 carrier.
##
## STATUS: DRAFT. Not yet read by Vivado. Every PACKAGE_PIN in this file is
## in one of two states:
##
##   VERIFY  A package pin taken from third-party board definitions found
##           online (the MathWorks HDL Coder KR260 board file and a Vivado
##           2022.2 PMOD tutorial), NOT checked against the KR260 carrier
##           user guide (UG1092), the carrier schematic or AMD's published
##           kr260_custom platform XDC. Only the eight PMOD1 (J2) data pins
##           are in this state. Both sources agreed on the set of eight; the
##           order (which package pin is Pmod pin 1, 2, 3, 4, 7, 8, 9, 10)
##           follows the MathWorks list and is the part most likely to be
##           wrong. Supporting evidence from a primary source: AMD's
##           kria-vitis-platforms kr260_pmod_gps platform (commit 60c3f54,
##           kr260/platforms/kr260_pmod_gps/xdc/pin_timing.xdc) puts its
##           PMOD UART on E12 (txd) and D11 (rxd) and its PPS input on B11,
##           all LVCMOS33, which confirms those three are PMOD data pins
##           but not which connector or which Pmod pin numbers.
##   TODO    No package pin known. The constraint is written out commented,
##           with the connector and connector pin it must be resolved to.
##
## Do not synthesise with this file until every VERIFY has been confirmed and
## every TODO resolved from a primary source, with that source named in this
## header. Vivado will not write a bitstream while ports have no PACKAGE_PIN
## (DRC UCIO-1 / NSTD-1), so the TODO lines are not optional.
##
## All PL I/O on the KR260 PMOD and Raspberry Pi headers is 3.3 V, so
## LVCMOS33 throughout. Pinmuxed ports go through the IOBUF instantiated in
## rtl/fpga/padring.sv and therefore carry IO_BUFFER_TYPE NONE, exactly as
## data/pins_sonata.xdc does for the same signals.
##
## Pmod connector pin numbering (Digilent Pmod interface specification):
## pins 1-4 and 7-10 are data, 5 and 11 are GND, 6 and 12 are VCC (3.3 V).
## Sonata's pmod0[0..7] / pmod1[0..7] are Pmod data pins 1,2,3,4,7,8,9,10 in
## that order.
##
## Connector assignment (phase 1 of the KR260 port):
##   PMOD1 (J2)   console UART0 and debug-module JTAG; data pins 9, 10 spare
##   PMOD2 (J18)  pmod0[7:0]
##   PMOD3 (J19)  pmod1[7:0]
##   PMOD4 (J20)  usrLed[7:0] on data pins 1,2,3,4,7,8,9,10 (external LEDs)
##   RPi header   the 28 rph_* signals, each on the same-named RPi GPIO
## The KR260 has 60 PL header data pins and Sonata would need 64, so Sonata's
## pmodc[5:0] is not brought out (top_kr260 ties its pinmux indices off).

## -----------------------------------------------------------------------
## Clocks and reset: none on package pins. clk_sys (pl_clk0), clk_usb
## (pl_clk1) and the reset (pl_resetn0) come from the Zynq UltraScale+ PS
## instantiated inside top_kr260 (flow/kr260_ps.tcl); the PS IP defines
## their clocks for timing. See data/synth_timing_kr260.xdc.
## -----------------------------------------------------------------------

## -----------------------------------------------------------------------
## PMOD1 (J2): console UART0 and the CHERIoT debug-module JTAG. Dedicated
## (not pinmuxed) signals, so plain buffers and no IO_BUFFER_TYPE NONE.
##
## Package pins marked VERIFY: the set {H12, B10, E10, E12, D10, D11, C11,
## B11} appeared in both third-party sources; the order below assumes it
## lists Pmod data pins 1,2,3,4,7,8,9,10. VERIFY the order against UG1092.
##
##   Pmod pin 1  ser0_tx   UART0 TX, FPGA -> adapter RX
##   Pmod pin 2  ser0_rx   UART0 RX, adapter TX -> FPGA
##   Pmod pin 3  tck_i     JTAG TCK
##   Pmod pin 4  tms_i     JTAG TMS
##   Pmod pin 7  td_i      JTAG TDI
##   Pmod pin 8  td_o      JTAG TDO
##   Pmod pin 9  spare     (VERIFY package pin C11, no port)
##   Pmod pin 10 spare     (VERIFY package pin B11, no port)
## -----------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H12 IOSTANDARD LVCMOS33 } [get_ports ser0_tx] ;# VERIFY  J2 Pmod pin 1
set_property -dict { PACKAGE_PIN B10 IOSTANDARD LVCMOS33 } [get_ports ser0_rx] ;# VERIFY  J2 Pmod pin 2
set_property -dict { PACKAGE_PIN E10 IOSTANDARD LVCMOS33 } [get_ports tck_i]   ;# VERIFY  J2 Pmod pin 3
set_property -dict { PACKAGE_PIN E12 IOSTANDARD LVCMOS33 } [get_ports tms_i]   ;# VERIFY  J2 Pmod pin 4
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports td_i]    ;# VERIFY  J2 Pmod pin 7
set_property -dict { PACKAGE_PIN D11 IOSTANDARD LVCMOS33 } [get_ports td_o]    ;# VERIFY  J2 Pmod pin 8

## JTAG TCK arrives on an ordinary PMOD data pin, not a clock-capable pin.
## Sonata does the same for its tck_i and sets this property.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets tck_i]
## Pack the TDO register in the matching IOB for best output timing, as
## data/pins_sonata.xdc does. Include parent name to prevent accidental matches.
set_property IOB TRUE [get_cells -hier -filter {NAME =~ */i_dmi_jtag_tap/td_o_reg}]

## -----------------------------------------------------------------------
## PMOD4 (J20): user LEDs. usrLed[7:0] are GPIO outputs [7:0], meant for
## external LEDs (the carrier has no PL-connected user LED that has been
## confirmed). usrLed[0..7] = J20 Pmod data pins 1,2,3,4,7,8,9,10. Plain
## outputs (OBUF), drive 4 mA like AMD's own KR260 PMOD constraints. TODO
## package pins from UG1092 / schematic.
## -----------------------------------------------------------------------
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[0]}] ;# TODO  J20 Pmod pin 1
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[1]}] ;# TODO  J20 Pmod pin 2
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[2]}] ;# TODO  J20 Pmod pin 3
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[3]}] ;# TODO  J20 Pmod pin 4
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[4]}] ;# TODO  J20 Pmod pin 7
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[5]}] ;# TODO  J20 Pmod pin 8
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[6]}] ;# TODO  J20 Pmod pin 9
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 DRIVE 4 } [get_ports {usrLed[7]}] ;# TODO  J20 Pmod pin 10

## -----------------------------------------------------------------------
## PMOD2 (J18): Sonata pmod0[7:0]. TODO package pins from UG1092 / schematic.
## pmod0[0..7] = J18 Pmod data pins 1,2,3,4,7,8,9,10.
## -----------------------------------------------------------------------
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[0]}] ;# TODO  J18 Pmod pin 1
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[1]}] ;# TODO  J18 Pmod pin 2
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[2]}] ;# TODO  J18 Pmod pin 3
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[3]}] ;# TODO  J18 Pmod pin 4
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[4]}] ;# TODO  J18 Pmod pin 7
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[5]}] ;# TODO  J18 Pmod pin 8
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[6]}] ;# TODO  J18 Pmod pin 9
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod0[7]}] ;# TODO  J18 Pmod pin 10

## -----------------------------------------------------------------------
## PMOD3 (J19): Sonata pmod1[7:0]. TODO package pins from UG1092 / schematic.
## pmod1[0..7] = J19 Pmod data pins 1,2,3,4,7,8,9,10.
## -----------------------------------------------------------------------
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[0]}] ;# TODO  J19 Pmod pin 1
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[1]}] ;# TODO  J19 Pmod pin 2
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[2]}] ;# TODO  J19 Pmod pin 3
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[3]}] ;# TODO  J19 Pmod pin 4
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[4]}] ;# TODO  J19 Pmod pin 7
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[5]}] ;# TODO  J19 Pmod pin 8
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[6]}] ;# TODO  J19 Pmod pin 9
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports {pmod1[7]}] ;# TODO  J19 Pmod pin 10

## -----------------------------------------------------------------------
## Raspberry Pi 40-pin header: the 28 Sonata rph_* signals, each on the
## KR260 header pin that carries the same-named Raspberry Pi GPIO, so the
## sonata_pkg pinmux indices used by sonata-software stay valid. TODO
## package pins from UG1092 / schematic. The header pin numbers given are
## the standard Raspberry Pi 40-pin assignment of each GPIO; VERIFY that
## the KR260 follows it.
## -----------------------------------------------------------------------
## ID_SD/ID_SC - I2C bus for the HAT ID EEPROM
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g0]       ;# TODO  RPi GPIO0  ID_SD, header pin 27
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g1]       ;# TODO  RPi GPIO1  ID_SC, header pin 28
## Enable pull-ups because this I2C bus will often be undriven externally
## (as data/pins_sonata.xdc does).
# set_property PULLTYPE PULLUP [get_ports rph_g0]                                                           ;# TODO  with the lines above
# set_property PULLTYPE PULLUP [get_ports rph_g1]                                                           ;# TODO  with the lines above
## I2C1 (SDA1/SCL1)
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g2_sda]   ;# TODO  RPi GPIO2  SDA1, header pin 3
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g3_scl]   ;# TODO  RPi GPIO3  SCL1, header pin 5
## GPIO
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g4]       ;# TODO  RPi GPIO4,  header pin 7
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g5]       ;# TODO  RPi GPIO5,  header pin 29
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g6]       ;# TODO  RPi GPIO6,  header pin 31
## SPI0
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g7_ce1]   ;# TODO  RPi GPIO7  SPI0 CE1, header pin 26
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g8_ce0]   ;# TODO  RPi GPIO8  SPI0 CE0, header pin 24
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g9_cipo]  ;# TODO  RPi GPIO9  SPI0 MISO, header pin 21
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g10_copi] ;# TODO  RPi GPIO10 SPI0 MOSI, header pin 19
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g11_sclk] ;# TODO  RPi GPIO11 SPI0 SCLK, header pin 23
## GPIO
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g12]      ;# TODO  RPi GPIO12, header pin 32
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g13]      ;# TODO  RPi GPIO13, header pin 33
## UART (TXD0/RXD0)
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_txd0]     ;# TODO  RPi GPIO14 TXD0, header pin 8
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_rxd0]     ;# TODO  RPi GPIO15 RXD0, header pin 10
## SPI1
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g16_ce2]  ;# TODO  RPi GPIO16 SPI1 CE2, header pin 36
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g17]      ;# TODO  RPi GPIO17 SPI1 CE1, header pin 11
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g18]      ;# TODO  RPi GPIO18 SPI1 CE0, header pin 12
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g19_cipo] ;# TODO  RPi GPIO19 SPI1 MISO, header pin 35
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g20_copi] ;# TODO  RPi GPIO20 SPI1 MOSI, header pin 38
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g21_sclk] ;# TODO  RPi GPIO21 SPI1 SCLK, header pin 40
## GPIO
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g22]      ;# TODO  RPi GPIO22, header pin 15
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g23]      ;# TODO  RPi GPIO23, header pin 16
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g24]      ;# TODO  RPi GPIO24, header pin 18
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g25]      ;# TODO  RPi GPIO25, header pin 22
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g26]      ;# TODO  RPi GPIO26, header pin 37
# set_property -dict { PACKAGE_PIN TODO IOSTANDARD LVCMOS33 IO_BUFFER_TYPE NONE } [get_ports rph_g27]      ;# TODO  RPi GPIO27, header pin 13

## -----------------------------------------------------------------------
## Bitstream settings. Compression is harmless for a PL image loaded by the
## fpga-manager on a running Kria Linux (bootgen -process_bitstream bin
## accepts a compressed .bit) and kept for parity with data/pins_sonata.xdc.
## -----------------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
