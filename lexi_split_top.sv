module lexi_split_top #(
    parameter E = 32,
    parameter P = 64,
    parameter LAT_WIDTH = 16,
    parameter PE_WIDTH = 7
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    input  logic [11:0]          tokens_t [0:E-1],
    
    output logic                 done,
    output logic [PE_WIDTH-1:0]  final_alloc [0:E-1],
    output logic [LAT_WIDTH-1:0] bottleneck_c
);

    localparam int R_MAX = 32;

    // Interconnect signals between Phase 1 and Phase 2
    logic                 phase1_done;
    logic [PE_WIDTH-1:0]  alloc_r_star [0:E-1];
    logic [PE_WIDTH+5:0]  sum_r_star;
    logic [PE_WIDTH:0]    R_leftover;
    
    // Shift register to delay the 'done' signal through the Phase 2 pipeline
    logic [R_MAX-1:0]     done_shift_reg;

    // -----------------------------------------------------------------
    // 1. Instantiate Phase 1: Parallel Min-Max Binary Search
    // -----------------------------------------------------------------
    lexi_split_phase1 #(
        .E(E), .P(P), .LAT_WIDTH(LAT_WIDTH), .PE_WIDTH(PE_WIDTH)
    ) u_phase1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tokens_t(tokens_t),
        .done(phase1_done),
        .alloc_r(alloc_r_star),
        .bottleneck_c(bottleneck_c)
    );

    // -----------------------------------------------------------------
    // 2. Calculate Leftover PEs for Phase 2
    // -----------------------------------------------------------------
    // We reuse the adder tree concept here to sum the r* allocation.
    // In a highly optimized synthesis, the tool can share the Phase 1 adder tree.
    always_comb begin
        sum_r_star = '0;
        for (int i = 0; i < E; i++) begin
            sum_r_star = sum_r_star + alloc_r_star[i];
        end
        // Calculate leftover PEs (R = P - sum(r_star))
        // Protect against underflow if sum exceeds P (shouldn't happen if Phase 1 is correct)
        if (sum_r_star <= P) begin
            R_leftover = P - sum_r_star;
        end else begin
            R_leftover = '0;
        end
    end

    // -----------------------------------------------------------------
    // 3. Instantiate Phase 2: Pipelined Greedy Min-Sum Optimization
    // -----------------------------------------------------------------
    lexi_split_phase2 #(
        .E(E), .P(P), .PE_WIDTH(PE_WIDTH)
    ) u_phase2 (
        .clk(clk),
        .rst_n(rst_n),
        .tokens_t(tokens_t),
        .r_star(alloc_r_star),
        .R_leftover(R_leftover),
        .final_alloc(final_alloc)
    );

    // -----------------------------------------------------------------
    // 4. Pipeline Synchronization
    // -----------------------------------------------------------------
    // Phase 2 takes exactly R_MAX cycles to flush through its pipeline stages.
    // We delay the phase1_done signal to match this datapath delay.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_shift_reg <= '0;
            done <= 1'b0;
        end else begin
            // Shift left, injecting phase1_done at the LSB
            done_shift_reg <= {done_shift_reg[R_MAX-2:0], phase1_done};
            
            // The final 'done' output is the MSB of the shift register
            // Because phase1_done stays high until the next 'start', we use a 
            // pulse detector (rising edge) or just pass it through depending on your handshake protocol.
            // Here, we just pass the delayed level.
            done <= done_shift_reg[R_MAX-1];
        end
    end

endmodule
