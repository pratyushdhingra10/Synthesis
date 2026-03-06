module lexi_split_phase1 #(
    parameter E = 32,          // Number of experts
    parameter P = 64,          // Total PEs
    parameter LAT_WIDTH = 24,  // Bit-width for latency values
    parameter PE_WIDTH = 7     // Bit-width for PE count (up to 64)
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    input  logic [11:0]          tokens [0:E-1], // t_i input per expert
    
    output logic                 done,
    output logic [PE_WIDTH-1:0]  alloc_r [0:E-1], // r*_i output
    output logic [LAT_WIDTH-1:0] bottleneck_c     // C* output
);

    localparam int unsigned C_MIN = 100;
    localparam int unsigned C_MAX = 8_781_696;

    // FSM States
    typedef enum logic [1:0] {IDLE, EVAL, CHECK, DONE} state_t;
    state_t state;

    // Binary Search Registers
    logic [LAT_WIDTH-1:0] low, high, mid;
    
    // Parallel EEU outputs
    logic [PE_WIDTH-1:0] r_needed [0:E-1];
    logic [PE_WIDTH+5:0] sum_r; // Adder tree output

    // Adder Tree Instantiation (Combinational)
    adder_tree_32 #(.WIDTH(PE_WIDTH)) u_adder_tree (
        .in_data(r_needed),
        .sum(sum_r)
    );

    // Parallel Expert Evaluators (Combinational ROM lookups)
    genvar i;
    generate
        for (i = 0; i < E; i++) begin : gen_eeu
            expert_eval_unit u_eeu (
                .target_c(mid),
                .tokens_t(tokens[i]),
                .req_p(r_needed[i]) // Returns min p | L(p) <= mid
            );
        end
    endgenerate

    // FSM and Datapath
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            low <= '0;
            high <= '0;
            mid <= '0;
            bottleneck_c <= '0;
            alloc_r <= '{default:'0};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        low <= LAT_WIDTH'(C_MIN);
                        high <= LAT_WIDTH'(C_MAX);
                        state <= EVAL;
                    end
                end
                EVAL: begin
                    mid <= low + ((high - low) >> 1);
                    state <= CHECK;
                end
                CHECK: begin
                    if (low > high) begin
                        state <= DONE;
                    end else if (sum_r <= P) begin // Feasible condition [cite: 5, 15]
                        bottleneck_c <= mid;
                        alloc_r <= r_needed;
                        high <= mid - 1;
                        state <= EVAL;
                    end else begin
                        low <= mid + 1;
                        state <= EVAL;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
