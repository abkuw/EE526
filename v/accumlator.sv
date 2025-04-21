// Abhishek Kumar, Keith Phou
// EE 526

// Sums mulitple sequnetial inputs over time
module accumlator #(
    parameter WIDTH = 32
) (
    input  logic                 clk,
    input  logic                 reset,     
    input  logic                 enable,    // accumulate only when high? Possibly don't need
    input  logic [WIDTH-1:0]     in,
    output logic [WIDTH-1:0]     out

);
    // testing comment
    // on every cycle sum the 
    always_ff @(posedge clk) begin
        if (reset) begin
            out <= '0;
        end else if (enable) begin
            out <= out + in;
        end
    end

endmodule
