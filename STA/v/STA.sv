// Include the corrected PE module definition
// Make sure the path is correct for your environment
`include "v/PE.sv"

// Systolic Tensor Array (STA) Module - M x N grid of PEs
module STA #(
    parameter N = 32, // Number of PE columns
    parameter M = 32, // Number of PE rows
    // Parameters passed down to the PE module
    parameter B = 4,
    parameter C = 2,
    parameter A = 2,
    parameter QUANTIZED_WIDTH = 8 // Consistent parameter name
)(
    input logic clk_i,
    input logic reset_i,

    // STA Inputs:
    // Data enters the top row of PEs (N columns)
    // Each PE needs C blocks of B vectors
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [N-1:0][C-1:0][B-1:0],
    // Weights enter the left column of PEs (M rows)
    // Each PE needs A blocks of B vectors
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][A-1:0][B-1:0],

    // STA Outputs:
    // Data exits the bottom row of PEs (N columns)
    output logic signed [QUANTIZED_WIDTH-1:0] data_o   [N-1:0][C-1:0][B-1:0],
    // Weights exit the right column of PEs (M rows)
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][A-1:0][B-1:0]
);

    // --- Typedefs for PE Interface ---
    // Type matching PE data input/output port: C blocks of B vectors
    typedef logic signed [QUANTIZED_WIDTH-1:0] pe_data_port_t [C-1:0][B-1:0];
    // Type matching PE weight input/output port: A blocks of B vectors
    typedef logic signed [QUANTIZED_WIDTH-1:0] pe_weight_port_t [A-1:0][B-1:0];

    // --- Internal Signal Arrays for Inter-PE Connections ---
    // Vertical data signals between PE rows
    // Need M+1 rows of signals for N columns (data_signals[i][j] is input to PE[i][j])
    pe_data_port_t data_signals[M:0][N-1:0];
    // Horizontal weight signals between PE columns
    // Need N+1 columns of signals for M rows (weights_signals[i][j] is input to PE[i][j])
    pe_weight_port_t weights_signals[M-1:0][N:0];


    // --- Generate the MxN Grid of PEs ---
    genvar i, j; // Row (M) and Column (N) iterators

    generate
        // --- Connect STA Inputs to the Grid Edges ---
        // Connect STA data inputs to the top edge (input to row 0 PEs)
        // data_signals[0][j] is the input for PE[0][j]
        for (j = 0; j < N; j = j + 1) begin : sta_data_input_connect
            assign data_signals[0][j] = data_i[j];
        end
        // Connect STA weight inputs to the left edge (input to column 0 PEs)
        // weights_signals[i][0] is the input for PE[i][0]
        for (i = 0; i < M; i = i + 1) begin : sta_weight_input_connect
            assign weights_signals[i][0] = weights_i[i];
        end

        // --- Instantiate the MxN PE Grid ---
        for (i = 0; i < M; i = i + 1) begin : row_gen
            for (j = 0; j < N; j = j + 1) begin : col_gen
                // Instantiate PE[i][j]
                PE #(
                    .B(B),
                    .C(C),
                    .A(A),
                    .QUANTIZED_WIDTH(QUANTIZED_WIDTH) // Pass consistent parameter name
                ) pe_inst (
                    .clk_i      (clk_i),
                    .reset_i    (reset_i),
                    // Data input comes from PE above (data_signals[i])
                    .data_i     (data_signals[i][j]),
                    // Weight input comes from PE to the left (weights_signals[j])
                    .weights_i  (weights_signals[i][j]),
                    // Data output goes to PE below (data_signals[i+1])
                    .data_o     (data_signals[i+1][j]),
                    // Weight output goes to PE to the right (weights_signals[j+1])
                    .weights_o  (weights_signals[i][j+1])
                );
            end
        end

        // --- Connect Grid Edges to STA Outputs ---
        // Connect the bottom edge data signals to the STA data output
        // data_signals[M][j] is the output from PE[M-1][j]
        for (j = 0; j < N; j = j + 1) begin : sta_data_output_connect
            assign data_o[j] = data_signals[M][j];
        end
        // Connect the right edge weight signals to the STA weight output
        // weights_signals[i][N] is the output from PE[i][N-1]
        for (i = 0; i < M; i = i + 1) begin : sta_weight_output_connect
            assign weights_o[i] = weights_signals[i][N];
        end

    endgenerate // End of main generate block

endmodule

