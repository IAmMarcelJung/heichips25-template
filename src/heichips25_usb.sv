// SPDX-FileCopyrightText: © 2025 Marcel Jung
// SPDX-License-Identifier: Apache-2.0

// Adapted from the Tiny Tapeout template

`default_nettype none

module heichips25_usb (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // TODO: set actual value
    localparam FABRIC_CLOCK_FREQUENCY = 48_000_000;

    localparam USB_CLK_PIN = 0;
    localparam USB_DP_PIN = 1;
    localparam USB_DN_PIN = 2;
    localparam USB_DP_PU_PIN = 3;
 
    // The "pads" have to be used because of the port limitation
    // This would not work in an actual TinyTapeout
    localparam USB_FROM_EFPGA_VALID_PIN = 4;
    localparam USB_FROM_EFPGA_READY_PIN = 5;
    localparam USB_TO_EFPGA_VALID_PIN = 6;
    localparam USB_TO_EFPGA_READY_PIN = 7;
 
    // Don't use JTAG for now due to pin limitation
    // localparam JTAG_TMS_PIN = 4;
    // localparam JTAG_TCK_PIN = 5;
    // localparam JTAG_TDI_PIN = 6;
    // localparam JTAG_TDO = 7;

    localparam DISABLE_OUTPUT = 1'b1;
    localparam ENABLE_OUTPUT = 1'b0;
    

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in[USB_DP_PU_PIN], uio_in[USB_FROM_EFPGA_READY_PIN], uio_in[USB_TO_EFPGA_VALID_PIN] };

    // wire       clk_usb;
    wire [7:0] from_efpga_data;
    wire       from_efpga_valid;
    wire       from_efpga_ready;
    wire [7:0] to_efpga_data;
    wire       to_efpga_valid;
    wire       to_efpga_ready;
    
    // USB signals
    wire dp_rx;  // USB+ RX
    wire dp_tx;  // USB+ TX
    wire dn_rx;  // USB- RX
    wire dn_tx;  // USB- TX
    wire dp_pu;  // USB 1.5kOhm Pullup EN
    wire tx_en;

    // External clock (probably not a good idea to route this through the fabric)
    // assign clk_usb = uio_in[USB_CLK_PIN];
    assign uio_oe[USB_CLK_PIN] = DISABLE_OUTPUT;
    assign uio_out[USB_CLK_PIN] = 1'b0; // unused

    // USB Data pins (bidirectional)
    assign dn_rx = uio_in[USB_DN_PIN];
    assign uio_out[USB_DN_PIN] = dn_tx;
    assign uio_oe[USB_DN_PIN] = !tx_en;

    assign dp_rx = uio_in[USB_DP_PIN];
    assign uio_out[USB_DP_PIN] = dp_tx;
    assign uio_oe[USB_DP_PIN] = !tx_en;

    // DP pull-up pin
    assign uio_out[USB_DP_PU_PIN] = 1'b1;
    assign uio_oe[USB_DP_PU_PIN] = !dp_pu;

    // Data connections
    assign from_efpga_data = ui_in;
    assign uo_out = to_efpga_data;

    assign from_efpga_valid = uio_in[USB_FROM_EFPGA_VALID_PIN];
    assign uio_out[USB_FROM_EFPGA_VALID_PIN] = 1'b0; // Unused
    assign uio_oe[USB_FROM_EFPGA_VALID_PIN] = DISABLE_OUTPUT;

    assign uio_out[USB_FROM_EFPGA_READY_PIN] = from_efpga_ready;
    assign uio_oe[USB_FROM_EFPGA_READY_PIN] = ENABLE_OUTPUT;

    assign uio_out[USB_TO_EFPGA_VALID_PIN] = to_efpga_valid;
    assign uio_oe[USB_TO_EFPGA_VALID_PIN] = ENABLE_OUTPUT;

    assign to_efpga_ready = uio_in[USB_TO_EFPGA_READY_PIN];
    assign uio_out[USB_TO_EFPGA_READY_PIN] = 1'b0; // Unused
    assign uio_oe[USB_TO_EFPGA_READY_PIN] = DISABLE_OUTPUT;

    controller #(
        .USE_SYSTEM_CLK      (1),
        .SYSTEM_CLK_FREQUENCY(FABRIC_CLOCK_FREQUENCY / 1_000_000),
        .MAX_PACKETSIZE      (32)
    ) controller_inst (
        .clk_system_i        (clk),
        .reset_n_i           (rst_n),
        .clk_usb_i           (clk),
        .dp_tx_o             (dp_tx),
        .dp_rx_i             (dp_rx),
        .dn_tx_o             (dn_tx),
        .dn_rx_i             (dn_rx),
        .dp_pu_o             (dp_pu),
        .tx_en_o             (tx_en),
        // verilator lint_off PINCONNECTEMPTY
        .tms_o               (),
        .tck_o               (),
        .tdi_o               (),
        .tdo_i               (),
        .srst_o              (),
        .trst_o              (),
        // verilator lint_on PINCONNECTEMPTY
        //TODO: think about if at least the usb_check_o should be used
`ifdef DEBUG
        .usb_check_o         (),
        .jtag_led            (),
        .ctr                 (),
`endif
        // verilator lint_off PINCONNECTEMPTY
        .efpga_write_data_o  (),
        .efpga_write_strobe_o(),
        // verilator lint_on PINCONNECTEMPTY
        .from_efpga_data_i   (from_efpga_data),
        .from_efpga_valid_i  (from_efpga_valid),
        .from_efpga_ready_o  (from_efpga_ready),
        .to_efpga_data_o     (to_efpga_data),
        .to_efpga_valid_o    (to_efpga_valid),
        .to_efpga_ready_i    (to_efpga_ready)
    );

endmodule
