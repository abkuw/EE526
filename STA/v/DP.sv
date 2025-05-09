/**
 * DP module for Systolic Tensor Array (STA) Processing Element
 * Performs B parallel multiplications, sums the products, and accumulates.
 * Assumes signed inputs/weights.
 */
module DP #(
    parameter B = 4,                   // Number of parallel multipliers (BxB)
    parameter QUANTIZED_WIDTH = 8      // Bit-width of input data/weights (e.g., 8 for INT8)
) (
    input logic clk_i,
    input logic reset_i,
    input logic clear_acc_i,           // Signal to clear accumulator without reset

    // Inputs (B vectors, each QUANTIZED_WIDTH bits wide)
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [B-1:0],
    input logic signed [QUANTIZED_WIDTH-1:0] weight_i [B-1:0],

    // Outputs for systolic array pass-through (registered)
    output logic signed [QUANTIZED_WIDTH-1:0] data_v_o   [B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weight_h_o [B-1:0],

    // Accumulated result output (registered)
    output logic signed [4*QUANTIZED_WIDTH-1:0] result
);

    // Calculate dot product combinationally
    function automatic logic signed [4*QUANTIZED_WIDTH-1:0] calc_dot_product(
        logic signed [QUANTIZED_WIDTH-1:0] data [B-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] weights [B-1:0]
    );
        logic signed [4*QUANTIZED_WIDTH-1:0] sum = 0;
        for (int i = 0; i < B; i++) begin
            sum += data[i] * weights[i];
        end
        return sum;
    endfunction
    
    // Internal signals
    logic signed [4*QUANTIZED_WIDTH-1:0] result_reg;
    
    // Pass-through for systolic array
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            for (int i = 0; i < B; i++) begin
                data_v_o[i] <= '0;
                weight_h_o[i] <= '0;
            end
        end else begin
            for (int i = 0; i < B; i++) begin
                data_v_o[i] <= data_i[i];
                weight_h_o[i] <= weight_i[i];
            end
        end
    end
    
    // Accumulation logic
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            result_reg <= '0;
        end else if (clear_acc_i) begin
            // When clear_acc is asserted, start with current dot product only
            result_reg <= calc_dot_product(data_i, weight_i);
        end else begin
            // Normal accumulation
            result_reg <= result_reg + calc_dot_product(data_i, weight_i);
        end
    end
    
    // Assign result
    assign result = result_reg;

endmodule
