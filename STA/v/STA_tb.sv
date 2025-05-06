// File: sta_tb.sv
// Testbench for the Systolic Tensor Array (STA)
`timescale 1ns / 1ps

// Include the STA module definition
`include "v/STA.sv" // Assumes STA.sv is the version with concatenated result_o port

module STA_tb;
    // Define test parameters - using smaller dimensions for simulation
    localparam int N = 2;                   // Number of PE columns
    localparam int M = 2;                   // Number of PE rows
    localparam int B = 4;                   // Number of parallel multipliers per DP
    localparam int A = 2;                   // Rows of DPs within PE
    localparam int C = 2;                   // Columns of DPs within PE
    localparam int QUANTIZED_WIDTH = 8;     // Bit-width of input data/weights
    localparam int PE_ACCUMULATOR_WIDTH = 4 * QUANTIZED_WIDTH; // Width of one DP's accumulator
    localparam int PE_CONCAT_RESULT_WIDTH = 4 * PE_ACCUMULATOR_WIDTH; // Width of PE's concatenated result_o

    // Clock Period
    localparam int CLK_PERIOD = 10; // ns

    // Estimated PE latency (from pe_tb, assuming 4 cycles for pass-through)
    localparam int PE_LATENCY = 4;
    // STA Latency Estimation (rough, for propagation checks)
    localparam int STA_PROP_LATENCY = (M + N -1) * PE_LATENCY + 1; // Longest path + final reg
    localparam int CHECK_DELAY = STA_PROP_LATENCY + 2; // Add margin for result stability // Increased from STA_MAX_LATENCY

    // --- Testbench Signals ---
    logic clk;
    logic reset;

    // STA Inputs
    logic signed [QUANTIZED_WIDTH-1:0] data_i[N-1:0][C-1:0][B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][A-1:0][B-1:0];

    // STA Outputs
    logic signed [QUANTIZED_WIDTH-1:0] data_o[N-1:0][C-1:0][B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][A-1:0][B-1:0];
    logic signed [PE_CONCAT_RESULT_WIDTH-1:0] dut_result_o[M-1:0][N-1:0]; // Corrected type

    // Expected output arrays for validation
    logic signed [QUANTIZED_WIDTH-1:0] expected_data_o[N-1:0][C-1:0][B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] expected_weights_o[M-1:0][A-1:0][B-1:0];
    logic signed [PE_CONCAT_RESULT_WIDTH-1:0] expected_result_o[M-1:0][N-1:0]; // Corrected type

    // --- Instantiate the STA (device under test) ---
    STA #(
        .N(N),
        .M(M),
        .B(B),
        .A(A),
        .C(C),
        .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
    ) dut (
        .clk_i(clk),
        .reset_i(reset),
        .data_i(data_i),
        .weights_i(weights_i),
        .data_o(data_o),
        .weights_o(weights_o),
        .result_o(dut_result_o) // Connect result_o
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- Helper Functions ---

    // Initialize all test arrays to zero
    function automatic void initialize_arrays();
        for (int n_idx = 0; n_idx < N; n_idx++)
            for (int c_idx = 0; c_idx < C; c_idx++)
                for (int b_idx = 0; b_idx < B; b_idx++)
                    data_i[n_idx][c_idx][b_idx] = 0;
        expected_data_o = data_i;

        for (int m_idx = 0; m_idx < M; m_idx++)
            for (int a_idx = 0; a_idx < A; a_idx++)
                for (int b_idx = 0; b_idx < B; b_idx++)
                    weights_i[m_idx][a_idx][b_idx] = 0;
        expected_weights_o = weights_i;

        // Initialize expected_result_o to 'X (don't care) by default
        // Specific tests (like reset) will override this if they expect 0.
        for (int m_idx = 0; m_idx < M; m_idx++) begin
            for (int n_idx = 0; n_idx < N; n_idx++) begin
                expected_result_o[m_idx][n_idx] = 'X;
            end
        end
    endfunction

    // Print data-like arrays (N x C x B)
    function automatic void print_ncb_array(
        string name,
        logic signed [QUANTIZED_WIDTH-1:0] arr[N-1:0][C-1:0][B-1:0]
    );
        $display("Array %s:", name);
        for (int n_idx = 0; n_idx < N; n_idx++) begin
            for (int c_idx = 0; c_idx < C; c_idx++) begin
                $write("  Col[%0d] CBlock[%0d]: [", n_idx, c_idx);
                for (int b_idx = 0; b_idx < B; b_idx++) begin
                    $write("%4d", $signed(arr[n_idx][c_idx][b_idx]));
                    if (b_idx < B-1) $write(", ");
                end
                $write("]\n");
            end
        end
    endfunction

    // Print weight-like arrays (M x A x B)
    function automatic void print_mab_array(
        string name,
        logic signed [QUANTIZED_WIDTH-1:0] arr[M-1:0][A-1:0][B-1:0]
    );
        $display("Array %s:", name);
        for (int m_idx = 0; m_idx < M; m_idx++) begin
            for (int a_idx = 0; a_idx < A; a_idx++) begin
                $write("  Row[%0d] ABlock[%0d]: [", m_idx, a_idx);
                for (int b_idx = 0; b_idx < B; b_idx++) begin
                    $write("%4d", $signed(arr[m_idx][a_idx][b_idx]));
                    if (b_idx < B-1) $write(", ");
                end
                $write("]\n");
            end
        end
    endfunction

    // Print result array (M x N of wide packed vectors)
    function automatic void print_mn_wide_array(
        string name,
        logic signed [PE_CONCAT_RESULT_WIDTH-1:0] arr[M-1:0][N-1:0]
    );
        $display("Array %s:", name);
        for (int m_idx = 0; m_idx < M; m_idx++) begin
            for (int n_idx = 0; n_idx < N; n_idx++) begin
                $write("  PE[%0d][%0d] Result: 0x%0h\n", m_idx, n_idx, arr[m_idx][n_idx]);
            end
        end
    endfunction

    // Load test patterns
    function automatic void load_test_pattern(int pattern_num);
        int counter; int idx; // Moved declaration to beginning
        initialize_arrays(); // Start fresh (expected_result_o will be 'X)

        case (pattern_num)
            1: begin // Sequential
                counter = 1;
                for (int n=0; n<N; n++) for (int c=0; c<C; c++) for (int b=0; b<B; b++) data_i[n][c][b] = counter++;
                counter = 1; // Use simple weights for this propagation test
                for (int m=0; m<M; m++) for (int a=0; a<A; a++) for (int b=0; b<B; b++) weights_i[m][a][b] = 1;
            end
            2: begin // Alternating
                for (int n=0; n<N; n++) for (int c=0; c<C; c++) for (int b=0; b<B; b++) data_i[n][c][b] = ((n*C*B + c*B + b) % 2 == 0) ? 10 : -10;
                for (int m=0; m<M; m++) for (int a=0; a<A; a++) for (int b=0; b<B; b++) weights_i[m][a][b] = ((m*A*B + a*B + b) % 2 == 0) ? 5 : -5;
            end
            default: $display("Error: Invalid test pattern number: %0d", pattern_num);
        endcase
    endfunction

    // Set expected outputs for propagation tests
    function automatic void set_expected_propagation(int pattern_num);
        int counter; int idx; // Moved declaration to beginning
        // For propagation, output should match input after latency
        // expected_result_o remains 'X' as set by initialize_arrays unless overridden for specific checks

        case (pattern_num)
            1: begin // Sequential data, weights=1
                counter = 1;
                for (int n=0; n<N; n++) for (int c=0; c<C; c++) for (int b=0; b<B; b++) expected_data_o[n][c][b] = counter++;
                for (int m=0; m<M; m++) for (int a=0; a<A; a++) for (int b=0; b<B; b++) expected_weights_o[m][a][b] = 1;
            end
            2: begin // Alternating
                for (int n=0; n<N; n++) for (int c=0; c<C; c++) for (int b=0; b<B; b++) expected_data_o[n][c][b] = ((n*C*B + c*B + b) % 2 == 0) ? 10 : -10;
                for (int m=0; m<M; m++) for (int a=0; a<A; a++) for (int b=0; b<B; b++) expected_weights_o[m][a][b] = ((m*A*B + a*B + b) % 2 == 0) ? 5 : -5;
            end
            default: $display("Error: Invalid pattern for expected: %0d", pattern_num);
        endcase
    endfunction

    // Verify outputs
    function automatic bit verify_outputs(string test_name, bit check_result_exact_zero = 0);
        bit match = 1;
        for (int n=0; n<N; n++) for (int c=0; c<C; c++) for (int b=0; b<B; b++)
            if (data_o[n][c][b] !== expected_data_o[n][c][b]) begin
                match = 0; $error("%s: Data mismatch at [%0d][%0d][%0d]: Exp %d, Got %d", test_name, n,c,b, expected_data_o[n][c][b], data_o[n][c][b]);
            end
        for (int m=0; m<M; m++) for (int a=0; a<A; a++) for (int b=0; b<B; b++)
            if (weights_o[m][a][b] !== expected_weights_o[m][a][b]) begin
                match = 0; $error("%s: Weight mismatch at [%0d][%0d][%0d]: Exp %d, Got %d", test_name, m,a,b, expected_weights_o[m][a][b], weights_o[m][a][b]);
            end

        if (check_result_exact_zero) begin // Used for reset/flush checks where result should be strictly 0
            for (int m_idx=0; m_idx<M; m_idx++) for (int n_idx=0; n_idx<N; n_idx++)
                if (dut_result_o[m_idx][n_idx] !== 0) begin
                    match = 0; $error("%s: Result mismatch at [%0d][%0d]: Exp 0, Got 0x%h", test_name, m_idx,n_idx, dut_result_o[m_idx][n_idx]);
                end
        end else begin // For regular pattern checks, expected_result_o is 'X', just print info if non-zero
             for (int m_idx=0; m_idx<M; m_idx++) for (int n_idx=0; n_idx<N; n_idx++)
                if (dut_result_o[m_idx][n_idx] !== 0) begin // If 'X' was expected, any non-zero is just info
                     $display("%s: Info: dut_result_o[%0d][%0d] = 0x%h (Non-zero, as expected or TBD)", test_name, m_idx, n_idx, dut_result_o[m_idx][n_idx]);
                end
        end

        if(match) $display("%s: PASS", test_name); else $display("%s: FAIL", test_name);
        return match;
    endfunction

    // --- Main Test Sequence ---
    initial begin
        $display("--- STA Testbench Started (N=%0d, M=%0d, PE_LATENCY=%0d) ---", N, M, PE_LATENCY);
        $display("--- Expected STA Propagation Latency (approx): %0d cycles ---", STA_PROP_LATENCY);

        // 1. Reset Test
        reset = 1;
        initialize_arrays(); // expected_result_o is 'X here
        // Explicitly set expected_result_o to 0 for reset checks
        for (int m_idx = 0; m_idx < M; m_idx++) for (int n_idx = 0; n_idx < N; n_idx++) expected_result_o[m_idx][n_idx] = '0;
        @(posedge clk);
        $display("\n=== Test 1: Reset active ===");
        @(posedge clk);
        verify_outputs("Test 1.1 (During Reset)", 1); // Check all outputs are zero

        reset = 0;
        // expected_result_o is still 0
        @(posedge clk);
        $display("\n=== Test 1: Reset released ===");
        verify_outputs("Test 1.2 (After Reset)", 1); // Still expect zero

        // --- Test Propagation (Patterns 1 and 2) ---
        for (int pattern = 1; pattern <= 2; pattern++) begin
            $display("\n=== Test Pattern %0d ===", pattern);
            load_test_pattern(pattern); // Initializes expected_result_o to 'X
            set_expected_propagation(pattern); // Sets expected data/weights, result remains 'X

            $display("[%0t] Inputs loaded:", $time);
            print_ncb_array("data_i", data_i);
            print_mab_array("weights_i", weights_i);

            $display("[%0t] Waiting %0d cycles for propagation...", $time, CHECK_DELAY); // Use CHECK_DELAY
            repeat (CHECK_DELAY) @(posedge clk);

            $display("[%0t] Checking outputs:", $time);
            print_ncb_array("data_o", data_o);
            print_mab_array("weights_o", weights_o);
            print_mn_wide_array("dut_result_o", dut_result_o); // Display results

            verify_outputs($sformatf("Test Pattern %0d", pattern), 0); // check_result_exact_zero = 0

            // Flush
            initialize_arrays(); // tb_inputs go to 0, expected_data/weights go to 0. expected_result_o becomes 'X.
            $display("[%0t] Flushing array with zeros...", $time);
            repeat (CHECK_DELAY + 5) @(posedge clk); // Wait for zeros to propagate + extra margin

            // Verify flush (expect data/weights to be zero)
            // For result_o, it will hold its value. We expect it to be non-zero from previous pattern.
            // The verify_outputs with check_result_exact_zero = 0 will just print info.
            // If we want to assert it's zero after flush, we need a reset.
            // For this test, we'll check data/weights are zero, and results are not *necessarily* zero.
            $display("[%0t] Checking outputs after flush:", $time);
            // expected_data_o and expected_weights_o are already 0 from initialize_arrays().
            // expected_result_o is 'X' from initialize_arrays().
            verify_outputs($sformatf("Test Pattern %0d Flush", pattern), 0); // check_result_exact_zero = 0
        end

        // Test Reset During Operation
        $display("\n=== Test Reset During Operation ===");
        load_test_pattern(1); // Load some data
        @(posedge clk); @(posedge clk);
        reset = 1; // Assert reset mid-operation
        // Explicitly set expected_result_o to 0 for reset checks
        for (int m_idx = 0; m_idx < M; m_idx++) for (int n_idx = 0; n_idx < N; n_idx++) expected_result_o[m_idx][n_idx] = '0;
        initialize_arrays(); // This will set expected_data/weights to 0.
                             // And expected_result_o to 'X', so override again for reset check.
        for (int m_idx = 0; m_idx < M; m_idx++) for (int n_idx = 0; n_idx < N; n_idx++) expected_result_o[m_idx][n_idx] = '0;

        @(posedge clk); @(posedge clk);
        $display("[%0t] Reset asserted mid-op, checking outputs...", $time);
        verify_outputs("Test Reset Mid-Op", 1); // Check results are exactly 0
        reset = 0; // Deassert reset
        @(posedge clk);


        $display("\n=== All tests completed! ===");
        $finish;
    end
endmodule
