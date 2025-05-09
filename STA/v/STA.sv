// Systolic Tensor Array (STA) Module - M x N grid of PEs
module STA #(
    parameter N = 2,             // Number of PE columns 
    parameter M = 2,             // Number of PE rows
    parameter B = 4,             // Multipliers per DP
    parameter QUANTIZED_WIDTH = 8// Bit-width of input data/weights
)(
    input logic clk_i,
    input logic reset_i,
    input logic clear_acc_i,     // Signal to clear accumulators in all PEs
    
    // Input data and weights
    input logic signed [QUANTIZED_WIDTH-1:0] data_i[N*B*2-1:0],     // Flattened data input
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[M*B*2-1:0],  // Flattened weights input
    
    // Output data and weights (pass-through)
    output logic signed [QUANTIZED_WIDTH-1:0] data_o[N*B*2-1:0],    // Flattened data output
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[M*B*2-1:0], // Flattened weights output
    
    // Results from each PE - now a 3D array to capture all DP results within each PE
    // [PE row][PE column][DP row][DP column]
    output logic signed [4*QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0][2-1:0][2-1:0]
);
    // Interconnections between PEs for systolic flow
    logic signed [QUANTIZED_WIDTH-1:0] pe_data_interconnect[M+1-1:0][N-1:0][B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] pe_weight_interconnect[M-1:0][N+1-1:0][B*2-1:0];
    
    // Individual PE result arrays
    logic signed [4*QUANTIZED_WIDTH-1:0] pe_results[M-1:0][N-1:0][2-1:0][2-1:0];
    
    // Generate block for PE grid
    genvar i, j, k, dp_row, dp_col;
    generate
        // Connect input data to the top row of PEs
        for (j = 0; j < N; j++) begin : data_input_connect
            for (k = 0; k < 2*B; k++) begin : data_input_connect_k
                assign pe_data_interconnect[0][j][k] = data_i[j*(2*B) + k];
            end
        end
        
        // Connect input weights to the leftmost column of PEs
        for (i = 0; i < M; i++) begin : weight_input_connect
            for (k = 0; k < 2*B; k++) begin : weight_input_connect_k
                assign pe_weight_interconnect[i][0][k] = weights_i[i*(2*B) + k];
            end
        end
        
        // PE grid instantiation
        for (i = 0; i < M; i++) begin : row_gen
            for (j = 0; j < N; j++) begin : col_gen
                PE #(
                    .B(B),
                    .QUANTIZED_WIDTH(QUANTIZED_WIDTH),
                    .A(2),  // Hardcoded to 2 as per your PE implementation
                    .C(2),  // Hardcoded to 2 as per your PE implementation
                    .M(2),  // Rows in result array
                    .N(2)   // Columns in result array
                ) pe_inst (
                    .clk_i(clk_i),
                    .reset_i(reset_i),
                    .clear_acc_i(clear_acc_i),
                    .data_i(pe_data_interconnect[i][j]),
                    .weights_i(pe_weight_interconnect[i][j]),
                    .data_o(pe_data_interconnect[i+1][j]),
                    .weights_o(pe_weight_interconnect[i][j+1]),
                    .result_o(pe_results[i][j])
                );
                
                // Connect each PE's result array to the STA output
                // Using proper generate loop variables
                for (dp_row = 0; dp_row < 2; dp_row++) begin : result_connect_row
                    for (dp_col = 0; dp_col < 2; dp_col++) begin : result_connect_col
                        assign result_o[i][j][dp_row][dp_col] = pe_results[i][j][dp_row][dp_col];
                    end
                end
            end
        end
        
        // Connect output data from the bottom row of PEs
        for (j = 0; j < N; j++) begin : data_output_connect
            for (k = 0; k < 2*B; k++) begin : data_output_connect_k
                assign data_o[j*(2*B) + k] = pe_data_interconnect[M][j][k];
            end
        end
        
        // Connect output weights from the rightmost column of PEs
        for (i = 0; i < M; i++) begin : weight_output_connect
            for (k = 0; k < 2*B; k++) begin : weight_output_connect_k
                assign weights_o[i*(2*B) + k] = pe_weight_interconnect[i][N][k];
            end
        end
    endgenerate
endmodule