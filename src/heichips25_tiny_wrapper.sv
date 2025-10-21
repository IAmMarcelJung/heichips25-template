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

    // Bit assignments for the projects. Project 0 uses bits 4-7,
    // Project 1 uses bits 0-3.
    localparam PROJECT_0_HIGH = 7;
    localparam PROJECT_0_LOW  = 4;
    localparam PROJECT_1_HIGH = 3;
    localparam PROJECT_1_LOW  = 0;

    wire [7:0] uo_out_project_0;
    wire [7:0] uio_out_project_0;
    wire [7:0] uio_oe_project_0;

    wire [7:0] uo_out_project_1;
    wire [7:0] uio_out_project_1;
    wire [7:0] uio_oe_project_1;

    assign uo_out = {uo_out_project_0[PROJECT_0_HIGH:PROJECT_0_LOW], uo_out_project_1[PROJECT_1_HIGH:PROJECT_1_LOW]};
    assign uio_out = {uio_out_project_0[PROJECT_0_HIGH:PROJECT_0_LOW], uio_out_project_1[PROJECT_1_HIGH:PROJECT_1_LOW]};
    assign uio_oe = {uio_oe_project_0[PROJECT_0_HIGH:PROJECT_0_LOW], uio_oe_project_1[PROJECT_1_HIGH:PROJECT_1_LOW]};

    // Instantiation of the PPWM project
    heichips25_ppwm ppwm_i (
        .ui_in(ui_in),
        .uo_out(uo_out_project_0),
        .uio_in(uio_in),
        .uio_out(uio_out_project_0),
        .uio_oe(uio_oe_project_0),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Instantiation of the FALU project
    heichips25_falu falu_i (
        .ui_in(ui_in),
        .uo_out(uo_out_project_1),
        .uio_in(uio_in),
        .uio_out(uio_out_project_1),
        .uio_oe(uio_oe_project_1),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

endmodule
