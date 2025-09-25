// SPDX-FileCopyrightText: © 2025 Marcel Jung
// SPDX-License-Identifier: Apache-2.0

// Adapted from the Tiny Tapeout template

`default_nettype none

module heichips25_tiny_wrapper (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // Sets which project will be active
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire [7:0] uo_out_project_0;
    wire [7:0] uio_out_project_0;
    wire [7:0] uio_oe_project_0;
    wire rst_n_project_0;
    wire ena_project_0;

    wire [7:0] uo_out_project_1;
    wire [7:0] uio_out_project_1;
    wire [7:0] uio_oe_project_1;
    wire rst_n_project_1;
    wire ena_project_1;


    // If ena = 0, the PPWM project will be active and if ena = 1, the SDR project will be active
    assign ena_project_1 = ena;
    assign ena_project_0 = ~ena_project_1; // Only one project is enabled at the same time

    assign uo_out = ena_project_0 ? uo_out_project_0 : uo_out_project_1;
    assign uio_out = ena_project_0 ? uio_out_project_0 : uio_out_project_1;
    assign uio_oe = ena_project_0 ? uio_oe_project_0 : uio_oe_project_1;

    // Reset the project that is not enabled. Also reset if the external
    // reset is triggered.
    assign rst_n_project_0 = ena_project_0 & rst_n;
    assign rst_n_project_1 = ena_project_1 & rst_n;

    // Instantiation of the PPWM project
    heichips25_ppwm ppwm_i (
        .ui_in(ui_in),
        .uo_out(uo_out_project_0),
        .uio_in(uio_in),
        .uio_out(uio_out_project_0),
        .uio_oe(uio_oe_project_0),
        .ena(1'b1), // The internal enable signal is always 1
        .clk(clk),
        .rst_n(rst_n_project_0)
    );

    // Instantiation of the FALU project
    heichips25_falu falu_i (
        .ui_in(ui_in),
        .uo_out(uo_out_project_1),
        .uio_in(uio_in),
        .uio_out(uio_out_project_1),
        .uio_oe(uio_oe_project_1),
        .ena(1'b1), // The internal enable signal is always 1
        .clk(clk),
        .rst_n(rst_n_project_1)
    );

endmodule
