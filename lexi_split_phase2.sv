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
    localparam int DELTA_K_WIDTH = 12;
    localparam int TOKEN_TERM_WIDTH = 13;
    localparam int DELTA_L_WIDTH = DELTA_K_WIDTH + TOKEN_TERM_WIDTH;
    localparam int IDX_WIDTH = (E > 1) ? $clog2(E) : 1;

    logic [DELTA_L_WIDTH-1:0] delta_L [0:E-1];
    logic [IDX_WIDTH-1:0]     max_idx;
    logic [DELTA_L_WIDTH-1:0] max_val;

    function automatic int unsigned get_delta_k(input int unsigned p);
        int unsigned k_curr;
        int unsigned k_next;
        begin
            if (p >= P) begin
                get_delta_k = 0;
            end else begin
                // delta_K(p) = K(p) - K(p+1), K(p) = ceil(1408/p) + ceil(704/p)
                k_curr = ((1408 + p - 1) / p) + ((704 + p - 1) / p);
                k_next = ((1408 + p) / (p + 1)) + ((704 + p) / (p + 1));
                get_delta_k = k_curr - k_next;
            end
        end
    endfunction

    // 1. Calculate marginal benefit for each expert.
    always_comb begin
        for (int i = 0; i < E; i++) begin
            int unsigned current_p;
            int unsigned delta_k;
            logic [TOKEN_TERM_WIDTH-1:0] token_term;

            current_p = p_in[i];
            token_term = tokens_t[i] + TAU;

            // Guard p=0 and p>=P to avoid invalid lookup/updates.
            if ((current_p < 1) || (current_p >= P)) begin
                delta_L[i] = '0;
            end else begin
                delta_k = get_delta_k(current_p);
                delta_L[i] = delta_k * token_term;
            end
        end
    end

    // 2. Combinational comparator tree to find the expert with maximum benefit.
    always_comb begin
        max_idx = '0;
        max_val = delta_L[0];
        for (int i = 1; i < E; i++) begin
            if (delta_L[i] > max_val) begin
                max_val = delta_L[i];
                max_idx = i;
            end
        end
    end

    // 3. Register the output (pipeline barrier).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < E; i++) begin
                p_out[i] <= '0;
            end
        end else begin
            for (int i = 0; i < E; i++) begin
                if (active && (i == max_idx)) begin
                    p_out[i] <= p_in[i] + 1; // Boost the best-benefit expert
                end else begin
                    p_out[i] <= p_in[i];     // Pass through unchanged
                end
            end
        end
    end
endmodule

module lexi_split_phase2 #(
    parameter E = 32,
    parameter P = 64,
    parameter PE_WIDTH = 7
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [11:0]          tokens_t [0:E-1],
    input  logic [PE_WIDTH-1:0]  r_star [0:E-1],
    input  logic [PE_WIDTH:0]    R_leftover,

    output logic [PE_WIDTH-1:0]  final_alloc [0:E-1]
);

    // stage_alloc[s][i] holds expert i allocation at pipeline stage s.
    logic [PE_WIDTH-1:0] stage_alloc [0:P][0:E-1];

    genvar i_seed;
    generate
        for (i_seed = 0; i_seed < E; i_seed++) begin : gen_seed
            assign stage_alloc[0][i_seed] = r_star[i_seed];
        end
    endgenerate

    genvar s;
    generate
        for (s = 0; s < P; s++) begin : gen_stages
            logic stage_active;
            assign stage_active = (s < R_leftover);

            greedy_stage #(
                .E(E), .P(P), .PE_WIDTH(PE_WIDTH)
            ) u_stage (
                .clk(clk),
                .rst_n(rst_n),
                .active(stage_active),
                .tokens_t(tokens_t),
                .p_in(stage_alloc[s]),
                .p_out(stage_alloc[s+1])
            );
        end
    endgenerate

    genvar i_out;
    generate
        for (i_out = 0; i_out < E; i_out++) begin : gen_out
            assign final_alloc[i_out] = stage_alloc[P][i_out];
        end
    endgenerate

endmodule
