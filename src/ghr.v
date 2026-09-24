`default_nettype none
//=============================================================================
// ghr.v -- Global History Register
//
// Simple shift register that records the outcome of every trained branch.
// Bit [0] is always the MOST RECENT outcome (shifted in on the MSB side of
// the internal register, exposed LSB-first for convenience of the hashing
// functions in tage_table.v).
//=============================================================================
module ghr #(
    parameter WIDTH = 16
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             shift_en,   // pulse once per trained branch
    input  wire             outcome_in, // 1 = taken, 0 = not-taken
    output wire [WIDTH-1:0] ghr_out
);

    reg [WIDTH-1:0] history;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            history <= {WIDTH{1'b0}};
        else if (shift_en)
            history <= {history[WIDTH-2:0], outcome_in};
    end

    assign ghr_out = history;

endmodule
