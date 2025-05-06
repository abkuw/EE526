// File: STA.sv
// Systolic Tensor Array (STA) Module - M x N grid of PEs
// Corrected to handle wide result_o from PE
`include "v/PE.sv" // Assumes PE.sv is pe_module_corrected_result

module STA #(
    parameter N = 4, // Number of PE columns (Using testbench value)
    parameter M = 4, // Number of PE rows (Using testbench value)
    parameter B = 4,  // Multipliers per DP
    parameter C = 2,  // Columns of DPs in PE (Implicit in PE version being used)
    parameter A = 2,  // Rows of DPs in PE (Implicit in PE version being used)
    parameter QUANTIZED_WIDTH = 8
)(
    input logic clk_i,
    input logic reset_i,

    // STA Inputs: Multi-dimensional as per original intent for PE data/weights
    input logic signed [QUANTIZED_WIDTH-1:0] data_i[N-1:0][C-1:0][B-1:0],
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][A-1:0][B-1:0],

    // STA Outputs: Multi-dimensional as per original intent for PE data/weights
    output logic signed [QUANTIZED_WIDTH-1:0] data_o[N-1:0][C-1:0][B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][A-1:0][B-1:0],
    // Corrected Result Output: Grid of wide packed vectors from each PE
    output logic signed [4*(4*QUANTIZED_WIDTH)-1:0] result_o[M-1:0][N-1:0] // Width matches PE's result_o
);
    // 1D flattened arrays for PE connections (data_i and weights_i to PE)
    logic signed [QUANTIZED_WIDTH-1:0] pe_data_in[M:0][N-1:0][B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] pe_weight_in[M-1:0][N:0][B*A-1:0];

    // Internal signal for PE results, matching PE's result_o width (a 2D array of wide packed vectors)
    logic signed [4*(4*QUANTIZED_WIDTH)-1:0] pe_results[M-1:0][N-1:0];

    // Generate block for PE grid
    genvar i, j, c_idx, a_idx, b_idx; // Renamed c,a,b to avoid conflict with parameters

    generate
        // Flatten input data for top row PEs
        for (j = 0; j < N; j++) begin : data_flatten_loop
            for (c_idx = 0; c_idx < C; c_idx++) begin : data_flatten_c_loop
                for (b_idx = 0; b_idx < B; b_idx++) begin : data_flatten_b_loop
                    assign pe_data_in[0][j][c_idx*B + b_idx] = data_i[j][c_idx][b_idx];
                end
            end
        end

        // Flatten input weights for leftmost column PEs
        for (i = 0; i < M; i++) begin : weight_flatten_loop
            for (a_idx = 0; a_idx < A; a_idx++) begin : weight_flatten_a_loop
                for (b_idx = 0; b_idx < B; b_idx++) begin : weight_flatten_b_loop
                    assign pe_weight_in[i][0][a_idx*B + b_idx] = weights_i[i][a_idx][b_idx];
                end
            end
        end

        // PE grid instantiation
        for (i = 0; i < M; i++) begin : row_gen_loop
            for (j = 0; j < N; j++) begin : col_gen_loop
                PE #(
                    .B(B),
                    .C(C), // PE module still has these parameters
                    .A(A), // PE module still has these parameters
                    .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
                ) pe_inst (
                    .clk_i(clk_i),
                    .reset_i(reset_i),
                    .data_i(pe_data_in[i][j]),
                    .weights_i(pe_weight_in[i][j]),
                    .data_o(pe_data_in[i+1][j]),
                    .weights_o(pe_weight_in[i][j+1]),
                    .result_o(pe_results[i][j]) // Connect PE's wide result_o
                );
            end
        end

        // Unflatten output data from bottom row PEs
        for (j = 0; j < N; j++) begin : data_unflatten_loop
            for (c_idx = 0; c_idx < C; c_idx++) begin : data_unflatten_c_loop
                for (b_idx = 0; b_idx < B; b_idx++) begin : data_unflatten_b_loop
                    assign data_o[j][c_idx][b_idx] = pe_data_in[M][j][c_idx*B + b_idx];
                end
            end
        end

        // Unflatten output weights from rightmost column PEs
        for (i = 0; i < M; i++) begin : weight_unflatten_loop
            for (a_idx = 0; a_idx < A; a_idx++) begin : weight_unflatten_a_loop
                for (b_idx = 0; b_idx < B; b_idx++) begin : weight_unflatten_b_loop
                    assign weights_o[i][a_idx][b_idx] = pe_weight_in[i][N][a_idx*B + b_idx];
                end
            end
        end

        // Connect PE results directly to STA output result array
        for (i = 0; i < M; i++) begin : result_connect_row_loop
            for (j = 0; j < N; j++) begin : result_connect_col_loop
                // Direct assignment as pe_results[i][j] and result_o[i][j] are now the same type
                assign result_o[i][j] = pe_results[i][j];
            end
        end
    endgenerate
endmodule
