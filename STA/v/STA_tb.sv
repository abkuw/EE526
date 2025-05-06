// File: sta_tb.sv
// Testbench for the Systolic Tensor Array (STA) with Concatenated Result Check
`timescale 1ns / 1ps

// Include the STA module definition
`include "v/STA.sv" // Assumes STA.sv has concatenated result_o port and uses compatible PE

module sta_tb;
    // --- Parameters ---
    localparam int N = 2;                   // Number of PE columns (Reduced for testing)
    localparam int M = 2;                   // Number of PE rows (Reduced for testing)
    localparam int B = 4;                   // Number of parallel multipliers per DP
    localparam int A = 2;                   // Rows of DPs within PE (Implicit in PE)
    localparam int C = 2;                   // Columns of DPs within PE (Implicit in PE)
    localparam int QUANTIZED_WIDTH = 8;     // Bit-width of input data/weights
    localparam int PE_LATENCY = 4;          // Latency of one PE (determined from pe_tb)
    localparam int ACCUMULATOR_WIDTH = 4 * QUANTIZED_WIDTH; // Width of single DP result
    localparam int PE_RESULT_WIDTH = 4 * ACCUMULATOR_WIDTH; // Width of concatenated PE result (4 * 32 = 128 bits)

    // Clock Period
    localparam int CLK_PERIOD = 10; // ns

    // Derived Latencies for STA
    localparam int STA_DATA_LATENCY = M * PE_LATENCY;    // Cycles for data_i to reach data_o
    localparam int STA_WEIGHT_LATENCY = N * PE_LATENCY;  // Cycles for weights_i to reach weights_o
    // Result latency depends on accumulation, use max propagation for check timing
    localparam int STA_MAX_LATENCY = (STA_DATA_LATENCY > STA_WEIGHT_LATENCY) ? STA_DATA_LATENCY : STA_WEIGHT_LATENCY;
    localparam int CHECK_DELAY = STA_MAX_LATENCY + 2; // Add margin for result stability

    // --- Testbench Signals ---
    logic clk;
    logic reset;

    // STA Inputs (Matching STA module ports - 1D inner dimension)
    logic signed [QUANTIZED_WIDTH-1:0] tb_data_i   [N-1:0][2*B-1:0];    // [N][2B]
    logic signed [QUANTIZED_WIDTH-1:0] tb_weights_i[M-1:0][2*B-1:0];    // [M][2B]

    // STA Outputs (Matching STA module ports - 1D inner dimension)
    logic signed [QUANTIZED_WIDTH-1:0] dut_data_o   [N-1:0][2*B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] dut_weights_o[M-1:0][2*B-1:0];
    logic signed [PE_RESULT_WIDTH-1:0] dut_result_o [M-1:0][N-1:0]; // Added Result Output (Wide)

    // Expected output arrays for validation (Matching output ports)
    logic signed [QUANTIZED_WIDTH-1:0] expected_data_o   [N-1:0][2*B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] expected_weights_o[M-1:0][2*B-1:0];
    logic signed [PE_RESULT_WIDTH-1:0] expected_result_o [M-1:0][N-1:0]; // Added Expected Result (Wide)

    // --- Instantiate the STA module ---
    STA #(
        .N(N),
        .M(M),
        .B(B),
        // A and C are implicit in the PE used by this STA version
        .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
    ) dut (
        .clk_i(clk),
        .reset_i(reset),
        .data_i(tb_data_i),
        .weights_i(tb_weights_i),
        .data_o(dut_data_o),
        .weights_o(dut_weights_o),
        .result_o(dut_result_o) // Connect result port
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Helper Functions ---

    // Initialize all test arrays to zero
    function automatic void initialize_arrays();
        tb_data_i = '{default: '{default: '0}};
        tb_weights_i = '{default: '{default: '0}};
        expected_data_o = '{default: '{default: '0}};
        expected_weights_o = '{default: '{default: '0}};
        expected_result_o = '{default: '{default: '0}}; // Initialize expected result
    endfunction

    // Print 1D data array slice (for one column/row)
    function automatic void print_1d_array(string name, logic signed [QUANTIZED_WIDTH-1:0] arr[2*B-1:0]);
        $write("%s: [", name);
        for (int i = 0; i < 2*B; i++) begin
            $write("%4d", $signed(arr[i]));
            if (i < 2*B-1) $write(", ");
        end
        $write("]");
    endfunction

    // Print Result array (MxN) - Displaying as Hex for wide values
     function automatic void print_result_array(string name, logic signed [PE_RESULT_WIDTH-1:0] arr[M-1:0][N-1:0]);
        $display("Array %s:", name);
        for (int i = 0; i < M; i++) begin
             $write("  Row %0d: [", i);
            for (int j = 0; j < N; j++) begin
                 $write("0x%0h", arr[i][j]); // Display wide result as hex
                 if (j < N-1) $write(", ");
            end
            $write("]\n");
        end
    endfunction


    // Load test patterns into the 1D input arrays
    function automatic void load_test_pattern(int pattern_num);
        initialize_arrays(); // Start fresh
        int counter;
        int idx;

        case (pattern_num)
            // Pattern 1: Sequential values
            1: begin
                counter = 1;
                for (int n = 0; n < N; n++) for (int i = 0; i < 2*B; i++) tb_data_i[n][i] = counter++;
                counter = 1; // Use simple weights for easier result prediction
                for (int m = 0; m < M; m++) for (int i = 0; i < 2*B; i++) tb_weights_i[m][i] = 1; // All weights = 1
            end
            // Pattern 2: Constant values
            2: begin
                 tb_data_i = '{default: '{default: 5}};
                 tb_weights_i = '{default: '{default: 2}};
            end
            // Pattern 3: Max values
            3: begin
                 tb_data_i = '{default: '{default: 127}};
                 tb_weights_i = '{default: '{default: 1}}; // Use weight=1 for max test
            end
             // Pattern 4: Min values
            4: begin
                 tb_data_i = '{default: '{default: -128}};
                 tb_weights_i = '{default: '{default: 1}}; // Use weight=1 for min test
            end
            default: $display("Error: Invalid test pattern number: %0d", pattern_num);
        endcase
    endfunction

    // Set expected outputs based on input pattern (simple propagation for data/weights)
    // Expected result is NOT calculated here, only checked for non-zero or zero after reset/flush
    function automatic void set_expected_outputs(int pattern_num);
        int counter;
        int idx;
        expected_result_o = '{default: '{default: 'X}}; // Default: Don't care about exact result value

        case (pattern_num)
            1: begin // Sequential data, weight=1
                counter = 1;
                for (int n = 0; n < N; n++) for (int i = 0; i < 2*B; i++) expected_data_o[n][i] = counter++;
                for (int m = 0; m < M; m++) for (int i = 0; i < 2*B; i++) expected_weights_o[m][i] = 1;
            end
            2: begin // Constant values (5, 2)
                expected_data_o = '{default: '{default: 5}};
                expected_weights_o = '{default: '{default: 2}};
            end
            3: begin // Max values (127, 1)
                expected_data_o = '{default: '{default: 127}};
                expected_weights_o = '{default: '{default: 1}};
            end
             4: begin // Min values (-128, 1)
                expected_data_o = '{default: '{default: -128}};
                expected_weights_o = '{default: '{default: 1}};
            end
            default: $display("Error: Invalid pattern number for expected: %0d", pattern_num);
        endcase
    endfunction

    // Verify outputs against expected values
    function automatic bit verify_outputs(string test_name, bit check_result_exact = 0);
        bit match = 1;
        // Verify data outputs
        for (int n = 0; n < N; n++) begin
            for (int i = 0; i < 2*B; i++) begin
                if (dut_data_o[n][i] !== expected_data_o[n][i]) begin
                    match = 0;
                    $error("%s: Data mismatch at data_o[%0d][%0d]: Expected %d, Got %d",
                             test_name, n, i, $signed(expected_data_o[n][i]), $signed(dut_data_o[n][i]));
                end
            end
        end
        // Verify weight outputs
        for (int m = 0; m < M; m++) begin
            for (int i = 0; i < 2*B; i++) begin
                if (dut_weights_o[m][i] !== expected_weights_o[m][i]) begin
                    match = 0;
                    $error("%s: Weight mismatch at weights_o[%0d][%0d]: Expected %d, Got %d",
                             test_name, m, i, $signed(expected_weights_o[m][i]), $signed(dut_weights_o[m][i]));
                end
            end
        end
        // Verify result outputs
        for (int m = 0; m < M; m++) begin
             for (int n = 0; n < N; n++) begin
                 if (check_result_exact) begin // Check exact value if requested (e.g., for reset/flush)
                     if (dut_result_o[m][n] !== expected_result_o[m][n]) begin
                         match = 0;
                         $error("%s: Result mismatch at result_o[%0d][%0d]: Expected 0x%h, Got 0x%h",
                                  test_name, m, n, expected_result_o[m][n], dut_result_o[m][n]);
                     end
                 end else begin // Otherwise, just check if it's non-zero when expected
                     if (expected_result_o[m][n] !== 'X && dut_result_o[m][n] === 0) begin
                         // If we expected something (non-'X') but got 0, it's likely an error
                         // (unless the actual expected result *is* 0, which we aren't calculating here)
                         $display("%s: Info: result_o[%0d][%0d] is 0. Expected non-zero based on inputs.", test_name, m, n);
                     end else if (dut_result_o[m][n] !== 0) begin
                         $display("%s: Info: result_o[%0d][%0d] = 0x%h (Non-zero)", test_name, m, n, dut_result_o[m][n]);
                     end
                 end
             end
        end

        if(match) $display("%s: PASS", test_name);
        else $display("%s: FAIL", test_name);
        return match;
    endfunction

    // --- Main Test Sequence ---
    initial begin
        $display("--- STA Testbench Started (N=%0d, M=%0d, PE_LATENCY=%0d) ---", N, M, PE_LATENCY);
        $display("--- Expected STA Data Latency: %0d cycles ---", STA_DATA_LATENCY);
        $display("--- Expected STA Weight Latency: %0d cycles ---", STA_WEIGHT_LATENCY);

        // 1. Reset Test
        reset = 1;
        initialize_arrays(); // Zeros expected arrays
        @(posedge clk);
        $display("\n=== Test 1: Reset active ===");
        @(posedge clk);
        verify_outputs("Test 1.1 (During Reset)", 1); // Check results are exactly 0

        reset = 0;
        @(posedge clk);
        $display("\n=== Test 1: Reset released ===");
        verify_outputs("Test 1.2 (After Reset)", 1); // Still expect zero for all outputs

        // --- Test Propagation ---
        // Loop through different patterns
        for (int pattern = 1; pattern <= 4; pattern++) begin
            $display("\n=== Test Pattern %0d ===", pattern);
            load_test_pattern(pattern);
            set_expected_outputs(pattern); // Sets expected data/weights

            $display("[%0t] Inputs loaded:", $time);
            print_1d_array($sformatf("  data_i[0]   "), tb_data_i[0]); $display();
            print_1d_array($sformatf("  weights_i[0]"), tb_weights_i[0]); $display();

            $display("[%0t] Waiting %0d cycles for propagation...", $time, CHECK_DELAY);
            repeat (CHECK_DELAY) @(posedge clk);

            $display("[%0t] Checking outputs:", $time);
            print_1d_array($sformatf("  data_o[0]   "), dut_data_o[0]); $display();
            print_1d_array($sformatf("  weights_o[0]"), dut_weights_o[0]); $display();
            // Print results as well
            print_result_array("dut_result_o", dut_result_o);

            // Verify propagation of data/weights
            // Result verification is basic (expects non-zero if inputs non-zero)
            verify_outputs($sformatf("Test Pattern %0d", pattern), 0); // Don't check exact result

            // Apply zeros to flush
            initialize_arrays(); // Set inputs to zero
            $display("[%0t] Flushing array with zeros...", $time);
            repeat (CHECK_DELAY + 5) @(posedge clk); // Wait for zeros to propagate + extra margin

            // Verify flush (expect all outputs zero)
            $display("[%0t] Checking outputs after flush:", $time);
            expected_data_o = '{default:'{default:0}};
            expected_weights_o = '{default:'{default:0}};
            expected_result_o = '{default:'{default:0}}; // Accumulators should also clear
            verify_outputs($sformatf("Test Pattern %0d Flush", pattern), 1); // Check results are exactly 0

        end

        // Test Reset During Operation
        $display("\n=== Test Reset During Operation ===");
        load_test_pattern(1); // Load some data
        @(posedge clk);
        @(posedge clk);
        reset = 1; // Assert reset mid-operation
        @(posedge clk);
        @(posedge clk);
        $display("[%0t] Reset asserted mid-operation, checking outputs...", $time);
        expected_data_o = '{default:'{default:0}}; // Expect zero
        expected_weights_o = '{default:'{default:0}};
        expected_result_o = '{default:'{default:0}};
        verify_outputs("Test Reset Mid-Op", 1); // Check results are exactly 0
        reset = 0; // Deassert reset
        @(posedge clk);


        $display("\n=== All tests completed! ===");
        $finish;
    end
endmodule
