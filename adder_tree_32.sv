module adder_tree_32 #(
    parameter WIDTH = 7,  // Enough bits to hold values up to 64
    parameter E = 32      // Number of inputs (experts)
)(
    input  logic [WIDTH-1:0]   in_data [0:E-1],
    output logic [WIDTH+5:0]   sum  // +5 bits to prevent overflow when summing 32 values
);

    always_comb begin
        sum = '0; 
        for (int i = 0; i < E; i++) begin
            sum = sum + in_data[i];
        end
    end

endmodule
