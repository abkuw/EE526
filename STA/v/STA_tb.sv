// Testbench for Systolic Tensor Array (STA)
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
    
    // Define input and output arrays
    // Data input - format: [column][C-block][B-element]
    logic signed [QUANTIZED_WIDTH-1:0] data_i[N-1:0][C-1:0][B-1:0];
    // Weight input - format: [row][A-block][B-element]
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[M-1:0][A-1:0][B-1:0];
    // Data output
    logic signed [QUANTIZED_WIDTH-1:0] data_o[N-1:0][C-1:0][B-1:0];
    // Weight output
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[M-1:0][A-1:0][B-1:0];
    
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
        .weights_o(weights_o)
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
    
    // Helper function to print 3D array
    function automatic void print_3D_array(
        string name,
        logic signed [QUANTIZED_WIDTH-1:0] arr[][][]
    );
        $display("Array %s:", name);
        for (int i = 0; i < $size(arr); i++) begin
            for (int j = 0; j < $size(arr[0]); j++) begin
                $write("  [%0d][%0d]: [", i, j);
                for (int k = 0; k < $size(arr[0][0]); k++) begin
                    $write("%4d", $signed(arr[i][j][k]));
                    if (k < $size(arr[0][0])-1) $write(", ");
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
                int counter = 1;
                
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
                // Data alternates 1, -1
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
            
            default: begin
                $display("Error: Invalid test pattern number: %0d", pattern_num);
            end
        endcase
    endfunction
    
    // Helper function to verify outputs
    function automatic bit verify_output();
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
    
    // This sets the expected outputs for test pattern 1
    // Based on how data should propagate through your STA
    function automatic void set_expected_pattern_1();
        // Fill pattern for sequential test - values should propagate through
        // For the 2x2 STA, each data input should appear at the corresponding output
        // after flowing through the PEs
        
        int counter = 1;
        
        // Expected data outputs
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    expected_data_o[n][c][b] = counter++;
                end
            end
        end
        
        // Expected weight outputs
        counter = 101; // Same base value as we used for weight inputs
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
        // Initialize
        reset = 1;
        initialize_arrays();
        
        // Test 1: Verify reset behavior
        @(posedge clk);
        $display("Test 1: Reset active");
        
        if (verify_output()) 
            $display("Test 1: PASS - All outputs are zero during reset");
        else
            $display("Test 1: FAIL - Outputs not zero during reset");
        
        // Test 2: Release reset and propagate sequential pattern through the array
        reset = 0;
        load_test_pattern(1);
        $display("Test 2: Pattern 1 (Sequential values) loaded");
        print_3D_array("data_i", data_i);
        print_3D_array("weights_i", weights_i);
        
        // Wait for propagation - for a 2x2 STA, we need to wait for 
        // the data to propagate through the PEs (4 cycles per PE)
        // Total delay = PEs in longest path * cycles per PE
        // For M=2, N=2, with 4 cycle PE latency: 4 * (M+N-1) = 12 cycles
        repeat (12) @(posedge clk);
        
        // Set expected outputs for pattern 1
        set_expected_pattern_1();
        
        $display("Test 2: Checking outputs after propagation");
        print_3D_array("data_o", data_o);
        print_3D_array("weights_o", weights_o);
        print_3D_array("expected_data_o", expected_data_o);
        print_3D_array("expected_weights_o", expected_weights_o);
        
        if (verify_output()) 
            $display("Test 2: PASS - Pattern 1 propagated correctly");
        else
            $display("Test 2: FAIL - Pattern 1 did not propagate correctly");
        
        // Test 3: Load pattern 2 (alternating values) and verify propagation
        load_test_pattern(2);
        $display("Test 3: Pattern 2 (Alternating values) loaded");
        print_3D_array("data_i", data_i);
        print_3D_array("weights_i", weights_i);
        
        // Wait for propagation again
        repeat (12) @(posedge clk);
        
        // Set expected outputs for alternating pattern
        // We'll set the same values - in the systolic array, these should 
        // propagate straight through
        for (int n = 0; n < N; n++) begin
            for (int c = 0; c < C; c++) begin
                for (int b = 0; b < B; b++) begin
                    int idx = (n * C * B) + (c * B) + b;
                    expected_data_o[n][c][b] = (idx % 2 == 0) ? 10 : -10;
                end
            end
        end
        
        for (int m = 0; m < M; m++) begin
            for (int a = 0; a < A; a++) begin
                for (int b = 0; b < B; b++) begin
                    int idx = (m * A * B) + (a * B) + b;
                    expected_weights_o[m][a][b] = (idx % 2 == 0) ? 5 : -5;
                end
            end
        end
        
        $display("Test 3: Checking outputs after propagation");
        print_3D_array("data_o", data_o);
        print_3D_array("weights_o", weights_o);
        
        if (verify_output()) 
            $display("Test 3: PASS - Pattern 2 propagated correctly");
        else
            $display("Test 3: FAIL - Pattern 2 did not propagate correctly");
        
        // Test 4: Reset during operation
        reset = 1;
        $display("Test 4: Reset during operation");
        
        // Wait 2 cycles for reset to take effect
        repeat (2) @(posedge clk);
        
        // Initialize expected outputs to zero
        initialize_arrays();
        
        if (verify_output()) 
            $display("Test 4: PASS - Reset during operation works correctly");
        else
            $display("Test 4: FAIL - Reset during operation failed");
        
        // Test 5: Test pattern 3 (Maximum values)
        reset = 0;
        load_test_pattern(3);
        $display("Test 5: Pattern 3 (Maximum values) loaded");
        
        // Wait for propagation
        repeat (12) @(posedge clk);
        
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
        
        $display("Test 5: Checking outputs after propagation");
        if (verify_output()) 
            $display("Test 5: PASS - Maximum values propagated correctly");
        else
            $display("Test 5: FAIL - Maximum values did not propagate correctly");
        
        // Test 6: Test pattern 4 (Minimum values)
        load_test_pattern(4);
        $display("Test 6: Pattern 4 (Minimum values) loaded");
        
        // Wait for propagation
        repeat (12) @(posedge clk);
        
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
        
        $display("Test 6: Checking outputs after propagation");
        if (verify_output()) 
            $display("Test 6: PASS - Minimum values propagated correctly");
        else
            $display("Test 6: FAIL - Minimum values did not propagate correctly");
        
        $display("All tests completed!");
        $finish;
    end
endmodule