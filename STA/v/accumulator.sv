// Abhishek Kumar, Keith Phou
// EE 526

// Sums multiple sequential inputs over time
module accumulator #(
    parameter WIDTH = 32
) (
    input  logic                 clk,
    input  logic                 reset,     
    input  logic [WIDTH-1:0]     in,
    output logic [WIDTH-1:0]     out
);
    // on every cycle sum the input
    always_ff @(posedge clk) begin
        if (reset) begin
            out <= '0;
        end else begin
            out <= out + in;
        end
    end
endmodule