`default_nettype none
//=============================================================================
// predictor_core.v -- Mini-TAGE branch predictor core (1x1-SAFE variant, A)
//
// bimodal base + ONE tagged TAGE table + loop predictor. This is the
// recommended fit for a single Tiny Tapeout tile: synthesizes (generic
// techmap, see ../../README.md) to ~800 cells against a ~1000-gate budget,
// leaving real margin for place-and-route overhead. Variant B keeps both
// TAGE tables but sits right at ~1070 cells -- riskier for a first tapeout.
//
// Priority: loop (if confident) > T1 (if tag hit) > bimodal (base).
// Allocation: on a misprediction where the loop predictor wasn't driving,
// try to allocate a fresh T1 entry (protecting it if its useful bit is set,
// aging that bit instead of evicting).
//=============================================================================
module predictor_core #(
    parameter PC_BITS = 7
) (
    input  wire              clk,
    input  wire              rst_n,

    input  wire               valid,
    input  wire [PC_BITS-1:0] pc,
    input  wire               actual_taken,

    input  wire               readback_mode,
    input  wire [2:0]         stat_reg_addr,

    output wire [7:0]         uo_out
);

    // ---------------------------------------------------------------
    // Global history -- 8 bits
    // ---------------------------------------------------------------
    localparam GHR_W = 8;
    wire [GHR_W-1:0] ghr;

    ghr #(.WIDTH(GHR_W)) u_ghr (
        .clk       (clk),
        .rst_n     (rst_n),
        .shift_en  (valid),
        .outcome_in(actual_taken),
        .ghr_out   (ghr)
    );

    // ---------------------------------------------------------------
    // Base predictor (bimodal) -- 8 entries
    // ---------------------------------------------------------------
    localparam BIM_ADDR_W = 3;
    wire bimodal_pred;

    bimodal #(.ADDR_W(BIM_ADDR_W), .CTR_W(2)) u_bimodal (
        .clk          (clk),
        .rst_n        (rst_n),
        .pc_index     (pc[BIM_ADDR_W-1:0]),
        .pred_taken   (bimodal_pred),
        .update_en    (valid),
        .update_index (pc[BIM_ADDR_W-1:0]),
        .actual_taken (actual_taken),
        .clearing_o   ()
    );

    // ---------------------------------------------------------------
    // TAGE table -- 4 entries, 3-bit tag, history=4. (Tried giving this
    // table the area saved by dropping T2 -- 8 entries/4-bit tag/hist=6 --
    // but that measured back up to ~1050 cells, right back at the risky
    // line. Keeping it this small is what actually measures safe below.)
    // ---------------------------------------------------------------
    localparam T1_ADDR_W   = 2;
    localparam T1_TAG_W    = 3;
    localparam T1_HIST_LEN = 4;

    wire t1_hit, t1_pred, t1_useful;
    reg  t1_train_en, t1_is_alloc, t1_uset, t1_uclr, t1_rst_useful;

    tage_table #(
        .ADDR_W(T1_ADDR_W), .TAG_W(T1_TAG_W), .CTR_W(2),
        .HIST_LEN(T1_HIST_LEN), .PC_BITS(PC_BITS)
    ) u_t1 (
        .clk(clk), .rst_n(rst_n),
        .pc(pc), .ghr(ghr[T1_HIST_LEN-1:0]),
        .hit(t1_hit), .pred_taken(t1_pred), .useful(t1_useful),
        .train_en(t1_train_en), .is_alloc(t1_is_alloc), .actual_taken(actual_taken),
        .update_useful_set(t1_uset), .update_useful_clr(t1_uclr),
        .reset_useful_all(t1_rst_useful),
        .clearing_o()
    );

    // ---------------------------------------------------------------
    // Loop predictor -- 2 entries, trip counts up to 7
    // ---------------------------------------------------------------
    wire loop_hit, loop_conf_ok, loop_pred;

    loop_predictor #(.ADDR_W(1), .TAG_W(3), .CNT_W(3), .PC_BITS(PC_BITS)) u_loop (
        .clk(clk), .rst_n(rst_n),
        .pc(pc),
        .hit(loop_hit), .conf_ok(loop_conf_ok), .pred_taken(loop_pred),
        .train_en(valid), .actual_taken(actual_taken),
        .clearing_o()
    );

    // ---------------------------------------------------------------
    // Priority mux: LOOP(conf) > T1(hit) > BIMODAL
    // provider: 2'b11=loop 2'b01=T1 2'b00=bimodal (2'b10 unused, T2 gone)
    // ---------------------------------------------------------------
    wire [1:0] provider = loop_conf_ok ? 2'b11 :
                           t1_hit      ? 2'b01 :
                                          2'b00;

    wire final_pred = loop_conf_ok ? loop_pred :
                       t1_hit      ? t1_pred   :
                                      bimodal_pred;

    wire misp = valid && (final_pred != actual_taken);

    // ---------------------------------------------------------------
    // Allocation policy
    // ---------------------------------------------------------------
    wire need_alloc = valid && !loop_conf_ok && misp && !t1_hit;

    always @(*) begin
        t1_train_en   = valid && (t1_hit || need_alloc);
        t1_is_alloc   = need_alloc && !t1_useful;
        t1_rst_useful = need_alloc &&  t1_useful;
        t1_uset       = valid && t1_hit && (provider == 2'b01) && !misp;
        t1_uclr       = valid && t1_hit && (provider == 2'b01) &&  misp;
    end

    // ---------------------------------------------------------------
    // Stats: cumulative correct/mispredict only (8-bit saturating each).
    // Per-table breakdown is observable live on uo_out's provider/hit
    // bits in predict mode -- accumulate off-chip if you need it.
    // ---------------------------------------------------------------
    reg [7:0] correct_count, mispredict_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            correct_count    <= 8'd0;
            mispredict_count <= 8'd0;
        end else if (valid) begin
            if (misp) begin
                if (mispredict_count != 8'hFF) mispredict_count <= mispredict_count + 1'b1;
            end else begin
                if (correct_count != 8'hFF) correct_count <= correct_count + 1'b1;
            end
        end
    end

    // ---------------------------------------------------------------
    // Register readback mux (8 x 8-bit registers)
    // ---------------------------------------------------------------
    reg [7:0] stat_byte;
    always @(*) begin
        case (stat_reg_addr)
            3'd0: stat_byte = correct_count;
            3'd1: stat_byte = mispredict_count;
            3'd2: stat_byte = {5'b0, ghr[2:0]};
            3'd3: stat_byte = {4'b0, loop_conf_ok, provider, misp};
            3'd7: stat_byte = 8'hA5; // readback sanity/version byte
            default: stat_byte = 8'h00;
        endcase
    end

    // ---------------------------------------------------------------
    // Output mux
    // ---------------------------------------------------------------
    wire [7:0] normal_out = {ghr[0], 1'b0, t1_hit, loop_conf_ok,
                              provider, misp, final_pred};

    assign uo_out = readback_mode ? stat_byte : normal_out;

endmodule
