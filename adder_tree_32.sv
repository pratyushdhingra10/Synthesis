module adder_tree_32 #(
    parameter WIDTH = 7,  // Enough bits to hold values up to 64
    parameter E = 32      // Number of inputs (experts)
)(
    input  logic [WIDTH-1:0]   in_data [0:E-1],
    output logic [WIDTH+((E > 1) ? $clog2(E) : 0)-1:0] sum  // Width scales with E
);

    always_comb begin
        sum = '0; 
        for (int i = 0; i < E; i++) begin
            sum = sum + in_data[i];
        end
    end

endmodule
