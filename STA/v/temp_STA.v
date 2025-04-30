// Include the PE module definition (either directly or via `include)
// Assumes PE module is defined above or in "PE.v"
// `include "PE.v"

// Systolic Tensor Array (STA) Module
// Instantiates an MxN grid of Processing Elements (PEs)
module STA #(
    // STA Dimensions
    parameter M = 32, // Number of rows in the PE array
    parameter N = 32, // Number of columns in the PE array
    // PE Parameters (should match the PE module)
    parameter B = 4,
    parameter C = 2,
    parameter A = 2,
    parameter quantized_size = 8
) (
    input clk_i,
    input reset_i,

    // Data inputs entering the top row of the STA
    input logic [2*B - 1 : 0] data_in [N-1:0][quantized_size-1:0],
    // Weight inputs entering the leftmost column of the STA
    input logic [2*B - 1 : 0] weights_in [M-1:0][quantized_size-1:0],

    // Data outputs exiting the bottom row of the STA
    output logic [2*B - 1 : 0] data_out [N-1:0][quantized_size-1:0],
    // Weight outputs exiting the rightmost column of the STA
    output logic [2*B - 1 : 0] weights_out [M-1:0][quantized_size-1:0]
);

    // Define the data type for signals connecting PEs
    typedef logic [2*B - 1 : 0] data_element_t [quantized_size-1:0];

    // Internal signals for connecting PEs
    // Vertical data flow signals: data_signals[row+1][col] = data_o from PE[row][col]
    data_element_t data_signals [M:0][N-1:0];
    // Horizontal weight flow signals: weights_signals[row][col+1] = weights_o from PE[row][col]
    data_element_t weights_signals  

    // Connect STA inputs to the first row/column of signals
    assign data_signals[0] = data_in;
    genvar r;
    generate
        for (r = 0; r < M; r++) begin : assign_weights_in
            assign weights_signals[r][0] = weights_in[r];
        end
    endgenerate

    // Instantiate the MxN array of PEs
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : row_gen // Rows
            for (j = 0; j < N; j++) begin : col_gen // Columns
                // Instantiate the Processing Element
                PE #(
                    .B(B),
                    .C(C),
                    .A(A),
                    .quantized_size(quantized_size)
                ) pe_inst (
                    .clk_i      (clk_i),
                    .reset_i    (reset_i),
                    // Connect data input from PE above or STA input
                    .data_i     (data_signals[i][j]),
                    // Connect weight input from PE to the left or STA input
                    .weights_i  (weights_signals[i][j]),
                    // Connect data output to PE below or STA output
                    .data_o     (data_signals[i+1][j]),
                    // Connect weight output to PE to the right or STA output
                    .weights_o  (weights_signals[i][j+1])
                );
            end
        end
    endgenerate

    // Connect the last row/column signals to STA outputs
    assign data_out = data_signals[M];
    genvar k;
    generate
        for (k = 0; k < M; k++) begin : assign_weights_out
            assign weights_out[k] = weights_signals[k][N];
        end
    endgenerate

endmodule
