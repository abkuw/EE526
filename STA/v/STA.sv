// Systolic Tensor Array (STA) Module - M x N grid of PEs
module STA #(
    parameter N = 4, // Number of PE columns should be 32 x 32 but downsized for compilation times
    parameter M = 4, // Number of PE rows
    parameter B = 4,  // Multipliers per DP
    parameter C = 2,  // Columns of DPs in PE
    parameter A = 2,  // Rows of DPs in PE
    parameter QUANTIZED_WIDTH = 8
)(
    input logic clk_i,
    input logic reset_i,
    input logic signed [QUANTIZED_WIDTH-1:0] data_i[N-1:0][C-1:0][B-1:0],
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][A-1:0][B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] data_o[N-1:0][C-1:0][B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][A-1:0][B-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0][2*B-1:0]  // Changed to match PE's result_o type
);
    // 1D flattened arrays for PE connections
    logic signed [QUANTIZED_WIDTH-1:0] pe_data_in[M:0][N-1:0][B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] pe_weight_in[M-1:0][N:0][B*A-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] pe_results[M-1:0][N-1:0][2*B-1:0]; // Changed to match PE's result_o type

    // Generate block for PE grid
    genvar i, j, c, a, b, r;
    generate
        // Flatten input data for top row
        for (j = 0; j < N; j++) begin : data_flatten
            for (c = 0; c < C; c++) begin : data_flatten_c
                for (b = 0; b < B; b++) begin : data_flatten_b
                    assign pe_data_in[0][j][c*B + b] = data_i[j][c][b];
                end
            end
        end

        // Flatten input weights for leftmost column
        for (i = 0; i < M; i++) begin : weight_flatten
            for (a = 0; a < A; a++) begin : weight_flatten_a
                for (b = 0; b < B; b++) begin : weight_flatten_b
                    assign pe_weight_in[i][0][a*B + b] = weights_i[i][a][b];
                end
            end
        end

        // PE grid instantiation
        for (i = 0; i < M; i++) begin : row_gen
            for (j = 0; j < N; j++) begin : col_gen
                PE #(
                    .B(B),
                    .C(C),
                    .A(A),
                    .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
                ) pe_inst (
                    .clk_i(clk_i),
                    .reset_i(reset_i),
                    .data_i(pe_data_in[i][j]),
                    .weights_i(pe_weight_in[i][j]),
                    .data_o(pe_data_in[i+1][j]),
                    .weights_o(pe_weight_in[i][j+1]),
                    .result_o(pe_results[i][j])
                );
            end
        end

        // Unflatten output data from bottom row
        for (j = 0; j < N; j++) begin : data_unflatten
            for (c = 0; c < C; c++) begin : data_unflatten_c
                for (b = 0; b < B; b++) begin : data_unflatten_b
                    assign data_o[j][c][b] = pe_data_in[M][j][c*B + b];
                end
            end
        end

        // Unflatten output weights from rightmost column
        for (i = 0; i < M; i++) begin : weight_unflatten
            for (a = 0; a < A; a++) begin : weight_unflatten_a
                for (b = 0; b < B; b++) begin : weight_unflatten_b
                    assign weights_o[i][a][b] = pe_weight_in[i][N][a*B + b];
                end
            end
        end

        // Connect PE results to output result array
        for (i = 0; i < M; i++) begin : result_connect_row
            for (j = 0; j < N; j++) begin : result_connect_col
                for (r = 0; r < 2*B; r++) begin : result_connect_elem
                    assign result_o[i][j][r] = pe_results[i][j][r];
                end
            end
        end
    endgenerate
endmodule