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

    // Inputs (B vectors, each QUANTIZED_WIDTH bits wide)
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [B-1:0],
    input logic signed [QUANTIZED_WIDTH-1:0] weight_i [B-1:0],

    // Outputs for systolic array pass-through (registered)
    output logic signed [QUANTIZED_WIDTH-1:0] data_v_o   [B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weight_h_o [B-1:0],

    // Accumulated result output (registered)
    // Width needs to be sufficient to avoid overflow.
    // Summing B products of (QUANTIZED_WIDTH * QUANTIZED_WIDTH) bits.
    // Product width = 2 * QUANTIZED_WIDTH
    // Sum width needs ~ (2 * QUANTIZED_WIDTH) + ceil(log2(B)) bits.
    // Example: B=4, QW=8 -> Product=16 bits. Sum ~ 16 + log2(4) = 18 bits minimum.
    // Using 32 bits (4*QW) provides headroom, common for INT8 MAC units.
    output logic signed [4*QUANTIZED_WIDTH-1:0] result
);

    // Intermediate signals
    // Array to hold the B individual products
    logic signed [2*QUANTIZED_WIDTH-1:0] products [B-1:0];

    // Combinational signal holding the sum of the B products for the current cycle
    logic signed [4*QUANTIZED_WIDTH-1:0] sum_of_products_comb;

    // Internal accumulator register (matches the output 'result')
    logic signed [4*QUANTIZED_WIDTH-1:0] result_reg;


    // Generate B parallel multipliers
    genvar i;
    generate
        for (i = 0; i < B; i = i + 1) begin : multipliers
            // Calculate individual product (signed multiplication)
            // Result width is 2 * QUANTIZED_WIDTH
            assign products[i] = data_i[i] * weight_i[i];
        end
    endgenerate

    // Combinational logic to sum the B products
    // This implements the adder tree following the multipliers
    always_comb begin
        sum_of_products_comb = '0; // Start with zero for summation
        for (int j = 0; j < B; j = j + 1) begin
            // Add each product to the sum, sign extension happens automatically
            sum_of_products_comb = sum_of_products_comb + products[j];
        end
    end

    // Registered logic for accumulation and pass-through
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            // Reset registers to zero
            // Use simple '0 assignment, SystemVerilog infers dimensions
            data_v_o   <= '0;
            weight_h_o <= '0;
            result_reg <= '0;

            /* Added for testbenching I needed this for simulation to run - Keith
            // Reset registers to zero - properly reset unpacked arrays element-by-element
            for (int j = 0; j < B; j = j + 1) begin
                data_v_o[j]   <= '0;
                weight_h_o[j] <= '0;
            end
            result_reg <= '0;
            */
        end else begin
            // Pass inputs to outputs (systolic movement)
            data_v_o   <= data_i;
            weight_h_o <= weight_i;

            // Accumulate the sum of products calculated in this cycle
            result_reg <= result_reg + sum_of_products_comb;

            /* Added for tb - Keith
            // Pass inputs to outputs (systolic movement)
            // Handle array assignments element-by-element
            for (int j = 0; j < B; j = j + 1) begin
                data_v_o[j]   <= data_i[j];
                weight_h_o[j] <= weight_i[j];
            end

            // Accumulate the sum of products calculated in this cycle
            result_reg <= result_reg + sum_of_products_comb;
            */
        end
    end

    // Assign the final accumulated value to the output port
    assign result = result_reg;

endmodule