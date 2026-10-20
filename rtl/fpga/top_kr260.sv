// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Sonata system top level for the AMD Kria KR260 (K26 SOM, Zynq UltraScale+ XCK26).
//
// How this differs from top_sonata (Sonata One / Sonata XL):
//
// - Clocks and reset come from the Zynq UltraScale+ processing system (PS): pl_clk0 (40 MHz) is
//   clk_sys, pl_clk1 (48 MHz) is clk_usb and the active-low pl_resetn0 takes the place of the
//   reset button. There is no PLL or MMCM in the programmable logic. The PS is the Vivado IP
//   "zynq_ultra_ps_e_0" created by flow/kr260_ps.tcl; dv/models/fpga/rtl/zynq_ultra_ps_e_0.sv
//   is a stand-in for lint only. The rates are only enforced by the PS configuration and the
//   device-tree overlay, so SysClkFreq must be kept equal to the pl_clk0 rate set there.
//
// - There is no HyperRAM. The target builds with USE_HYPERRAM_SRAM_MODEL and HyperRAMSize bytes
//   of on-chip RAM at the HyperRAM address; the HyperRAM clocks and reset are tied off the way
//   sonata_system does for Sonata XL, and the HyperRAM pins stay on internal wires.
//
// - The board I/O reachable from the programmable logic is four PMODs and the Raspberry Pi
//   header, all 3.3 V. The Sonata signal names and sonata_pkg pinmux indices are kept so the
//   sonata-software board description works unchanged:
//
//     KR260 PMOD1 (J2)   UART0 TX/RX on pins 1-2 and the debug-module JTAG on pins 3-4 and 7-8;
//                        these are dedicated (not pinmuxed) signals; pins 9-10 are spare
//     KR260 PMOD2 (J18)  Sonata pmod0[7:0]
//     KR260 PMOD3 (J19)  Sonata pmod1[7:0]
//     KR260 PMOD4 (J20)  usrLed[7:0] = GPIO outputs [7:0], for external LEDs
//     RPi header         the 28 Sonata rph_* signals, each on the same-named RPi GPIO
//
//   The KR260 has 60 PL header data pins (4 x 8 PMOD + 28 RPi) and Sonata would need 64 (the
//   above plus pmodc[5:0]), so Sonata's PMODC is not brought out: its six pinmux indices are tied
//   off like the Arduino header pins. The package pins are in data/pins_kr260.xdc.
//
// - Everything Sonata has that the KR260 does not (QWIIC I2C buses, Arduino shield, mikroBUS,
//   LCD, Ethernet MAC, microSD, SPI flash, RS-232, RS-485, USB transceiver, RGB LEDs, switches,
//   joystick, status LEDs) has its inputs tied to inactive levels and its outputs left on
//   internal unused_* signals. In particular the CHERI error indicators (cheri_err_o) and the
//   CHERI enable indicator are not connected to any pin in phase 1.
module top_kr260
  import sonata_pkg::*;
