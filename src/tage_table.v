`default_nettype none
//=============================================================================
// tage_table.v -- One tagged, geometric-history TAGE component table
//
// Each entry: {tag, 3-bit signed-ish saturating counter, useful bit, valid}
//
// Indexing / tagging use a cheap XOR fold of PC bits with GHR bits rather
// than a real CRC/H3 hash -- adequate for a tiny demo table and cheap in
// area. Requires HIST_LEN >= ADDR_W and HIST_LEN >= TAG_W (true for both
// instantiations used in predictor_core.v).
//
// Same reset-sweep behaviour as bimodal.v: table is invalid for DEPTH
// cycles after rst_n deasserts.
//=============================================================================
module tage_table #(
    parameter ADDR_W   = 4,   // 2^4 = 16 entries
    parameter TAG_W    = 4,
    parameter CTR_W    = 3,
    parameter HIST_LEN = 8,   // bits of GHR folded into index/tag
    parameter PC_BITS  = 7
) (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire [PC_BITS-1:0]   pc,
    input  wire [HIST_LEN-1:0]  ghr,

    output wire                 hit,
    output wire                 pred_taken,
    output wire                 useful,

    // training (all qualified by train_en, evaluated against the SAME
    // pc/ghr presented on the read side this cycle)
    input  wire                 train_en,
    input  wire                 is_alloc,        // allocate fresh entry here
    input  wire                 actual_taken,
    input  wire                 update_useful_set,
    input  wire                 update_useful_clr,
    input  wire                 reset_useful_all, // periodic global aging
    output wire                 clearing_o
);

    localparam DEPTH = (1 << ADDR_W);

    reg [TAG_W-1:0] tag_mem   [0:DEPTH-1];
    reg [CTR_W-1:0] ctr_mem   [0:DEPTH-1];
    reg             useful_mem[0:DEPTH-1];
    reg             valid_mem [0:DEPTH-1];

    // ---- index / tag hash (cheap XOR fold) ----------------------------
    wire [ADDR_W-1:0] index_hash = pc[ADDR_W-1:0] ^ ghr[ADDR_W-1:0];
    wire [TAG_W-1:0]  tag_hash   = pc[PC_BITS-1 -: TAG_W] ^ ghr[HIST_LEN-1 -: TAG_W];

    wire [ADDR_W-1:0] rd_index = index_hash;

    assign hit        = valid_mem[rd_index] && (tag_mem[rd_index] == tag_hash);
    assign pred_taken = ctr_mem[rd_index][CTR_W-1];
    assign useful      = useful_mem[rd_index];

    integer i;
    reg [ADDR_W:0] clear_ptr;
    reg            clearing;
    assign clearing_o = clearing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_ptr <= {(ADDR_W+1){1'b0}};
            clearing  <= 1'b1;
        end else if (clearing) begin
            valid_mem[clear_ptr[ADDR_W-1:0]]  <= 1'b0;
            useful_mem[clear_ptr[ADDR_W-1:0]] <= 1'b0;
            ctr_mem[clear_ptr[ADDR_W-1:0]]    <= {1'b0, {(CTR_W-1){1'b1}}}; // weak middle
            clear_ptr <= clear_ptr + 1'b1;
            if (clear_ptr[ADDR_W-1:0] == {ADDR_W{1'b1}})
                clearing <= 1'b0;
        end else if (reset_useful_all) begin
            for (i = 0; i < DEPTH; i = i + 1)
                useful_mem[i] <= 1'b0;
        end else if (train_en) begin
            if (is_alloc) begin
                tag_mem[rd_index]    <= tag_hash;
                valid_mem[rd_index]  <= 1'b1;
                useful_mem[rd_index] <= 1'b0;
                ctr_mem[rd_index]    <= actual_taken ? {1'b1, {(CTR_W-1){1'b0}}}
                                                       : {1'b0, {(CTR_W-1){1'b1}}};
            end else begin
                if (actual_taken) begin
                    if (ctr_mem[rd_index] != {CTR_W{1'b1}})
                        ctr_mem[rd_index] <= ctr_mem[rd_index] + 1'b1;
                end else begin
                    if (ctr_mem[rd_index] != {CTR_W{1'b0}})
                        ctr_mem[rd_index] <= ctr_mem[rd_index] - 1'b1;
                end
                if (update_useful_set) useful_mem[rd_index] <= 1'b1;
                if (update_useful_clr) useful_mem[rd_index] <= 1'b0;
            end
        end
    end

endmodule
