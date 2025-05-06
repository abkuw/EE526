// Abhishek Kumar, Keith Phou
// EE 526

// Testbench for the Systolic Tensor Array (STA)
module sta_tb;
    // Define test parameters - using smaller dimensions for simulation
    localparam int N = 2;                   // Number of PE columns
    localparam int M = 2;                   // Number of PE rows
    localparam int B = 4;                   // Number of parallel multipliers per DP
    localparam int A = 2;                   // Rows of DPs within PE
    localparam int C = 2;                   // Columns of DPs within PE
    localparam int QUANTIZED_WIDTH = 8;     // Bit-width of input data/weights
    
    // Define clock and reset signals
    logic clk;
    logic reset;
    
    // Define variables that will be used throughout the testbench
    int counter;                           // Moved the counter declaration to module level
    int latency_cycles;                    // Cycles needed for data to propagate through array
    
    // Define input and output arrays
    // Data input - format: [column][C-block][B-element]
    logic signed [QUANTIZED_WIDTH-1:0] data_i[N-1:0][C-1:0][B-1:0];
    // Weight input - format: [row][A-block][B-element]
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][A-1:0][B-1:0];
    // Data output
    logic signed [QUANTIZED_WIDTH-1:0] data_o[N-1:0][C-1:0][B-1:0];
    // Weight output
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][A-1:0][B-1:0];
    // Results output (from each PE)
    logic signed [QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0][2*B-1:0];
    
    // Expected output arrays for validation
    logic signed [QUANTIZED_WIDTH-1:0] expected_data_o[N-1:0][C-1:0][B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] expected_weights_o[M-1:0][A-1:0][B-1:0];
    
    // Instantiate the STA (device under test)
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
        .result_o(result_o)
    );
    
    // Clock generation
    parameter clock_period = 100;
    initial begin
        clk = 0;
        forever #(clock_period/2) clk = ~clk;
    end
    
    // Helper function to initialize all test arrays to zero
    function automatic void initialize_arrays();
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    data_i[n][c][b] = 0;
                    expected_data_o[n][c][b] = 0;
                end
            end
        end
        
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    weights_i[m][a][b] = 0;
                    expected_weights_o[m][a][b] = 0;
                end
            end
        end
    endfunction

    // Helper function to print data arrays
    function automatic void print_data_array(
        string name,
        logic signed [QUANTIZED_WIDTH-1:0] arr[N-1:0][C-1:0][B-1:0]
    );
        $display("Array %s:", name);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < C; j++) begin
                $write("  [%0d][%0d]: [", i, j);
                for (int k = 0; k < B; k++) begin
                    $write("%4d", $signed(arr[i][j][k]));
                    if (k < B-1) $write(", ");
                end
                $write("]\n");
            end
        end
    endfunction

    // Helper function to print weight arrays
    function automatic void print_weight_array(
        string name,
        logic signed [QUANTIZED_WIDTH-1:0] arr[M-1:0][A-1:0][B-1:0]
    );
        $display("Array %s:", name);
        for (int i = 0; i < M; i++) begin
            for (int j = 0; j < A; j++) begin
                $write("  [%0d][%0d]: [", i, j);
                for (int k = 0; k < B; k++) begin
                    $write("%4d", $signed(arr[i][j][k]));
                    if (k < B-1) $write(", ");
                end
                $write("]\n");
            end
        end
    endfunction
    
    // Helper function to print result array from PEs
    function automatic void print_result_array(
        string name,
        logic signed [QUANTIZED_WIDTH-1:0] arr[M-1:0][N-1:0][2*B-1:0]
    );
        $display("Array %s:", name);
        for (int i = 0; i < M; i++) begin
            for (int j = 0; j < N; j++) begin
                $write("  PE[%0d][%0d]: [", i, j);
                for (int k = 0; k < 2*B; k++) begin
                    $write("%4d", $signed(arr[i][j][k]));
                    if (k < 2*B-1) $write(", ");
                end
                $write("]\n");
            end
        end
    endfunction
    
    // Helper function to load data patterns
    function automatic void load_test_pattern(int pattern_num);
        // Initialize arrays first
        initialize_arrays();
        
        case (pattern_num)
            // Test Pattern 1: Sequential values
            1: begin
                // Each element gets a unique sequential value
                counter = 1;
                
                // Load data inputs
                for (int n = 0; n < N; n++) begin
                    for (int c = 0; c < C; c++) begin
                        for (int b = 0; b < B; b++) begin
                            data_i[n][c][b] = counter++;
                        end
                    end
                end
                
                // Load weight inputs
                counter = 101; // Start weights with a different base value
                for (int m = 0; m < M; m++) begin
                    for (int a = 0; a < A; a++) begin
                        for (int b = 0; b < B; b++) begin
                            weights_i[m][a][b] = counter++;
                        end
                    end
                end
            end
            
            // Test Pattern 2: Alternating positive/negative values
            2: begin
                // Data alternates 10, -10
                for (int n = 0; n < N; n++) begin
                    for (int c = 0; c < C; c++) begin
                        for (int b = 0; b < B; b++) begin
                            int idx = (n * C * B) + (c * B) + b;
                            data_i[n][c][b] = (idx % 2 == 0) ? 10 : -10;
                        end
                    end
                end
                
                // Weights alternates 5, -5
                for (int m = 0; m < M; m++) begin
                    for (int a = 0; a < A; a++) begin
                        for (int b = 0; b < B; b++) begin
                            int idx = (m * A * B) + (a * B) + b;
                            weights_i[m][a][b] = (idx % 2 == 0) ? 5 : -5;
                        end
                    end
                end
            end
            
            // Test Pattern 3: Maximum values
            3: begin
                // All data set to maximum INT8 value
                for (int n = 0; n < N; n++) begin
                    for (int c = 0; c < C; c++) begin
                        for (int b = 0; b < B; b++) begin
                            data_i[n][c][b] = 127;
                        end
                    end
                end
                
                // All weights set to maximum INT8 value
                for (int m = 0; m < M; m++) begin
                    for (int a = 0; a < A; a++) begin
                        for (int b = 0; b < B; b++) begin
                            weights_i[m][a][b] = 127;
                        end
                    end
                end
            end
            
            // Test Pattern 4: Minimum values
            4: begin
                // All data set to minimum INT8 value
                for (int n = 0; n < N; n++) begin
                    for (int c = 0; c < C; c++) begin
                        for (int b = 0; b < B; b++) begin
                            data_i[n][c][b] = -128;
                        end
                    end
                end
                
                // All weights set to minimum INT8 value
                for (int m = 0; m < M; m++) begin
                    for (int a = 0; a < A; a++) begin
                        for (int b = 0; b < B; b++) begin
                            weights_i[m][a][b] = -128;
                        end
                    end
                end
            end
            
            // Test Pattern 5: Simple matrix multiplication
            5: begin
                // Set data to 1 and weights to 1 for simple multiplication
                for (int n = 0; n < N; n++) begin
                    for (int c = 0; c < C; c++) begin
                        for (int b = 0; b < B; b++) begin
                            data_i[n][c][b] = 1;
                        end
                    end
                end
                
                for (int m = 0; m < M; m++) begin
                    for (int a = 0; a < A; a++) begin
                        for (int b = 0; b < B; b++) begin
                            weights_i[m][a][b] = 1;
                        end
                    end
                end
            end
            
            default: begin
                $display("Error: Invalid test pattern number: %0d", pattern_num);
            end
        endcase
    endfunction
    
    // Helper function to verify outputs
    function automatic bit verify_outputs();
        bit match = 1;
        
        // Verify data outputs
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    if (data_o[n][c][b] !== expected_data_o[n][c][b]) begin
                        match = 0;
                        $display("Data mismatch at [%0d][%0d][%0d]: Expected %0d, Got %0d", 
                                 n, c, b, $signed(expected_data_o[n][c][b]), $signed(data_o[n][c][b]));
                    end
                end
            end
        end
        
        // Verify weight outputs
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    if (weights_o[m][a][b] !== expected_weights_o[m][a][b]) begin
                        match = 0;
                        $display("Weight mismatch at [%0d][%0d][%0d]: Expected %0d, Got %0d", 
                                 m, a, b, $signed(expected_weights_o[m][a][b]), $signed(weights_o[m][a][b]));
                    end
                end
            end
        end
        
        return match;
    endfunction
    
    // Set expected outputs for test pattern 1
    function automatic void set_expected_pattern_1();
        // Sequential values should flow through the array
        counter = 1;
        
        // Expected data outputs
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = counter++;
                end
            end
        end
        
        // Expected weight outputs
        counter = 101; // Same base value as input weights
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = counter++;
                end
            end
        end
    endfunction
    
    // Main test sequence
    initial begin
        // Calculate latency cycles based on array dimensions
        // For a systolic array, latency is proportional to (M+N)
        // Using 4 cycles per PE and a safety factor of 2
        latency_cycles = (M + N) * 4 * 2;
        
        // Initialize
        reset = 1;
        initialize_arrays();
        
        // Test 1: Verify reset behavior
        @(posedge clk);
        @(posedge clk); // Additional cycle to ensure reset propagates
        $display("\n=== Test 1: Reset active ===");
        
        if (verify_outputs()) 
            $display("Test 1: PASS - All outputs are zero during reset");
        else
            $display("Test 1: FAIL - Outputs not zero during reset");
        
        // Test 2: Release reset and propagate sequential pattern
        reset = 0;
        @(posedge clk); // Wait one cycle after reset release
        load_test_pattern(1);
        $display("\n=== Test 2: Pattern 1 (Sequential values) loaded ===");
        print_data_array("data_i", data_i);
        print_weight_array("weights_i", weights_i);
        
        // Wait for data to propagate through the systolic array
        $display("Waiting for data propagation (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Set expected outputs for pattern 1
        set_expected_pattern_1();
        
        $display("\n=== Test 2: Checking outputs after propagation ===");
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        print_data_array("expected_data_o", expected_data_o);
        print_weight_array("expected_weights_o", expected_weights_o);
        
        if (verify_outputs()) 
            $display("Test 2: PASS - Pattern 1 propagated correctly");
        else
            $display("Test 2: FAIL - Pattern 1 did not propagate correctly");
        
        // Test 3: Alternating positive/negative values
        reset = 1; // Reset between patterns
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        load_test_pattern(2);
        $display("\n=== Test 3: Pattern 2 (Alternating values) loaded ===");
        print_data_array("data_i", data_i);
        print_weight_array("weights_i", weights_i);
        
        // Wait for data propagation
        $display("Waiting for data propagation (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Set expected outputs - same alternating pattern
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    int idx;
						 idx = (n * C * B) + (c * B) + b;
                    expected_data_o[n][c][b] = (idx % 2 == 0) ? 10 : -10;
                end
            end
        end
        
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    int idx;
						 idx = (m * A * B) + (a * B) + b;
                    expected_weights_o[m][a][b] = (idx % 2 == 0) ? 5 : -5;
                end
            end
        end
        
        $display("\n=== Test 3: Checking outputs after propagation ===");
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 3: PASS - Pattern 2 propagated correctly");
        else
            $display("Test 3: FAIL - Pattern 2 did not propagate correctly");
        
        // Test 4: Reset during operation
        reset = 1;
        $display("\n=== Test 4: Reset during operation ===");
        
        // Wait for reset to take effect
        repeat (2) @(posedge clk);
        
        // Initialize expected outputs to zero
        initialize_arrays();
        
        if (verify_outputs()) 
            $display("Test 4: PASS - Reset during operation works correctly");
        else
            $display("Test 4: FAIL - Reset during operation failed");
        
        // Test 5: Maximum values
        reset = 0;
        @(posedge clk);
        load_test_pattern(3);
        $display("\n=== Test 5: Pattern 3 (Maximum values) loaded ===");
        
        // Wait for data propagation
        $display("Waiting for data propagation (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Set expected outputs to maximum values
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = 127;
                end
            end
        end
        
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = 127;
                end
            end
        end
        
        $display("\n=== Test 5: Checking outputs after propagation ===");
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 5: PASS - Maximum values propagated correctly");
        else
            $display("Test 5: FAIL - Maximum values did not propagate correctly");
        
        // Test 6: Minimum values
        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        load_test_pattern(4);
        $display("\n=== Test 6: Pattern 4 (Minimum values) loaded ===");
        
        // Wait for data propagation
        $display("Waiting for data propagation (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Set expected outputs to minimum values
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = -128;
                end
            end
        end
        
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = -128;
                end
            end
        end
        
        $display("\n=== Test 6: Checking outputs after propagation ===");
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 6: PASS - Minimum values propagated correctly");
        else
            $display("Test 6: FAIL - Minimum values did not propagate correctly");
        
        // Test 7: Simple matrix multiplication test
        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        load_test_pattern(5);
        $display("\n=== Test 7: Pattern 5 (Simple matrix multiplication) loaded ===");
        
        // Wait for data propagation
        $display("Waiting for data propagation (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Set expected data and weight outputs - still all ones
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = 1;
                end
            end
        end
        
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = 1;
                end
            end
        end
        
        $display("\n=== Test 7: Checking outputs after propagation ===");
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 7: PASS - Simple matrix multiplication pattern propagated correctly");
        else
            $display("Test 7: FAIL - Simple matrix multiplication pattern did not propagate correctly");
        
        // Test 8: Pipeline filling with sequential inputs - IMPROVED VERSION
        $display("\n=== Test 8: Testing pipeline filling with sequential inputs (IMPROVED) ===");
        
        // Full reset to ensure clean state
        reset = 1;
        repeat (4) @(posedge clk);
        initialize_arrays();
        reset = 0;
        repeat (2) @(posedge clk);
        
        // Load sequence 1 and hold steady
        $display("Loading sequence 1");
        counter = 1;
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    data_i[n][c][b] = counter++;
                end
            end
        end
        
        counter = 101;
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    weights_i[m][a][b] = counter++;
                end
            end
        end
        
        // Wait until sequence 1 fully propagates through array
        $display("Waiting for sequence 1 to propagate (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // First sequence should appear at output
        $display("Checking for sequence 1 at outputs");
        counter = 1;
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = counter++;
                end
            end
        end
        
        counter = 101;
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = counter++;
                end
            end
        end
        
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 8.1: PASS - First sequence appeared at output");
        else
            $display("Test 8.1: FAIL - First sequence did not appear at output");
        
        // Reset again before loading second sequence
        reset = 1;
        repeat (4) @(posedge clk);
        initialize_arrays();
        reset = 0;
        repeat (2) @(posedge clk);
        
        // Load sequence 2 and hold steady
        $display("Loading sequence 2");
        counter = 1000;
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    data_i[n][c][b] = counter++;
                end
            end
        end
        
        counter = 2000;
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    weights_i[m][a][b] = counter++;
                end
            end
        end
        
        // Wait until sequence 2 fully propagates through array
        $display("Waiting for sequence 2 to propagate (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Second sequence should appear at output
        $display("Checking for sequence 2 at outputs");
        counter = 1000;
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = counter++;
                end
            end
        end
        
        counter = 2000;
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = counter++;
                end
            end
        end
        
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 8.2: PASS - Second sequence appeared at output");
        else
            $display("Test 8.2: FAIL - Second sequence did not appear at output");
        
        // Reset again before loading third sequence
        reset = 1;
        repeat (4) @(posedge clk);
        initialize_arrays();
        reset = 0;
        repeat (2) @(posedge clk);
        
        // Load sequence 3 and hold steady
        $display("Loading sequence 3");
        counter = 3000;
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    data_i[n][c][b] = counter++;
                end
            end
        end
        
        counter = 4000;
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    weights_i[m][a][b] = counter++;
                end
            end
        end
        
        // Wait until sequence 3 fully propagates through array
        $display("Waiting for sequence 3 to propagate (%0d cycles)...", latency_cycles);
        repeat (latency_cycles) @(posedge clk);
        
        // Third sequence should appear at output
        $display("Checking for sequence 3 at outputs");
        counter = 3000;
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = counter++;
                end
            end
        end
        
        counter = 4000;
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    expected_weights_o[m][a][b] = counter++;
                end
            end
        end
        
        print_data_array("data_o", data_o);
        print_weight_array("weights_o", weights_o);
        print_result_array("result_o", result_o);
        
        if (verify_outputs()) 
            $display("Test 8.3: PASS - Third sequence appeared at output");
        else
            $display("Test 8.3: FAIL - Third sequence did not appear at output");
        
        $display("\n=== All tests completed! ===");
        $finish;
    end
endmodule
