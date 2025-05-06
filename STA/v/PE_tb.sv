// File: pe_tb.sv (Testbench for the PE module)
// `include "v/PE.sv" // Assumes PE.sv is available

// Abhishek Kumar, Keith Phou
// EE 526

// Testbench for the PE (Processing Element) module
module PE_tb;
    // Define parameters
    localparam int B = 4;                 // Number of parallel multipliers per DP
    // A and C are implicitly 2 in the PE design being tested
    localparam int A = 2;                 // Rows of DPs within PE (for array sizing)
    localparam int C = 2;                 // Columns of DPs within PE (for array sizing)
    localparam int QUANTIZED_WIDTH = 8;   // Bit-width of input data/weights
    localparam int RESULT_WIDTH = 4*QUANTIZED_WIDTH; // Width of accumulator (not checked here)
    localparam int PE_LATENCY = 4;        // Expected latency (DP reg + DP reg + Buffer reg + Output assign)

    // Define signals
    logic                           clk;
    logic                           reset;
    logic signed [QUANTIZED_WIDTH-1:0] data_i[B*C-1:0];    // 8 inputs for B=4, C=2
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[B*A-1:0]; // 8 inputs for B=4, A=2
    logic signed [QUANTIZED_WIDTH-1:0] data_o[B*C-1:0];    // 8 outputs
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[B*A-1:0]; // 8 outputs

    // Expected output signals for validation
    logic signed [QUANTIZED_WIDTH-1:0] expected_data_o[B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] expected_weights_o[B*A-1:0];

    // Arrays for Test 5
    logic signed [QUANTIZED_WIDTH-1:0] random_data[B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] random_weights[B*A-1:0];

    // Arrays for Test 9
    logic signed [QUANTIZED_WIDTH-1:0] input_data_1[B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] input_weights_1[B*A-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] input_data_2[B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] input_weights_2[B*A-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] input_data_3[B*C-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] input_weights_3[B*A-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] input_data_4[B*C-1:0]; // Added for clarity in Test 9
    logic signed [QUANTIZED_WIDTH-1:0] input_weights_4[B*A-1:0]; // Added for clarity in Test 9

    // Define the seed for random number generation
    int seed;

    // Instantiate the PE (device under test)
    // Ensure this instantiation matches the PE module being tested
    // (e.g., pe_module_2x2_type_param_buffer)
    PE #(
        .B(B),
        .A(A), // Pass A and C if the PE module expects them
        .C(C),
        .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
    ) dut (
        .clk_i(clk),
        .reset_i(reset),
        .data_i(data_i),
        .weights_i(weights_i),
        .data_o(data_o),
        .weights_o(weights_o)
    );

    // Clock generation
    parameter clock_period = 5; // Use ns timescale
    initial begin
        clk = 0;
        forever #(clock_period/2) clk = ~clk;
    end

    // Helper function to print array values
    function automatic void print_arrays(
        string test_name,
        logic signed [QUANTIZED_WIDTH-1:0] data[B*C-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] weights[B*A-1:0]
    );
        $write("%s: data = [", test_name);
        for (int i = 0; i < B*C; i++) begin
            $write("%d", $signed(data[i]));
            if (i < B*C-1) $write(", ");
        end
        $write("], weights = [");
        for (int i = 0; i < B*A; i++) begin
            $write("%d", $signed(weights[i]));
            if (i < B*A-1) $write(", ");
        end
        $write("]\n");
    endfunction

    // Helper function to print output arrays
    function automatic void print_output_arrays(
        string test_name,
        logic signed [QUANTIZED_WIDTH-1:0] data[B*C-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] weights[B*A-1:0]
    );
        $write("%s: data_o = [", test_name);
        for (int i = 0; i < B*C; i++) begin
            $write("%d", $signed(data[i]));
            if (i < B*C-1) $write(", ");
        end
        $write("], weights_o = [");
        for (int i = 0; i < B*A; i++) begin
            $write("%d", $signed(weights[i]));
            if (i < B*A-1) $write(", ");
        end
        $write("]\n");
    endfunction

    // Helper function to print expected vs. actual outputs
    function automatic void verify_outputs(
        string test_name,
        logic signed [QUANTIZED_WIDTH-1:0] actual_data[B*C-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] expected_data[B*C-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] actual_weights[B*A-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] expected_weights[B*A-1:0]
    );
        bit data_match = 1;
        bit weights_match = 1;

        // Check data outputs
        for (int i = 0; i < B*C; i++) begin
            if (actual_data[i] !== expected_data[i]) begin
                data_match = 0;
                $error("%s: Data mismatch at index %0d. Expected %d, Got %d", test_name, i, expected_data[i], actual_data[i]);
                // break; // Optional: stop checking on first mismatch
            end
        end

        // Check weight outputs
        for (int i = 0; i < B*A; i++) begin
            if (actual_weights[i] !== expected_weights[i]) begin
                weights_match = 0;
                 $error("%s: Weight mismatch at index %0d. Expected %d, Got %d", test_name, i, expected_weights[i], actual_weights[i]);
                // break; // Optional: stop checking on first mismatch
            end
        end

        // Print verification results
        if (data_match && weights_match) begin
            $display("%s: PASS - All outputs match expected values", test_name);
        end else begin
            $display("%s: FAIL - Output mismatch detected (see $error messages above)", test_name);
        end
    endfunction

    initial begin
        // Initialize signals
        reset = 1;
        seed = 42; // Initialize the seed here

        for (int i = 0; i < B*C; i++) begin
            data_i[i] = 0;
            expected_data_o[i] = 0;
            random_data[i] = 0;
            input_data_1[i] = 0; input_data_2[i] = 0; input_data_3[i] = 0; input_data_4[i] = 0;
        end
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = 0;
            expected_weights_o[i] = 0;
            random_weights[i] = 0;
            input_weights_1[i] = 0; input_weights_2[i] = 0; input_weights_3[i] = 0; input_weights_4[i] = 0;
        end

        // Test 1: Reset active
        @(posedge clk); // Wait for first edge
        $display("Test 1: Reset active");
        @(posedge clk);
        verify_outputs("Test 1", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 2: Release reset
        reset = 0;
        @(posedge clk); // Let reset deassertion propagate
        $display("Test 2: Reset inactive");
        verify_outputs("Test 2", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 3: Basic data flow - simple values
        $display("Test 3: Basic data flow");
        for (int i = 0; i < B*C; i++) data_i[i] = i + 1;
        for (int i = 0; i < B*A; i++) weights_i[i] = i + 1;
        print_arrays("Test 3 inputs", data_i, weights_i);

        // Wait for data to propagate through the PE array (4 cycles)
        repeat(PE_LATENCY) @(posedge clk); // FIX: Wait 4 cycles

        // Expected outputs after 4 clock cycles:
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = i + 1;
            expected_data_o[i+B] = i + 1 + B;
            expected_weights_o[i] = i + 1;
            expected_weights_o[i+B] = i + 1 + B;
        end
        print_output_arrays("Test 3 outputs", data_o, weights_o);
        verify_outputs("Test 3", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 4: Alternating positive/negative values
        $display("Test 4: Alternating values");
        for (int i = 0; i < B*C; i++) data_i[i] = (i % 2 == 0) ? 10 : -10;
        for (int i = 0; i < B*A; i++) weights_i[i] = (i % 2 == 0) ? 5 : -5;
        print_arrays("Test 4 inputs", data_i, weights_i);

        // Wait for propagation (4 cycles)
        repeat(PE_LATENCY) @(posedge clk); // FIX: Wait 4 cycles

        // Expected alternating pattern after propagation
        for (int i = 0; i < B*C; i++) expected_data_o[i] = (i % 2 == 0) ? 10 : -10;
        for (int i = 0; i < B*A; i++) expected_weights_o[i] = (i % 2 == 0) ? 5 : -5;
        print_output_arrays("Test 4 outputs", data_o, weights_o);
        verify_outputs("Test 4", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 5: Random values within INT8 range
        $display("Test 5: Random values");
        for (int i = 0; i < B*C; i++) begin data_i[i] = $random(seed) % 256 - 128; random_data[i] = data_i[i]; end
        for (int i = 0; i < B*A; i++) begin weights_i[i] = $random(seed) % 256 - 128; random_weights[i] = weights_i[i]; end
        print_arrays("Test 5 inputs", data_i, weights_i);

        // Wait for propagation (4 cycles)
        repeat(PE_LATENCY) @(posedge clk); // FIX: Wait 4 cycles

        // Set expected outputs based on the random inputs
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = random_data[i];
            expected_data_o[i+B] = random_data[i+B];
            expected_weights_o[i] = random_weights[i];
            expected_weights_o[i+B] = random_weights[i+B];
        end
        print_output_arrays("Test 5 outputs", data_o, weights_o);
        verify_outputs("Test 5", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 6: Maximum values test
        $display("Test 6: Maximum values");
        for (int i = 0; i < B*C; i++) data_i[i] = 127;
        for (int i = 0; i < B*A; i++) weights_i[i] = 127;
        print_arrays("Test 6 inputs", data_i, weights_i);

        repeat(PE_LATENCY) @(posedge clk); // FIX: Wait 4 cycles

        for (int i = 0; i < B*C; i++) expected_data_o[i] = 127;
        for (int i = 0; i < B*A; i++) expected_weights_o[i] = 127;
        print_output_arrays("Test 6 outputs", data_o, weights_o);
        verify_outputs("Test 6", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 7: Minimum values test
        $display("Test 7: Minimum values");
        for (int i = 0; i < B*C; i++) data_i[i] = -128;
        for (int i = 0; i < B*A; i++) weights_i[i] = -128;
        print_arrays("Test 7 inputs", data_i, weights_i);

        repeat(PE_LATENCY) @(posedge clk); // FIX: Wait 4 cycles

        for (int i = 0; i < B*C; i++) expected_data_o[i] = -128;
        for (int i = 0; i < B*A; i++) expected_weights_o[i] = -128;
        print_output_arrays("Test 7 outputs", data_o, weights_o);
        verify_outputs("Test 7", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 8: Reset during operation
        $display("Test 8: Reset during operation");
        for (int i = 0; i < B*C; i++) data_i[i] = i * 2;
        for (int i = 0; i < B*A; i++) weights_i[i] = i * 3;
        print_arrays("Test 8 inputs", data_i, weights_i);

        @(posedge clk); // Let one cycle run
        reset = 1;      // Assert reset
        @(posedge clk); // Let reset take effect

        // After reset, all outputs should be zero
        for (int i = 0; i < B*C; i++) expected_data_o[i] = 0;
        for (int i = 0; i < B*A; i++) expected_weights_o[i] = 0;
        print_output_arrays("Test 8 outputs (after reset)", data_o, weights_o);
        verify_outputs("Test 8", data_o, expected_data_o, weights_o, expected_weights_o);

        // Test 9: Verify systolic data flow with consecutive different inputs
        $display("Test 9: Systolic data flow");
        reset = 0;      // Deassert reset
        @(posedge clk); // Wait one cycle

        // --- Cycle 1 --- Apply Input Set 1
        for (int i = 0; i < B*C; i++) data_i[i] = i + 1;
        for (int i = 0; i < B*A; i++) weights_i[i] = 10 + i;
        for (int i = 0; i < B*C; i++) input_data_1[i] = data_i[i];
        for (int i = 0; i < B*A; i++) input_weights_1[i] = weights_i[i];
        print_arrays("Test 9.1 inputs", data_i, weights_i);
        @(posedge clk);

        // --- Cycle 2 --- Apply Input Set 2
        for (int i = 0; i < B*C; i++) data_i[i] = 20 + i;
        for (int i = 0; i < B*A; i++) weights_i[i] = 30 + i;
        for (int i = 0; i < B*C; i++) input_data_2[i] = data_i[i];
        for (int i = 0; i < B*A; i++) input_weights_2[i] = weights_i[i];
        print_arrays("Test 9.2 inputs", data_i, weights_i);
        @(posedge clk);

        // --- Cycle 3 --- Apply Input Set 3
        for (int i = 0; i < B*C; i++) data_i[i] = 40 + i;
        for (int i = 0; i < B*A; i++) weights_i[i] = 50 + i;
        for (int i = 0; i < B*C; i++) input_data_3[i] = data_i[i];
        for (int i = 0; i < B*A; i++) input_weights_3[i] = weights_i[i];
        print_arrays("Test 9.3 inputs", data_i, weights_i);
        @(posedge clk);

        // --- Cycle 4 --- Apply Input Set 4 (or hold last input)
        for (int i = 0; i < B*C; i++) data_i[i] = 60 + i; // Example: Apply another set
        for (int i = 0; i < B*A; i++) weights_i[i] = 70 + i;
        for (int i = 0; i < B*C; i++) input_data_4[i] = data_i[i];
        for (int i = 0; i < B*A; i++) input_weights_4[i] = weights_i[i];
        print_arrays("Test 9.4 inputs", data_i, weights_i);
        @(posedge clk);

        // --- Cycle 4 End: Check Output (Input Set 1 expected) --- FIX: Check after 4 cycles
        $display("Test 9 - Checking after 4 cycles (Input Set 1 expected):");
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = input_data_1[i];
            expected_data_o[i+B] = input_data_1[i+B];
            expected_weights_o[i] = input_weights_1[i];
            expected_weights_o[i+B] = input_weights_1[i+B];
        end
        print_output_arrays("Test 9.4 outputs", data_o, weights_o);
        verify_outputs("Test 9.4", data_o, expected_data_o, weights_o, expected_weights_o);

        // --- Cycle 5 End: Check Output (Input Set 2 expected) --- FIX: Check after 5 cycles
        @(posedge clk);
        $display("Test 9 - Checking after 5 cycles (Input Set 2 expected):");
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = input_data_2[i];
            expected_data_o[i+B] = input_data_2[i+B];
            expected_weights_o[i] = input_weights_2[i];
            expected_weights_o[i+B] = input_weights_2[i+B];
        end
        print_output_arrays("Test 9.5 outputs", data_o, weights_o);
        verify_outputs("Test 9.5", data_o, expected_data_o, weights_o, expected_weights_o);

        // --- Cycle 6 End: Check Output (Input Set 3 expected) --- FIX: Check after 6 cycles
        @(posedge clk);
        $display("Test 9 - Checking after 6 cycles (Input Set 3 expected):");
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = input_data_3[i];
            expected_data_o[i+B] = input_data_3[i+B];
            expected_weights_o[i] = input_weights_3[i];
            expected_weights_o[i+B] = input_weights_3[i+B];
        end
        print_output_arrays("Test 9.6 outputs", data_o, weights_o);
        verify_outputs("Test 9.6", data_o, expected_data_o, weights_o, expected_weights_o);


        $display("All tests completed!");
        $finish;
    end
endmodule
