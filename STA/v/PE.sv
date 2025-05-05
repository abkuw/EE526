// Assuming DP.sv contains the corrected DP module with parameters B and QUANTIZED_WIDTH
`include "v/DP.sv"

// Define a simple registered buffer module locally or include from a separate file
module SimpleRegisteredBuffer #(
    parameter WIDTH = 8
) (
    input logic clk_i,
    input logic reset_i, // Active-high reset
    input logic [WIDTH-1:0] i,
    output logic [WIDTH-1:0] o
);

    // Use standard synchronous logic with reset
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            o <= '0; // Reset output to all zeros
        end else begin
            o <= i;  // Capture input on clock edge
        end
    end

endmodule


// Main PE Module
module PE #(
    parameter B = 4,
    parameter C = 2, // Columns of DPs within PE
    parameter A = 2, // Rows of DPs within PE
    parameter QUANTIZED_WIDTH = 8 // Renamed from quantized_size
) (
    input logic clk_i,
    input logic reset_i,

    // PE Inputs: Array of B*C data vectors, B*A weight vectors
    input logic signed [QUANTIZED_WIDTH-1:0] data_i   [B*C-1:0], // e.g., [7:0] elements for B=4, C=2
    input logic signed [QUANTIZED_WIDTH-1:0] weights_i[B*A-1:0], // e.g., [7:0] elements for B=4, A=2

    // PE Outputs: Array of B*C data vectors, B*A weight vectors
    output logic signed [QUANTIZED_WIDTH-1:0] data_o   [B*C-1:0],
    output logic signed [QUANTIZED_WIDTH-1:0] weights_o[B*A-1:0]
);

    // --- Sanity Checks ---
    // This specific implementation hardcodes a 2x2 DP structure
    initial begin
        if (A != 2 || C != 2) begin
            $fatal(1, "PE Instantiation Error: This PE implementation requires A=2 and C=2. Got A=%d, C=%d.", A, C);
        end
    end

    // --- Derived Parameters ---
    localparam DP_VECTOR_COUNT      = B;
    // Define the type for an array of B vectors, each QUANTIZED_WIDTH bits wide
    typedef logic signed [QUANTIZED_WIDTH-1:0] dp_vector_array_t [DP_VECTOR_COUNT-1:0];
    // Calculate the total width when this array is flattened into a single vector
    localparam DP_FLAT_ARRAY_WIDTH  = DP_VECTOR_COUNT * QUANTIZED_WIDTH;
    // Define the width of the accumulator result from the DP module
    localparam ACCUMULATOR_WIDTH    = 4 * QUANTIZED_WIDTH;

    // --- Internal Signals ---

    // Signals between DPs (Using the defined array type)
    dp_vector_array_t dp1_data_v_o;   // Data passed down from DP1
    dp_vector_array_t dp1_weight_h_o; // Weight passed right from DP1
    dp_vector_array_t dp2_data_v_o;   // Data passed down from DP2
    dp_vector_array_t dp2_weight_h_o; // Weight passed right from DP2 (to PE output buffer)
    dp_vector_array_t dp3_data_v_o;   // Data passed down from DP3 (to PE output buffer)
    dp_vector_array_t dp3_weight_h_o; // Weight passed right from DP3
    dp_vector_array_t dp4_data_v_o;   // Data passed down from DP4 (to PE output buffer)
    dp_vector_array_t dp4_weight_h_o; // Weight passed right from DP4 (to PE output buffer)

    // DP accumulator results (Correct type, although unused locally)
    logic signed [ACCUMULATOR_WIDTH-1:0] resultdp1, resultdp2, resultdp3, resultdp4;

    // --- DP Instantiations (2x2 Structure) ---

    // Row 1
    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP1 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(data_i[0 +: B]),          // Data input for DP1 (e.g., data_i[0..3])
        .weight_i(weights_i[0 +: B]),    // Weight input for DP1 (e.g., weights_i[0..3])
        .weight_h_o(dp1_weight_h_o),     // Weight out to DP2
        .data_v_o(dp1_data_v_o),         // Data out to DP3
        .result(resultdp1)
    );

    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP2 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(data_i[B +: B]),          // Data input for DP2 (e.g., data_i[4..7])
        .weight_i(dp1_weight_h_o),       // Weight input from DP1
        .weight_h_o(dp2_weight_h_o),     // Weight out right (buffered to weights_o[0..B-1])
        .data_v_o(dp2_data_v_o),         // Data out down to DP4
        .result(resultdp2)
    );

    // Row 2
    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP3 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(dp1_data_v_o),           // Data input from DP1
        .weight_i(weights_i[B +: B]),    // Weight input for DP3 (e.g., weights_i[4..7])
        .weight_h_o(dp3_weight_h_o),     // Weight out to DP4
        .data_v_o(dp3_data_v_o),         // Data out down (buffered to data_o[0..B-1])
        .result(resultdp3)
    );

    DP #( .B(B), .QUANTIZED_WIDTH(QUANTIZED_WIDTH) ) DP4 (
        .clk_i(clk_i), .reset_i(reset_i),
        .data_i(dp2_data_v_o),           // Data input from DP2
        .weight_i(dp3_weight_h_o),       // Weight input from DP3
        .weight_h_o(dp4_weight_h_o),     // Weight out right (buffered to weights_o[B..2B-1])
        .data_v_o(dp4_data_v_o),         // Data out down (buffered to data_o[B..2B-1])
        .result(resultdp4)
    );


    // --- Output Buffering using SimpleRegisteredBuffer ---

    // Signals for buffer inputs/outputs (flattened vectors)
    logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_w_out1_i, flat_buf_w_out1_o; // DP2 -> weights_o[0+:B]
    logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_d_out0_i, flat_buf_d_out0_o; // DP3 -> data_o[0+:B]
    logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_w_out0_i, flat_buf_w_out0_o; // DP4 -> weights_o[B+:B]
    logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_d_out1_i, flat_buf_d_out1_o; // DP4 -> data_o[B+:B]

    // Flatten DP outputs going to buffers (using bitstream casting)
    // The outputs from DPs are combinational or registered depending on DP internal logic.
    // We assume they are stable before the clock edge where the buffer captures them.
    
    assign flat_buf_w_out1_i = DP_FLAT_ARRAY_WIDTH'(dp2_weight_h_o); // Weights from DP2 (Right Top)
    assign flat_buf_d_out0_i = DP_FLAT_ARRAY_WIDTH'(dp3_data_v_o);    // Data from DP3 (Down Left)
    assign flat_buf_w_out0_i = DP_FLAT_ARRAY_WIDTH'(dp4_weight_h_o); // Weights from DP4 (Right Bottom)
    assign flat_buf_d_out1_i = DP_FLAT_ARRAY_WIDTH'(dp4_data_v_o);    // Data from DP4 (Down Right)

    // Instantiate Buffers (Pass flattened width, connect clock and reset)
    SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_weights_out_1 (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(flat_buf_w_out1_i), .o(flat_buf_w_out1_o) // Weights DP2 -> weights_o[0+:B]
    );
    SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_data_out_0 (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(flat_buf_d_out0_i), .o(flat_buf_d_out0_o) // Data DP3    -> data_o[0+:B]
    );
    SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_weights_out_0 (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(flat_buf_w_out0_i), .o(flat_buf_w_out0_o) // Weights DP4 -> weights_o[B+:B]
    );
    SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_data_out_1 (
        .clk_i(clk_i), .reset_i(reset_i),
        .i(flat_buf_d_out1_i), .o(flat_buf_d_out1_o) // Data DP4    -> data_o[B+:B]
    );

    // Unflatten buffer outputs and assign to PE outputs using correct slices
    // Assign weights output (from right column DP2 and DP4 buffers)
    assign weights_o[0 +: B] = dp_vector_array_t'(flat_buf_w_out1_o); // Unflatten DP2 weights buffer output
    assign weights_o[B +: B] = dp_vector_array_t'(flat_buf_w_out0_o); // Unflatten DP4 weights buffer output

    // Assign data output (from bottom row DP3 and DP4 buffers)
    assign data_o[0 +: B] = dp_vector_array_t'(flat_buf_d_out0_o); // Unflatten DP3 data buffer output
    assign data_o[B +: B] = dp_vector_array_t'(flat_buf_d_out1_o); // Unflatten DP4 data buffer output

    /*
	// Signals for buffer inputs/outputs (flattened vectors)
	logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_w_out1_i, flat_buf_w_out1_o; // DP2 -> weights_o[0+:B]
	logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_d_out0_i, flat_buf_d_out0_o; // DP3 -> data_o[0+:B]
	logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_w_out0_i, flat_buf_w_out0_o; // DP4 -> weights_o[B+:B]
	logic [DP_FLAT_ARRAY_WIDTH-1:0] flat_buf_d_out1_i, flat_buf_d_out1_o; // DP4 -> data_o[B+:B]

	// Flatten DP outputs going to buffers by concatenating individual elements
	// Instead of using casting, we'll use a generate block to create the proper concatenation
	genvar gv_i;
	generate
		 for (gv_i = 0; gv_i < B; gv_i++) begin : flatten_arrays
			  // Each array element is QUANTIZED_WIDTH bits, placed at the right position in the flattened vector
			  assign flat_buf_w_out1_i[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH] = dp2_weight_h_o[gv_i];
			  assign flat_buf_d_out0_i[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH] = dp3_data_v_o[gv_i];
			  assign flat_buf_w_out0_i[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH] = dp4_weight_h_o[gv_i];
			  assign flat_buf_d_out1_i[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH] = dp4_data_v_o[gv_i];
		 end
	endgenerate

	// Instantiate Buffers (Pass flattened width, connect clock and reset)
	SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_weights_out_1 (
		 .clk_i(clk_i), .reset_i(reset_i),
		 .i(flat_buf_w_out1_i), .o(flat_buf_w_out1_o) // Weights DP2 -> weights_o[0+:B]
	);
	SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_data_out_0 (
		 .clk_i(clk_i), .reset_i(reset_i),
		 .i(flat_buf_d_out0_i), .o(flat_buf_d_out0_o) // Data DP3    -> data_o[0+:B]
	);
	SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_weights_out_0 (
		 .clk_i(clk_i), .reset_i(reset_i),
		 .i(flat_buf_w_out0_i), .o(flat_buf_w_out0_o) // Weights DP4 -> weights_o[B+:B]
	);
	SimpleRegisteredBuffer #( .WIDTH(DP_FLAT_ARRAY_WIDTH) ) buf_data_out_1 (
		 .clk_i(clk_i), .reset_i(reset_i),
		 .i(flat_buf_d_out1_i), .o(flat_buf_d_out1_o) // Data DP4    -> data_o[B+:B]
	);

	// Unflatten buffer outputs back into arrays
	generate
		 for (gv_i = 0; gv_i < B; gv_i++) begin : unflatten_arrays
			  // Each array element is extracted from the flattened vector
			  assign weights_o[0 + gv_i] = flat_buf_w_out1_o[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH];
			  assign data_o[0 + gv_i] = flat_buf_d_out0_o[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH];
			  assign weights_o[B + gv_i] = flat_buf_w_out0_o[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH];
			  assign data_o[B + gv_i] = flat_buf_d_out1_o[(gv_i+1)*QUANTIZED_WIDTH-1 : gv_i*QUANTIZED_WIDTH];
		 end
	endgenerate
    */
endmodule
