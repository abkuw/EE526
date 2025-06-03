/**
 * Optimized DP module for Systolic Tensor Array (STA) Processing Element
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

    // Optimized internal signals
    logic signed [2*QUANTIZED_WIDTH-1:0] products [B-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] dot_product;
    logic signed [4*QUANTIZED_WIDTH-1:0] result_reg;
    
    // Generate parallel multipliers for better synthesis optimization
    genvar i;
    generate
        for (i = 0; i < B; i++) begin : gen_multipliers
            always_ff @(posedge clk_i) begin
                products[i] <= data_i[i] * weight_i[i];
            end
        end
    endgenerate
    
    // Optimized dot product calculation using tree reduction for better timing
    always_comb begin
        case (B)
            1: dot_product = products[0];
            2: dot_product = products[0] + products[1];
            4: dot_product = (products[0] + products[1]) + (products[2] + products[3]);
            8: dot_product = ((products[0] + products[1]) + (products[2] + products[3])) +
                           ((products[4] + products[5]) + (products[6] + products[7]));
            default: begin
                // Fallback for other values of B
                dot_product = '0;
                for (int j = 0; j < B; j++) begin
                    dot_product += products[j];
                end
            end
        endcase
    end
    
    // Optimized pass-through logic (unchanged for correctness)
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            data_v_o <= '{default: '0};
            weight_h_o <= '{default: '0};
        end else begin
            data_v_o <= data_i;
            weight_h_o <= weight_i;
        end
    end
    
    // Optimized accumulation logic with single calculation
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            result_reg <= '0;
        end else begin
            if (clear_acc_i) begin
                result_reg <= dot_product;
            end else begin
                result_reg <= result_reg + dot_product;
            end
        end
    end
    
    // Direct assignment for better synthesis
    assign result = result_reg;

endmodule
