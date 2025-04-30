// Abhishek Kumar, Keith Phou
// EE 526

// Variable bit adder
module adder #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] sum,
    output logic carry_out
);

    logic [WIDTH:0] result; // One bit wider to hold carry

    always_comb begin
        result   = a + b;
        sum      = result[WIDTH-1:0];
        carry_out = result[WIDTH];
    end

endmodule
