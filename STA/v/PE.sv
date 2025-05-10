// File: PE.sv
// PE Module with array-based result output format to match STA requirements
`include "v/DP.sv" // Assumes DP.sv is available

// Define buffer locally within PE file
module SimpleTypeParameterizedBuffer #(
    parameter type T = logic signed [7:0][3:0]
) (
    input logic clk_i,
    input logic reset_i,
    input T i,
    output T o
);
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            o <= '{default: '0};
        end else begin
            o <= i;
        end
    end
endmodule

// Main PE Module - Hardcoded for 2x2 (A=2, C=2) DP structure
// Now with array-based result output
module PE #(
    parameter B = 4,
    parameter QUANTIZED_WIDTH = 8,
    parameter A = 2,  // M dimension in the STA
    parameter C = 2,  // N dimension in the STA
    parameter M = 2,  // Rows in the result array (matches A)
    parameter N = 2   // Columns in the result array (matches C)
) (
    input logic clk_i,
    input logic reset_i,
    input logic clear_acc_i,

    // PE Inputs
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [2*B-1:0],
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[2*B-1:0],

    // PE Outputs
    output logic signed [QUANTIZED_WIDTH-1:0] data_o   [2*B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[2*B-1:0],
    
    // 2D array [M][N] of accumulators used for verifying
    output logic signed [4*QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0]
);

    // --- Derived Parameters ---
    localparam DP_VECTOR_COUNT = B;
    typedef logic signed [QUANTIZED_WIDTH-1:0] dp_vector_array_t [DP_VECTOR_COUNT-1:0];
    localparam ACCUMULATOR_WIDTH = 4 * QUANTIZED_WIDTH;

    // --- Internal Signals ---
    dp_vector_array_t dp1_data_v_o, dp1_weight_h_o;
    dp_vector_array_t dp2_data_v_o, dp2_weight_h_o;
    dp_vector_array_t dp3_data_v_o, dp3_weight_h_o;
    dp_vector_array_t dp4_data_v_o, dp4_weight_h_o;

    // DP accumulator results
    logic signed [ACCUMULATOR_WIDTH-1:0] resultdp1, resultdp2, resultdp3, resultdp4;
    
    // Registered results
    logic signed [ACCUMULATOR_WIDTH-1:0] resultdp1_reg, resultdp2_reg, resultdp3_reg, resultdp4_reg;
    
    // Synchronized clear signal
    logic clear_acc_reg;
    
    // Register the clear_acc signal
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            clear_acc_reg <= 0;
        end else begin
            clear_acc_reg <= clear_acc_i;
        end
    end

    // --- DP Instantiations ---
    // [0,0]
    DP #(.B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH)) DP1 (
        .clk_i(clk_i), 
        .reset_i(reset_i),
        .clear_acc_i(clear_acc_i),
        .data_i(data_i[0 +: B]),
        .weight_i(weights_i[0 +: B]),
        .weight_h_o(dp1_weight_h_o),
        .data_v_o(dp1_data_v_o),
        .result(resultdp1)
    );
    // [0,1]
    DP #(.B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH)) DP2 (
        .clk_i(clk_i), 
        .reset_i(reset_i),
        .clear_acc_i(clear_acc_i),
        .data_i(data_i[B +: B]),
        .weight_i(dp1_weight_h_o),
        .weight_h_o(dp2_weight_h_o),
        .data_v_o(dp2_data_v_o),
        .result(resultdp2)
    );
    // [1,0]
    DP #(.B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH)) DP3 (
        .clk_i(clk_i), 
        .reset_i(reset_i),
        .clear_acc_i(clear_acc_i),
        .data_i(dp1_data_v_o),
        .weight_i(weights_i[B +: B]),
        .weight_h_o(dp3_weight_h_o),
        .data_v_o(dp3_data_v_o),
        .result(resultdp3)
    );
    // [1,1]
    DP #(.B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH)) DP4 (
        .clk_i(clk_i), 
        .reset_i(reset_i),
        .clear_acc_i(clear_acc_i),
        .data_i(dp2_data_v_o),
        .weight_i(dp3_weight_h_o),
        .weight_h_o(dp4_weight_h_o),
        .data_v_o(dp4_data_v_o),
        .result(resultdp4)
    );

    // // --- Output Buffering ---
    // SimpleTypeParameterizedBuffer #(.T(dp_vector_array_t)) buf_weights_out_top (
    //     .clk_i(clk_i), .reset_i(reset_i),
    //     .i(dp2_weight_h_o),
    //     .o(weights_o[0 +: B])
    // );
    
    // SimpleTypeParameterizedBuffer #(.T(dp_vector_array_t)) buf_data_out_left (
    //     .clk_i(clk_i), .reset_i(reset_i),
    //     .i(dp3_data_v_o),
    //     .o(data_o[0 +: B])
    // );
    
    // SimpleTypeParameterizedBuffer #(.T(dp_vector_array_t)) buf_weights_out_bottom (
    //     .clk_i(clk_i), .reset_i(reset_i),
    //     .i(dp4_weight_h_o),
    //     .o(weights_o[B +: B])
    // );
    
    // SimpleTypeParameterizedBuffer #(.T(dp_vector_array_t)) buf_data_out_right (
    //     .clk_i(clk_i), .reset_i(reset_i),
    //     .i(dp4_data_v_o),
    //     .o(data_o[B +: B])
    // );

    // Direct connections without extra buffering
    assign weights_o[0 +: B] = dp2_weight_h_o;
    assign data_o[0 +: B] = dp3_data_v_o;
    assign weights_o[B +: B] = dp4_weight_h_o;
    assign data_o[B +: B] = dp4_data_v_o;

    // --- Result Registration and Output Assignment ---
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            resultdp1_reg <= '0;
            resultdp2_reg <= '0;
            resultdp3_reg <= '0;
            resultdp4_reg <= '0;
        end else begin
            resultdp1_reg <= resultdp1;
            resultdp2_reg <= resultdp2;
            resultdp3_reg <= resultdp3;
            resultdp4_reg <= resultdp4;
        end
    end
    
    // Map the individual DP results to the 2D result array
    // For a 2x2 PE:
    // [0][0] = DP1, [0][1] = DP2
    // [1][0] = DP3, [1][1] = DP4
    assign result_o[0][0] = resultdp1_reg;
    assign result_o[0][1] = resultdp2_reg;
    assign result_o[1][0] = resultdp3_reg;
    assign result_o[1][1] = resultdp4_reg;

endmodule