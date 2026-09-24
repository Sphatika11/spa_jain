`default_nettype none
//=============================================================================
// bimodal.v -- Base predictor (fallback when no TAGE table matches)
//
// Classic 2-bit saturating-counter PC-indexed table. This is the predictor
// TAGE always has as a backstop, so it never "misses" a prediction, only
// disagrees with the tagged tables.
//
// On rst_n deassertion the table is swept and initialised to the weakly-
// not-taken state (2'b01) over DEPTH cycles ("clearing" phase). Do not
// trust predictions/reads during that window -- it lasts DEPTH clocks.
//=============================================================================
module bimodal #(
    parameter ADDR_W = 5,   // 2^5 = 32 entries
    parameter CTR_W  = 2    // 2-bit saturating counter
) (
    input  wire              clk,
    input  wire              rst_n,

    input  wire [ADDR_W-1:0] pc_index,
    output wire               pred_taken,

    input  wire               update_en,
    input  wire [ADDR_W-1:0]  update_index,
    input  wire               actual_taken,

    output wire                clearing_o
);

    localparam DEPTH = (1 << ADDR_W);

    reg [CTR_W-1:0] table_mem [0:DEPTH-1];

    reg [ADDR_W:0] clear_ptr;
    reg            clearing;

    assign clearing_o = clearing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_ptr <= {(ADDR_W+1){1'b0}};
            clearing  <= 1'b1;
        end else if (clearing) begin
            table_mem[clear_ptr[ADDR_W-1:0]] <= {1'b0, 1'b1}; // weakly not-taken
            clear_ptr <= clear_ptr + 1'b1;
            if (clear_ptr[ADDR_W-1:0] == {ADDR_W{1'b1}})
                clearing <= 1'b0;
        end else if (update_en) begin
            if (actual_taken) begin
                if (table_mem[update_index] != {CTR_W{1'b1}})
                    table_mem[update_index] <= table_mem[update_index] + 1'b1;
            end else begin
                if (table_mem[update_index] != {CTR_W{1'b0}})
                    table_mem[update_index] <= table_mem[update_index] - 1'b1;
            end
        end
    end

    assign pred_taken = table_mem[pc_index][CTR_W-1];

endmodule
