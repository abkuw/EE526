// File: PE.sv
// PE Module (Hardcoded 2x2 with Type-Parameterized Buffer and Corrected Concatenated Result Output)
`include "v/DP.sv" // Assumes DP.sv is available (dp_module_final_v1)

// Define buffer locally within PE file or include separately
module SimpleTypeParameterizedBuffer #(
    // Parameterize by the data type the buffer should handle
    // Default type matches dp_vector_array_t structure for B=4, QW=8
    parameter type T = logic signed [7:0][3:0]
) (
    input logic clk_i,
    input logic reset_i, // Active-high reset
    input T i,           // Input port of type T
    output T o          // Output port of type T
);
    // Use standard synchronous logic with reset
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            // Reset output using default assignment for complex types
            o <= '{default: '0};
        end else begin
            o <= i;  // Capture input on clock edge
        end
    end
endmodule


// Main PE Module - Hardcoded for 2x2 (A=2, C=2) DP structure
module PE #(
    // B and QUANTIZED_WIDTH are the main parameters needed
    parameter B = 4,
    parameter QUANTIZED_WIDTH = 8,
    // A and C are implicitly 2 in this hardcoded version
    parameter A = 2, // Keep for compatibility if needed elsewhere
    parameter C = 2  // Keep for compatibility if needed elsewhere
) (
    input logic clk_i,
    input logic reset_i,

    // PE Inputs: 1D unpacked arrays expected by pe_tb
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [2*B-1:0], // B*C = 2*B
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[2*B-1:0], // B*A = 2*B

    // PE Outputs: 1D unpacked arrays matching inputs
    output logic signed [QUANTIZED_WIDTH-1:0] data_o   [2*B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[2*B-1:0],
    // CORRECTED Result Output: Single packed vector, concatenation of all 4 DP results
    output logic signed [4*(4*QUANTIZED_WIDTH)-1:0] result_o // Width is 4 * ACCUMULATOR_WIDTH
);

    // --- Derived Parameters ---
    localparam DP_VECTOR_COUNT      = B;
    // Define the type for an array of B vectors, each QUANTIZED_WIDTH bits wide
    typedef logic signed [QUANTIZED_WIDTH-1:0] dp_vector_array_t [DP_VECTOR_COUNT-1:0];
    // Define the width of the accumulator result from the DP module
    localparam ACCUMULATOR_WIDTH    = 4 * QUANTIZED_WIDTH;

    // --- Internal Signals ---

    // Signals between DPs (Using the defined array type)
    dp_vector_array_t dp1_data_v_o;   // Data passed down from DP1 to DP3
    dp_vector_array_t dp1_weight_h_o; // Weight passed right from DP1 to DP2
    dp_vector_array_t dp2_data_v_o;   // Data passed down from DP2 to DP4
    dp_vector_array_t dp2_weight_h_o; // Weight passed right from DP2 (to PE output buffer)
    dp_vector_array_t dp3_data_v_o;   // Data passed down from DP3 (to PE output buffer)
    dp_vector_array_t dp3_weight_h_o; // Weight passed right from DP3 to DP4
    dp_vector_array_t dp4_data_v_o;   // Data passed down from DP4 (to PE output buffer)
    dp_vector_array_t dp4_weight_h_o; // Weight passed right from DP4 (to PE output buffer)

    // DP accumulator results (Correct type)
    logic signed [ACCUMULATOR_WIDTH-1:0] resultdp1, resultdp2, resultdp3, resultdp4;

    // --- DP Instantiations (Hardcoded 2x2 Structure) ---

    // Row 1, Col 1
    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP1 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(data_i[0 +: B]),          // First B data inputs
        .weight_i(weights_i[0 +: B]),    // First B weight inputs
        .weight_h_o(dp1_weight_h_o),     // Weight out to DP2
        .data_v_o(dp1_data_v_o),         // Data out to DP3
        .result(resultdp1)
    );

    // Row 1, Col 2
    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP2 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(data_i[B +: B]),          // Second B data inputs
        .weight_i(dp1_weight_h_o),       // Weight input from DP1
        .weight_h_o(dp2_weight_h_o),     // Weight out right (buffered to weights_o[0..B-1])
        .data_v_o(dp2_data_v_o),         // Data out down to DP4
        .result(resultdp2)
    );

    // Row 2, Col 1
    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP3 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(dp1_data_v_o),           // Data input from DP1
        .weight_i(weights_i[B +: B]),    // Second B weight inputs
        .weight_h_o(dp3_weight_h_o),     // Weight out to DP4
        .data_v_o(dp3_data_v_o),         // Data out down (buffered to data_o[0..B-1])
        .result(resultdp3)
    );

    // Row 2, Col 2
    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP4 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(dp2_data_v_o),           // Data input from DP2
        .weight_i(dp3_weight_h_o),       // Weight input from DP3
        .weight_h_o(dp4_weight_h_o),     // Weight out right (buffered to weights_o[B..2B-1])
        .data_v_o(dp4_data_v_o),         // Data out down (buffered to data_o[B..2B-1])
        .result(resultdp4)
    );


    // --- Output Buffering using SimpleTypeParameterizedBuffer ---
    // NO FLATTENING/UNFLATTENING NEEDED

    // Instantiate Buffers (Pass the unpacked array type directly)
    SimpleTypeParameterizedBuffer #( .T(dp_vector_array_t) ) buf_weights_out_top (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(dp2_weight_h_o),       // Input from DP2 weight output
        .o(weights_o[0 +: B])     // Output directly to first half of weights_o
    );
    SimpleTypeParameterizedBuffer #( .T(dp_vector_array_t) ) buf_data_out_left (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(dp3_data_v_o),         // Input from DP3 data output
        .o(data_o[0 +: B])        // Output directly to first half of data_o
    );
    SimpleTypeParameterizedBuffer #( .T(dp_vector_array_t) ) buf_weights_out_bottom (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(dp4_weight_h_o),       // Input from DP4 weight output
        .o(weights_o[B +: B])     // Output directly to second half of weights_o
    );
    SimpleTypeParameterizedBuffer #( .T(dp_vector_array_t) ) buf_data_out_right (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(dp4_data_v_o),         // Input from DP4 data output
        .o(data_o[B +: B])        // Output directly to second half of data_o
    );

    // --- Assign Result Output ---
    // Concatenate the results from all four DPs
    assign result_o = {resultdp1, resultdp2, resultdp3, resultdp4};

endmodule
