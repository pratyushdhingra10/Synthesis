module greedy_stage #(
    parameter E = 32,
    parameter P = 64,
    parameter PE_WIDTH = 7
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 active,       // 1 if this stage is needed (stage_idx < R)
    input  logic [11:0]          tokens_t [0:E-1],
    input  logic [PE_WIDTH-1:0]  p_in [0:E-1], // PE allocation from previous stage
    
    output logic [PE_WIDTH-1:0]  p_out [0:E-1] // Output allocation to next stage
);

    localparam int TAU = 63;
    logic [11:0] delta_K_coeff [1:P];
    logic [15:0] delta_L [0:E-1];
    logic [4:0]  max_idx;
    logic [15:0] max_val;

    // ROM: Precomputed marginal coefficient reductions
    // delta_K(p) = K(p) - K(p+1)
    initial begin
        for (int p = 1; p < P; p++) begin
            int k_curr = ((1408 + p - 1) / p) + ((704 + p - 1) / p);
            int k_next = ((1408 + p) / (p + 1)) + ((704 + p) / (p + 1));
            delta_K_coeff[p] = k_curr - k_next;
        end
        delta_K_coeff[P] = 0;
    end

    // 1. Calculate marginal benefit for each expert
    always_comb begin
        for (int i = 0; i < E; i++) begin
            int current_p = p_in[i];
            // If an expert already has max PEs, it cannot benefit further
            if (current_p >= P) begin
                delta_L[i] = 0;
            end else begin
                delta_L[i] = delta_K_coeff[current_p] * (tokens_t[i] + TAU);
            end
        end
    end

    // 2. Combinational Comparator Tree to find the expert with maximum benefit
    always_comb begin
        max_idx = 0;
        max_val = delta_L[0];
        for (int i = 1; i < E; i++) begin
            if (delta_L[i] > max_val) begin
                max_val = delta_L[i];
                max_idx = i;
            end
        end
    end

    // 3. Register the output (Pipeline barrier)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < E; i++) p_out[i] <= '0;
        end else begin
            for (int i = 0; i < E; i++) begin
                if (active && i == max_idx) begin
                    p_out[i] <= p_in[i] + 1; // Boost the slowest expert
                end else begin
                    p_out[i] <= p_in[i];     // Pass through unchanged
                end
            end
        end
    end
endmodule
