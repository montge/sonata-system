# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# OpenOCD configuration for the CHERIoT debug module of the sonata-system
# KR260 build (target synth_kr260). The debug JTAG (tck_i, tms_i, td_i, td_o)
# is on KR260 PMOD1 (J2); the board's own USB-JTAG goes to the MPSoC chain,
# not to these pins, so an external probe is needed.
#
# Pick the probe with the KR260_JTAG_ADAPTER environment variable, which
# names an OpenOCD interface script. Examples:
#   interface/ftdi/digilent-hs2.cfg      (Digilent JTAG-HS2, default)
#   interface/ftdi/olimex-arm-usb-tiny-h.cfg
#   interface/ftdi/um232h.cfg            (FT232H breakout)
# Usage, from the sonata-system root:
#   KR260_JTAG_ADAPTER=interface/ftdi/digilent-hs2.cfg \
#     util/mem_helper.sh load_program -e app.elf -t util/kr260-openocd-cfg.tcl
#
# Not yet run against hardware: adapter speed and the probe layout need a
# first bring-up session (see doc/dev/kr260.md).

if { [info exists ::env(KR260_JTAG_ADAPTER)] } {
  source [find $::env(KR260_JTAG_ADAPTER)]
} else {
  source [find interface/ftdi/digilent-hs2.cfg]
}
transport select jtag

# Configure JTAG chain and the target processor
set _CHIPNAME riscv-cheriot

# Same JTAG IDCODE as Sonata (rtl/system/jtag_id_pkg.sv)
set _EXPECTED_ID 0x11011CDF

jtag newtap $_CHIPNAME cpu -irlen 5 -expected-id $_EXPECTED_ID -ignore-version
set _TARGETNAME $_CHIPNAME.cpu
target create $_TARGETNAME riscv -chain-position $_TARGETNAME

# Flying leads on a PMOD header: start slow, raise once it works.
adapter speed 2000

riscv set_mem_access sysbus
gdb_report_data_abort enable
gdb_report_register_access_error enable
gdb_breakpoint_override hard
reset_config none

init
halt
