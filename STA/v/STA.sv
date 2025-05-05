// File: STA.sv
// STA Module (Compatible with Hardcoded 2x2 PE using 1D ports)
`include "v/PE.sv" // Assumes PE.sv is the version compatible with pe_tb

// Systolic Tensor Array (STA) Module - M x N grid of PEs
module STA #(
    parameter N = 32, // Number of PE columns
    parameter M = 32, // Number of PE rows
    // Parameters passed down to the PE module
    parameter B = 4,
    // A and C are implicitly 2 for the hardcoded PE, so not needed here
    parameter QUANTIZED_WIDTH = 8 // Consistent parameter name
)(
    input logic clk_i,
    input logic reset_i,

    // STA Inputs: Need to match the structure expected by the PE inputs
    // Data input for N columns. Each PE takes [2*B-1:0] vectors.
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [N-1:0][2*B-1:0],
    // Weight input for M rows. Each PE takes [2*B-1:0] vectors.
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][2*B-1:0],

    // STA Outputs: Need to match the structure provided by the PE outputs
    // Data output from N columns. Each PE provides [2*B-1:0] vectors.
    output logic signed [QUANTIZED_WIDTH-1:0] data_o   [N-1:0][2*B-1:0],
    // Weight output from M rows. Each PE provides [2*B-1:0] vectors.
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][2*B-1:0]
);

    // --- Define Type for PE Port Compatibility ---
    // Type matching the 1D unpacked array ports of the hardcoded PE
    typedef logic signed [QUANTIZED_WIDTH-1:0] pe_port_array_t [2*B-1:0];

    // --- Internal Signal Arrays for Inter-PE Connections ---
    // Use the defined type for signals connecting PEs
    // data_signals connects PE outputs vertically. data_signals[i][j] is output from PE[i-1][j] and input to PE[i][j].
    pe_port_array_t data_signals   [M:0][N-1:0];
    // weights_signals connects PE outputs horizontally. weights_signals[i][j] is output from PE[i][j-1] and input to PE[i][j].
    pe_port_array_t weights_signals[M-1:0][N:0];


    // --- Generate the MxN Grid of PEs ---
    genvar i, j; // Row (M) and Column (N) iterators

    generate
        // --- Connect STA Inputs to the Grid Edges ---
        // Connect STA data inputs to the top edge (input to row 0 PEs)
        for (j = 0; j < N; j = j + 1) begin : sta_data_input_connect
            assign data_signals[0][j] = data_i[j];
        end
        // Connect STA weight inputs to the left edge (input to column 0 PEs)
        for (i = 0; i < M; i = i + 1) begin : sta_weight_input_connect
            assign weights_signals[i][0] = weights_i[i];
        end

        // --- Instantiate the MxN PE Grid ---
        for (i = 0; i < M; i = i + 1) begin : row_gen
            for (j = 0; j < N; j = j + 1) begin : col_gen
                // Instantiate PE[i][j] - A and C parameters removed/implicit
                PE #(
                    .B(B),
                    .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
                    // A=2, C=2 are implicit in the PE design
                ) pe_inst (
                    .clk_i      (clk_i),
                    .reset_i    (reset_i),
                    // Connect the compatible 1D array type signals
                    .data_i     (data_signals[i][j]),
                    .weights_i  (weights_signals[i][j]),
                    .data_o     (data_signals[i+1][j]),
                    .weights_o  (weights_signals[i][j+1])
                );
            end
        end

        // --- Connect Grid Edges to STA Outputs ---
        // Connect the bottom edge data signals to the STA data output
        for (j = 0; j < N; j = j + 1) begin : sta_data_output_connect
            assign data_o[j] = data_signals[M][j];
        end
        // Connect the right edge weight signals to the STA weight output
        for (i = 0; i < M; i = i + 1) begin : sta_weight_output_connect
            assign weights_o[i] = weights_signals[i][N];
        end

    endgenerate // End of main generate block

endmodule
