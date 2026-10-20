## SPDX-License-Identifier: Apache-2.0
## DRAFT. Creates a Zynq UltraScale+ PS IP instance for the sonata-system
## KR260 target so the PL gets pl_clk0 (40 MHz, clk_sys), pl_clk1 (48 MHz,
## clk_usb) and pl_resetn0. Intended to be referenced from sonata.core as a
## tclSource in the synth_kr260 target, next to flow/vivado_setup.tcl.
##
## Only the PL-facing settings matter here: on the KR260 the PS is already
## configured by the FSBL/Linux before the PL is loaded, and the actual
## pl_clk frequencies at run time are set by the device-tree overlay
## (sonata_kr260.dtso). The values below make the IP emit matching
## create_clock constraints for timing analysis.
##
## Not yet run against Vivado; property names follow the zynq_ultra_ps_e
## IP's CONFIG namespace and must be checked on first use. Referenced from
## sonata.core (files_tcl_kr260) as a tclSource of the synth_kr260 target.

set ps_name zynq_ultra_ps_e_0

create_ip -name zynq_ultra_ps_e -vendor xilinx.com -library ip -module_name $ps_name

set_property -dict [list \
  CONFIG.PSU__FPGA_PL0_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {40} \
  CONFIG.PSU__FPGA_PL1_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {48} \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__M_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {0} \
  CONFIG.PSU__USE__IRQ0 {0} \
] [get_ips $ps_name]

## Synthesise the IP inside synth_1 rather than out-of-context. With Vivado's
## default OOC checkpoint the IP is a black box during top-level synthesis
## (UG896), so the *PS8_i/PLCLK[0] -source lookup in data/synth_timing_kr260.xdc
## would find nothing until implementation. The IP is one PS8 primitive plus
## clock buffers, so global synthesis costs nothing.
set ps_xci [get_files -quiet "${ps_name}.xci"]
if {[llength $ps_xci] == 0} {
  set ps_xci [get_property IP_FILE [get_ips $ps_name]]
}
set_property generate_synth_checkpoint false $ps_xci

generate_target all [get_ips $ps_name]

## top_kr260.sv instantiates it as:
##   zynq_ultra_ps_e_0 u_ps (
##     .pl_clk0    (clk_sys),
##     .pl_clk1    (clk_usb),
##     .pl_resetn0 (ps_rst_n)
##   );
## Phase 2 (PS DDR4) enables S_AXI_HP0 here and adds the TL-UL to AXI bridge.
