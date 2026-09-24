`default_nettype none
//=============================================================================
// tt_um_sphatika11_minitage.v -- Tiny Tapeout top level (1x1-SAFE variant, A)
//
// ui_in[6:0]  = pc[6:0]
// ui_in[7]    = actual_taken
// uio_in[0]   = valid
// uio_in[1]   = readback_mode
// uio_in[4:2] = stat_reg_addr[2:0]  (8 registers, see docs/INTERFACE.md)
// uio_in[7:5] = unused
//=============================================================================
module tt_um_sphatika11_minitage (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire        ena,
    input  wire        clk,
    input  wire        rst_n
);

    wire        valid          = uio_in[0];
    wire        readback_mode  = uio_in[1];
    wire [2:0]  stat_reg_addr  = uio_in[4:2];

    wire [6:0]  pc             = ui_in[6:0];
    wire        actual_taken   = ui_in[7];

    predictor_core #(.PC_BITS(7)) u_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .valid         (valid && ena),
        .pc            (pc),
        .actual_taken  (actual_taken),
        .readback_mode (readback_mode),
        .stat_reg_addr (stat_reg_addr),
        .uo_out        (uo_out)
    );

    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    wire _unused = &{ena, 1'b0};

endmodule
