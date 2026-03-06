module expert_eval_unit #(
    parameter P = 64,          // Total PEs
    parameter LAT_WIDTH = 24,
    parameter PE_WIDTH = 7
)(
    input  logic [LAT_WIDTH-1:0] target_c,
    input  logic [11:0]          tokens_t,
    
    output logic [PE_WIDTH-1:0]  req_p
);

    // Constant offset from the latency model
    localparam int TAU = 63;
    
    localparam int K_WIDTH = 12;           // max K(p) is 2112 at p=1
    localparam int TOKEN_TERM_WIDTH = 13;  // max tokens_t + TAU is 4158
    localparam int LAT_CALC_WIDTH = K_WIDTH + TOKEN_TERM_WIDTH;

    // Combinational evaluation of L(p) <= target_c for all possible p.
    logic [P:1] meets_target;
    logic [LAT_CALC_WIDTH-1:0] current_latency [1:P];
    logic [TOKEN_TERM_WIDTH-1:0] token_term;

    // Parallel combinational evaluation.
    always_comb begin
        token_term = tokens_t + TAU;
        for (int p = 1; p <= P; p++) begin
            int unsigned k_coeff;
            // ceil(a/b) = (a + b - 1) / b
            k_coeff = ((1408 + p - 1) / p) + ((704 + p - 1) / p);
            current_latency[p] = k_coeff * token_term;
            meets_target[p] = (current_latency[p] <= target_c);
        end
    end

    // Priority Encoder: Find the MINIMUM p that meets the target
    // Because L(p) is strictly decreasing, the first '1' we find is our optimal r_i
    always_comb begin
        req_p = P + 1; // Default to infeasible (P + 1)
        for (int p = P; p >= 1; p--) begin
            if (meets_target[p]) begin
                req_p = p; // Overwrites until it hits the lowest valid p
            end
        end
    end

endmodule