(
  // Console UART0, dedicated pins on KR260 PMOD1 (J2)
  output logic       ser0_tx,
  input  logic       ser0_rx,

  // CHERIoT debug module JTAG, dedicated pins on KR260 PMOD1 (J2)
  input  logic       tck_i,
  input  logic       tms_i,
  input  logic       td_i,
  output logic       td_o,

  // User LEDs = GPIO outputs [7:0], on KR260 PMOD4 (J20) data pins (external LEDs)
  output logic [7:0] usrLed,

  // Pinmuxed PMODs, Sonata names kept so sonata-software pinmux indices are unchanged:
  // KR260 PMOD2 (J18) -> pmod0, PMOD3 (J19) -> pmod1. Sonata's pmodc is not brought out.
  inout  logic [7:0] pmod0,
  inout  logic [7:0] pmod1,

  // Raspberry Pi header, the same 28 signals as on Sonata

  // R-Pi header I2C buses
  inout  logic       rph_g3_scl,   // SCL1/GPIO3 on Header
  inout  logic       rph_g2_sda,   // SDA1/GPIO2

  inout  logic       rph_g1,       // ID_SC for HAT ID EEPROM
  inout  logic       rph_g0,       // ID_SD

  // R-Pi header SPI buses
  inout  logic       rph_g11_sclk, // SPI0
  inout  logic       rph_g10_copi, // SPI0
  inout  logic       rph_g9_cipo,  // SPI0
  inout  logic       rph_g8_ce0,   // SPI0
  inout  logic       rph_g7_ce1,   // SPI0

  inout  logic       rph_g21_sclk, // SPI1
  inout  logic       rph_g20_copi, // SPI1
  inout  logic       rph_g19_cipo, // SPI1
  inout  logic       rph_g18,      // SPI1 CE0
  inout  logic       rph_g17,      // SPI1 CE1
  inout  logic       rph_g16_ce2,  // SPI1

  // R-Pi header UART
  inout  logic       rph_txd0,
  inout  logic       rph_rxd0,

  // R-Pi header GPIO
  inout  logic       rph_g27,
  inout  logic       rph_g26,
  inout  logic       rph_g25,
  inout  logic       rph_g24,
  inout  logic       rph_g23,
  inout  logic       rph_g22,
  inout  logic       rph_g13,
  inout  logic       rph_g12,
  inout  logic       rph_g6,
  inout  logic       rph_g5,
  inout  logic       rph_g4
);
  // System clock frequency. Must equal the pl_clk0 rate configured in flow/kr260_ps.tcl and in
  // the device-tree overlay that loads the bitstream.
  parameter int unsigned SysClkFreq      =  40_000_000;
  // Passed through to sonata_system for the HyperRAM controller, which this target does not use.
  parameter int unsigned HyperRAMClkFreq = 100_000_000;
  // Size in bytes of the on-chip RAM standing in for the HyperRAM (USE_HYPERRAM_SRAM_MODEL).
  parameter int unsigned HyperRAMSize    = 256 * 1024;

  parameter SRAMInitFile    = "";

  ////////////////////
  // Clocks, resets //
  ////////////////////

  // Clocks and reset from the PS
  logic clk_sys;
  logic clk_usb;
  logic ps_rst_n;

  // Main reset, and the per-domain synchronised resets
  logic rst_btn;
  logic rst_n;
  logic rst_sys_n;
  logic rst_usb_n;

  // There is no HyperRAM clock domain on the KR260. Its clocks and reset are tied off exactly as
  // sonata_system does under TARGET_XL_BOARD; the SRAM model inside sonata_system ignores them.
  logic clk_hr, clk_hr90p, clk_hr3x;
  logic rst_hr_n;
  logic unused_rst_hr_n;

  assign clk_hr    = 1'b0;
  assign clk_hr90p = 1'b0;
  assign clk_hr3x  = 1'b0;
  assign rst_hr_n  = 1'b0;

  // pl_clk0 and pl_clk1 of the Zynq UltraScale+ PS. In the synth_kr260 flow this is the Vivado IP
  // generated by flow/kr260_ps.tcl (40 MHz and 48 MHz); for lint it is the constant stand-in in
  // dv/models/fpga/rtl/zynq_ultra_ps_e_0.sv.
  zynq_ultra_ps_e_0 u_ps (
    .pl_clk0   (clk_sys),
    .pl_clk1   (clk_usb),
    .pl_resetn0(ps_rst_n)
  );

  // Produce the reset at the beginning of time and whenever the PS asserts pl_resetn0 (active
  // low); rst_ctrl wants an active-high button input. The PS clocks are stable before the PL is
  // configured, so there is no PLL lock to wait for.
  assign rst_btn = ~ps_rst_n;

  rst_ctrl u_rst_ctrl (
    .clk_i       (clk_sys),
    .pll_locked_i(1'b1),
    .rst_btn_i   (rst_btn),
    .rst_no      (rst_n)
  );

  // Synchronise the reset into the system and USB clock domains. The HyperRAM domain does not
  // exist here; its synchroniser is clocked from clk_sys so no flop sits on a constant clock, and
  // its output is unused.
  rst_sync u_rst_sync (
    .clk_sys_i  (clk_sys),
    .clk_usb_i  (clk_usb),
    .clk_hr_i   (clk_sys),
    .rst_ni     (rst_n),
    .rst_sys_no (rst_sys_n),
    .rst_usb_no (rst_usb_n),
    .rst_hr_no  (unused_rst_hr_n)
  );

  ///////////////////////////////////////////
  // Signals to and from the Sonata system //
  ///////////////////////////////////////////

  sonata_in_pins_t    in_from_pins;
  sonata_out_pins_t   out_to_pins;
  sonata_inout_pins_t inout_from_pins, inout_to_pins, inout_to_pins_en;

  // Enable CHERI by default.
  logic enable_cheri;
  assign enable_cheri = 1'b1;

  // GPIO inputs. On Sonata these carry the user switches, joystick, selector switches and the
  // microSD card detect; none exists on the KR260. The switch bits read as 0 (off), the microSD
  // detect bit reads as 1 (card absent; see doc/ip/gpio.md).
  logic [7:0] user_sw_n;
  logic [4:0] nav_sw_n;
  logic [2:0] sel_sw_n;
  logic       microsd_det;

  assign user_sw_n   = '0;
  assign nav_sw_n    = '0;
  assign sel_sw_n    = '0;
  assign microsd_det = 1'b1;

  // GPIO outputs above the eight user LEDs, and the output enables, go nowhere.
  logic [GPIO_IOS_WIDTH-9:0] unused_gp_o;
  logic [GPIO_IOS_WIDTH-1:0] unused_gp_o_en;

  // Outputs of sonata_system with no KR260 counterpart. The CHERI error indicators drive LEDs on
  // Sonata; they are not connected to any pin in phase 1.
  logic [8:0] cheri_err;
  logic       cheri_en;
  logic       rgbled_dout;

  logic lcd_copi, lcd_copi_en, lcd_sclk, lcd_cs, lcd_dc, lcd_rst, lcd_backlight;
  logic ethmac_copi, ethmac_sclk, ethmac_cs, ethmac_rst;

  logic usb_dp, usb_dp_en, usb_dn, usb_dn_en;
  logic usb_dp_pullup, usb_dn_pullup, usb_rx_enable;

  logic rs485_tx_enable, rs485_rx_enable;

  logic unused_cheri;
  logic unused_lcd;
  logic unused_ethmac;
  logic unused_usb;
  logic unused_rs485;

  assign unused_cheri  = ^{cheri_err, cheri_en, rgbled_dout};
  assign unused_lcd    = ^{lcd_copi, lcd_copi_en, lcd_sclk, lcd_cs, lcd_dc, lcd_rst,
                           lcd_backlight};
  assign unused_ethmac = ^{ethmac_copi, ethmac_sclk, ethmac_cs, ethmac_rst};
  assign unused_usb    = ^{usb_dp, usb_dp_en, usb_dn, usb_dn_en,
                           usb_dp_pullup, usb_dn_pullup, usb_rx_enable};
  assign unused_rs485  = ^{rs485_tx_enable, rs485_rx_enable};

  // HyperRAM pins of sonata_system. Nothing is connected to them on the KR260 and the SRAM model
  // does not drive them; they stay on internal wires as in top_verilator.
  wire [7:0] hyperram_dq;
  wire       hyperram_rwds;
  wire       hyperram_ckp;
  wire       hyperram_ckn;
  wire       hyperram_nrst;
  wire       hyperram_cs;

  logic unused_hyperram;
  assign unused_hyperram = ^{hyperram_ckp, hyperram_ckn, hyperram_nrst, hyperram_cs};

  sonata_system #(
    .CheriErrWidth   ( 9               ),
    .SRAMInitFile    ( SRAMInitFile    ),
    .SysClkFreq      ( SysClkFreq      ),
    .HyperRAMClkFreq ( HyperRAMClkFreq ),
    .HyperRAMSize    ( HyperRAMSize    )
  ) u_sonata_system (
    // Main system clock and reset
    .clk_sys_i      (clk_sys),
    .rst_sys_ni     (rst_sys_n),

    // USB device clock and reset
    .clk_usb_i      (clk_usb),
    .rst_usb_ni     (rst_usb_n),

    // HyperRAM clocks and reset (tied off, see above)
    .clk_hr_i       (clk_hr),
    .clk_hr90p_i    (clk_hr90p),
    .clk_hr3x_i     (clk_hr3x),
    .rst_hr_ni      (rst_hr_n),

    // GPIO
    .gp_i           ({
                      15'b0,
                      microsd_det, // MicroSD card insertion detection
                      sel_sw_n,    // Software selection switches
                      nav_sw_n,    // joystick
                      user_sw_n    // user switches
                    }),
    .gp_o           ({
                      unused_gp_o,
                      usrLed // User LEDs (8 bits)
                    }),
    .gp_o_en        (unused_gp_o_en),

    // Arduino Shield Analog(ue): no analogue inputs on the KR260
    .ard_an_di_i    ('0),
    .ard_an_p_i     ('0),
    .ard_an_n_i     ('0),

    // Non-pinmuxed spi devices: no LCD or Ethernet MAC on the KR260
    .lcd_copi_o              (lcd_copi),
    .lcd_copi_en_o           (lcd_copi_en),
    .lcd_cipo_i              (1'b0),
    .lcd_sclk_o              (lcd_sclk),
    .lcd_cs_o                (lcd_cs),
    .lcd_dc_o                (lcd_dc),
    .lcd_rst_o               (lcd_rst),
    .lcd_backlight_o         (lcd_backlight),

    .ethmac_copi_o           (ethmac_copi),
    .ethmac_cipo_i           (1'b0),
    .ethmac_sclk_o           (ethmac_sclk),
    .ethmac_cs_o             (ethmac_cs),
    .ethmac_rst_o            (ethmac_rst),
    .ethmac_irq_ni           (1'b1), // Active low, never asserted

    // CHERI signals
    .cheri_en_i     (enable_cheri),
    .cheri_err_o    (cheri_err),
    .cheri_en_o     (cheri_en),

    // Reception from USB host via transceiver: no transceiver on the KR260, idle levels
    .usb_dp_i         (1'b0),
    .usb_dn_i         (1'b0),
    .usb_rx_d_i       (1'b0),

    // Transmission to USB host via transceiver
    .usb_dp_o         (usb_dp),
    .usb_dp_en_o      (usb_dp_en),
    .usb_dn_o         (usb_dn),
    .usb_dn_en_o      (usb_dn_en),

    // Configuration and control of USB transceiver; VBUS is reported absent
    .usb_sense_i      (1'b0),
    .usb_dp_pullup_o  (usb_dp_pullup),
    .usb_dn_pullup_o  (usb_dn_pullup),
    .usb_rx_enable_o  (usb_rx_enable),

    // User JTAG
    .tck_i,
    .tms_i,
    .trst_ni(rst_n),
    .td_i,
    .td_o,

    .rgbled_dout_o(rgbled_dout),

    // HyperRAM
    .hyperram_dq,
    .hyperram_rwds,
    .hyperram_ckp,
    .hyperram_ckn,
    .hyperram_nrst,
    .hyperram_cs,

    .rs485_tx_enable_o(rs485_tx_enable),
    .rs485_rx_enable_o(rs485_rx_enable),

    .in_from_pins_i     (in_from_pins    ),
    .out_to_pins_o      (out_to_pins     ),
    .inout_from_pins_i  (inout_from_pins ),
    .inout_to_pins_o    (inout_to_pins   ),
    .inout_to_pins_en_o (inout_to_pins_en)
  );

  ////////////////////////////
  // Dedicated input/output //
  ////////////////////////////

  // Input pins. Only UART0 RX reaches a board pin; the other receivers see their idle level
  // (UART and RS-232/RS-485 idle high, SPI CIPO low).
  assign in_from_pins[IN_PIN_SER0_RX     ] = ser0_rx;
  assign in_from_pins[IN_PIN_SER1_RX     ] = 1'b1;
  assign in_from_pins[IN_PIN_RS232_RX    ] = 1'b1;
  assign in_from_pins[IN_PIN_RS485_RX    ] = 1'b1;
  assign in_from_pins[IN_PIN_MB3         ] = 1'b0;
  assign in_from_pins[IN_PIN_MB8         ] = 1'b1;
  assign in_from_pins[IN_PIN_APPSPI_D1   ] = 1'b0;
  assign in_from_pins[IN_PIN_MICROSD_DAT0] = 1'b0;

  // Output pins. Only UART0 TX reaches a board pin.
  assign ser0_tx = out_to_pins[OUT_PIN_SER0_TX];

  logic unused_out_to_pins;
  assign unused_out_to_pins = ^{out_to_pins[OUT_PIN_SER1_TX     ],
                                out_to_pins[OUT_PIN_RS232_TX    ],
                                out_to_pins[OUT_PIN_RS485_TX    ],
                                out_to_pins[OUT_PIN_MB1         ],
                                out_to_pins[OUT_PIN_MB2         ],
                                out_to_pins[OUT_PIN_MB4         ],
                                out_to_pins[OUT_PIN_MB7         ],
                                out_to_pins[OUT_PIN_MB10        ],
                                out_to_pins[OUT_PIN_APPSPI_D0   ],
                                out_to_pins[OUT_PIN_APPSPI_CLK  ],
                                out_to_pins[OUT_PIN_APPSPI_CS   ],
                                out_to_pins[OUT_PIN_MICROSD_CMD ],
                                out_to_pins[OUT_PIN_MICROSD_CLK ],
                                out_to_pins[OUT_PIN_MICROSD_DAT3]};

  /////////////////////////
  // Pinmuxed inout pins //
  /////////////////////////

  // Sonata has INOUT_PIN_NUM (70) pinmuxed pins; the KR260 has board pins for 44 of them: the
  // 28 Raspberry Pi header signals, pmod0 and pmod1. Those go through one padring, whose
  // position i carries the Sonata pinmux index KrInoutIdx[i]. The table is in the order of the
  // inout_pins_io concatenation below read from its last (least significant) element upwards.
  localparam int unsigned KrInoutNum = 44;

  localparam int unsigned KrInoutIdx[KrInoutNum] = '{
    // Raspberry Pi header: positions 0-27
    INOUT_PIN_RPH_G0,
    INOUT_PIN_RPH_G1,
    INOUT_PIN_RPH_G2_SDA,
    INOUT_PIN_RPH_G3_SCL,
    INOUT_PIN_RPH_G4,
    INOUT_PIN_RPH_G5,
    INOUT_PIN_RPH_G6,
    INOUT_PIN_RPH_G7,
    INOUT_PIN_RPH_G8,
    INOUT_PIN_RPH_G9,
    INOUT_PIN_RPH_G10,
    INOUT_PIN_RPH_G11,
    INOUT_PIN_RPH_G12,
    INOUT_PIN_RPH_G13,
    INOUT_PIN_RPH_TXD0,
    INOUT_PIN_RPH_RXD0,
    INOUT_PIN_RPH_G16,
    INOUT_PIN_RPH_G17,
    INOUT_PIN_RPH_G18,
    INOUT_PIN_RPH_G19,
    INOUT_PIN_RPH_G20,
    INOUT_PIN_RPH_G21,
    INOUT_PIN_RPH_G22,
    INOUT_PIN_RPH_G23,
    INOUT_PIN_RPH_G24,
    INOUT_PIN_RPH_G25,
    INOUT_PIN_RPH_G26,
    INOUT_PIN_RPH_G27,
    // pmod0[7:0] (KR260 PMOD2): positions 28-35
    INOUT_PIN_PMOD0_1,
    INOUT_PIN_PMOD0_2,
    INOUT_PIN_PMOD0_3,
    INOUT_PIN_PMOD0_4,
    INOUT_PIN_PMOD0_7,
    INOUT_PIN_PMOD0_8,
    INOUT_PIN_PMOD0_9,
    INOUT_PIN_PMOD0_10,
    // pmod1[7:0] (KR260 PMOD3): positions 36-43
    INOUT_PIN_PMOD1_1,
    INOUT_PIN_PMOD1_2,
    INOUT_PIN_PMOD1_3,
    INOUT_PIN_PMOD1_4,
    INOUT_PIN_PMOD1_7,
    INOUT_PIN_PMOD1_8,
    INOUT_PIN_PMOD1_9,
    INOUT_PIN_PMOD1_10
  };

  logic [KrInoutNum-1:0] kr_inout_to_pins;
  logic [KrInoutNum-1:0] kr_inout_to_pins_en;
  logic [KrInoutNum-1:0] kr_inout_from_pins;

  for (genvar i = 0; i < KrInoutNum; i++) begin : gen_kr_inout
    assign kr_inout_to_pins[i]            = inout_to_pins[KrInoutIdx[i]];
    assign kr_inout_to_pins_en[i]         = inout_to_pins_en[KrInoutIdx[i]];
    assign inout_from_pins[KrInoutIdx[i]] = kr_inout_from_pins[i];
  end : gen_kr_inout

  padring #(
    .InoutNumber(KrInoutNum)
  ) u_pinmux_padring (
    .inout_to_pins_i   (kr_inout_to_pins   ),
    .inout_to_pins_en_i(kr_inout_to_pins_en),
    .inout_from_pins_o (kr_inout_from_pins ),
    .inout_pins_io({
      pmod1,
      pmod0,
      rph_g27,
      rph_g26,
      rph_g25,
      rph_g24,
      rph_g23,
      rph_g22,
      rph_g21_sclk,
      rph_g20_copi,
      rph_g19_cipo,
      rph_g18,
      rph_g17,
      rph_g16_ce2,
      rph_rxd0,
      rph_txd0,
      rph_g13,
      rph_g12,
      rph_g11_sclk,
      rph_g10_copi,
      rph_g9_cipo,
      rph_g8_ce0,
      rph_g7_ce1,
      rph_g6,
      rph_g5,
      rph_g4,
      rph_g3_scl,
      rph_g2_sda,
      rph_g1,
      rph_g0
    })
  );

  // The 26 pinmux indices with no KR260 board pin. The I2C lines (QWIIC0, QWIIC1 and the mikroBUS
  // I2C bus) read as 1 so the I2C blocks see an idle, pulled-up bus; the Arduino shield and PMODC
  // pins read as 0. Whatever the pinmux drives towards them is dropped.
  assign inout_from_pins[INOUT_PIN_PMODC_1  ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_PMODC_2  ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_PMODC_3  ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_PMODC_4  ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_PMODC_5  ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_PMODC_6  ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_SCL0     ] = 1'b1;
  assign inout_from_pins[INOUT_PIN_SDA0     ] = 1'b1;
  assign inout_from_pins[INOUT_PIN_SCL1     ] = 1'b1;
  assign inout_from_pins[INOUT_PIN_SDA1     ] = 1'b1;
  assign inout_from_pins[INOUT_PIN_MB5      ] = 1'b1;
  assign inout_from_pins[INOUT_PIN_MB6      ] = 1'b1;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO0 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO1 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO2 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO3 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO4 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO5 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO6 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO7 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO8 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO9 ] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO10] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO11] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO12] = 1'b0;
  assign inout_from_pins[INOUT_PIN_AH_TMPIO13] = 1'b0;

  logic unused_inout_to_pins;
  assign unused_inout_to_pins = ^{
    inout_to_pins[INOUT_PIN_PMODC_1   ], inout_to_pins_en[INOUT_PIN_PMODC_1   ],
    inout_to_pins[INOUT_PIN_PMODC_2   ], inout_to_pins_en[INOUT_PIN_PMODC_2   ],
    inout_to_pins[INOUT_PIN_PMODC_3   ], inout_to_pins_en[INOUT_PIN_PMODC_3   ],
    inout_to_pins[INOUT_PIN_PMODC_4   ], inout_to_pins_en[INOUT_PIN_PMODC_4   ],
    inout_to_pins[INOUT_PIN_PMODC_5   ], inout_to_pins_en[INOUT_PIN_PMODC_5   ],
    inout_to_pins[INOUT_PIN_PMODC_6   ], inout_to_pins_en[INOUT_PIN_PMODC_6   ],
    inout_to_pins[INOUT_PIN_SCL0      ], inout_to_pins_en[INOUT_PIN_SCL0      ],
    inout_to_pins[INOUT_PIN_SDA0      ], inout_to_pins_en[INOUT_PIN_SDA0      ],
    inout_to_pins[INOUT_PIN_SCL1      ], inout_to_pins_en[INOUT_PIN_SCL1      ],
    inout_to_pins[INOUT_PIN_SDA1      ], inout_to_pins_en[INOUT_PIN_SDA1      ],
    inout_to_pins[INOUT_PIN_MB5       ], inout_to_pins_en[INOUT_PIN_MB5       ],
    inout_to_pins[INOUT_PIN_MB6       ], inout_to_pins_en[INOUT_PIN_MB6       ],
    inout_to_pins[INOUT_PIN_AH_TMPIO0 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO0 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO1 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO1 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO2 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO2 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO3 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO3 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO4 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO4 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO5 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO5 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO6 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO6 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO7 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO7 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO8 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO8 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO9 ], inout_to_pins_en[INOUT_PIN_AH_TMPIO9 ],
    inout_to_pins[INOUT_PIN_AH_TMPIO10], inout_to_pins_en[INOUT_PIN_AH_TMPIO10],
    inout_to_pins[INOUT_PIN_AH_TMPIO11], inout_to_pins_en[INOUT_PIN_AH_TMPIO11],
    inout_to_pins[INOUT_PIN_AH_TMPIO12], inout_to_pins_en[INOUT_PIN_AH_TMPIO12],
    inout_to_pins[INOUT_PIN_AH_TMPIO13], inout_to_pins_en[INOUT_PIN_AH_TMPIO13]
  };
endmodule : top_kr260
