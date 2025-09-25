module testbench (
    input clk,
    input rst_n,
    input ena,
    input [7:0] ui_in,
    input [7:0] uio_in,
    output [7:0] uo_out,
    output [7:0] uio_out,
    output [7:0] uio_oe,
    output [7:0] uo_out_project_0,
    output [7:0] uio_out_project_0,
    output [7:0] uio_oe_project_0,
    output [7:0] uo_out_project_1,
    output [7:0] uio_out_project_1,
    output [7:0] uio_oe_project_1
);

    heichips25_tiny_wrapper heichips25_tiny_wrapper_i (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    heichips25_ppwm ppwm_i (
        .clk(clk),
        .rst_n(rst_n),
        .ena(1'b1),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out_project_0),
        .uio_out(uio_out_project_0),
        .uio_oe(uio_oe_project_0)
    );

    heichips25_falu falu_i (
        .clk(clk),
        .rst_n(rst_n),
        .ena(1'b1),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out_project_1),
        .uio_out(uio_out_project_1),
        .uio_oe(uio_oe_project_1)
    );
endmodule
