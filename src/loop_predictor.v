`default_nettype none
//=============================================================================
// loop_predictor.v -- small trip-count-learning loop predictor
//
// 8 entries (indexed by low PC bits). Each entry learns how many taken
// iterations a loop branch runs before it is finally not-taken (the "trip
// count"), and once that trip count has repeated >=2 times in a row,
// predicts "taken" for iterations < trip and "not-taken" on the exiting
// iteration -- something a plain saturating counter or short-history TAGE
// table handles poorly (it just tracks "mostly taken").
//
// Only participates in the final prediction when conf_ok is asserted;
// otherwise the caller should fall back to TAGE/bimodal.
//=============================================================================
module loop_predictor #(
    parameter ADDR_W = 3,   // 8 entries
    parameter TAG_W  = 4,
    parameter CNT_W  = 5,   // trip counts up to 31 iterations
    parameter PC_BITS = 7
) (
    input  wire               clk,
    input  wire                rst_n,

    input  wire [PC_BITS-1:0] pc,

    output wire                 hit,
    output wire                 conf_ok,
    output wire                 pred_taken,

    input  wire                 train_en,
    input  wire                 actual_taken,
    output wire                 clearing_o
);

    localparam DEPTH = (1 << ADDR_W);

    reg [TAG_W-1:0] tag_mem   [0:DEPTH-1];
    reg [CNT_W-1:0] count_mem [0:DEPTH-1]; // iterations seen so far this pass
    reg [CNT_W-1:0] trip_mem  [0:DEPTH-1]; // learned trip count
    reg [1:0]       conf_mem  [0:DEPTH-1];
    reg             valid_mem [0:DEPTH-1];

    wire [ADDR_W-1:0] index = pc[ADDR_W-1:0];
    wire [TAG_W-1:0]  tag   = pc[PC_BITS-1 -: TAG_W];

    assign hit        = valid_mem[index] && (tag_mem[index] == tag);
    assign conf_ok     = hit && (conf_mem[index] >= 2'd2);
    assign pred_taken = conf_ok ? (count_mem[index] < trip_mem[index]) : 1'b0;

    integer i;
    reg [ADDR_W:0] clear_ptr;
    reg            clearing;
    assign clearing_o = clearing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_ptr <= {(ADDR_W+1){1'b0}};
            clearing  <= 1'b1;
        end else if (clearing) begin
            valid_mem[clear_ptr[ADDR_W-1:0]] <= 1'b0;
            conf_mem[clear_ptr[ADDR_W-1:0]]  <= 2'b00;
            count_mem[clear_ptr[ADDR_W-1:0]] <= {CNT_W{1'b0}};
            trip_mem[clear_ptr[ADDR_W-1:0]]  <= {CNT_W{1'b0}};
            clear_ptr <= clear_ptr + 1'b1;
            if (clear_ptr[ADDR_W-1:0] == {ADDR_W{1'b1}})
                clearing <= 1'b0;
        end else if (train_en) begin
            if (!hit) begin
                // allocate a fresh entry for this PC
                tag_mem[index]   <= tag;
                valid_mem[index] <= 1'b1;
                conf_mem[index]  <= 2'b00;
                trip_mem[index]  <= {CNT_W{1'b0}};
                count_mem[index] <= actual_taken ? {{(CNT_W-1){1'b0}}, 1'b1} : {CNT_W{1'b0}};
            end else if (actual_taken) begin
                if (count_mem[index] != {CNT_W{1'b1}})
                    count_mem[index] <= count_mem[index] + 1'b1;
            end else begin
                // branch fell through -- end of this loop pass
                if (count_mem[index] == trip_mem[index]) begin
                    if (conf_mem[index] != 2'b11)
                        conf_mem[index] <= conf_mem[index] + 1'b1;
                end else begin
                    trip_mem[index] <= count_mem[index];
                    conf_mem[index] <= 2'b00;
                end
                count_mem[index] <= {CNT_W{1'b0}};
            end
        end
    end

endmodule
