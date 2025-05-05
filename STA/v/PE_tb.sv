// Abhishek Kumar, Keith Phou
// EE 526

// Testbench for the PE (Processing Element) module
module PE_tb;
    // Define parameters
    localparam int B = 4;                   // Number of parallel multipliers per DP
    localparam int A = 2;                   // Rows of DPs within PE
    localparam int C = 2;                   // Columns of DPs within PE
    localparam int QUANTIZED_WIDTH = 8;     // Bit-width of input data/weights
    localparam int RESULT_WIDTH = 4*QUANTIZED_WIDTH;  // Width of accumulator
    
    // Define signals
    logic                            clk;
    logic                            reset;     
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
    
    // Define the seed for random number generation
    int seed;
    
    // Instantiate the PE (device under test)
    PE #(
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
                break;
            end
        end
        
        // Check weight outputs
        for (int i = 0; i < B*A; i++) begin
            if (actual_weights[i] !== expected_weights[i]) begin
                weights_match = 0;
                break;
            end
        end
        
        // Print verification results
        if (data_match && weights_match) begin
            $display("%s: PASS - All outputs match expected values", test_name);
        end else begin
            $display("%s: FAIL - Output mismatch", test_name);
            
            // Print expected vs actual for debugging
            $write("Expected data_o = [");
            for (int i = 0; i < B*C; i++) begin
                $write("%d", $signed(expected_data[i]));
                if (i < B*C-1) $write(", ");
            end
            $write("], Actual data_o = [");
            for (int i = 0; i < B*C; i++) begin
                $write("%d", $signed(actual_data[i]));
                if (i < B*C-1) $write(", ");
            end
            $write("]\n");
            
            $write("Expected weights_o = [");
            for (int i = 0; i < B*A; i++) begin
                $write("%d", $signed(expected_weights[i]));
                if (i < B*A-1) $write(", ");
            end
            $write("], Actual weights_o = [");
            for (int i = 0; i < B*A; i++) begin
                $write("%d", $signed(actual_weights[i]));
                if (i < B*A-1) $write(", ");
            end
            $write("]\n");
        end
    endfunction
    
    initial begin
        // Initialize signals
        reset = 1;
        seed = 42; // Initialize the seed here
        
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = 0;
            expected_data_o[i] = 0;
            // Initialize test arrays
            random_data[i] = 0;
            input_data_1[i] = 0;
            input_data_2[i] = 0;
            input_data_3[i] = 0;
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = 0;
            expected_weights_o[i] = 0;
            // Initialize test arrays
            random_weights[i] = 0;
            input_weights_1[i] = 0;
            input_weights_2[i] = 0;
            input_weights_3[i] = 0;
        end
        
        // Test 1: Reset active
        @(posedge clk);
        $display("Test 1: Reset active");
        
        // During reset, all outputs should be zero
        for (int i = 0; i < B*C; i++) begin
            expected_data_o[i] = 0;
        end
        
        for (int i = 0; i < B*A; i++) begin
            expected_weights_o[i] = 0;
        end
        
        verify_outputs("Test 1", data_o, expected_data_o, weights_o, expected_weights_o);
        
        // Test 2: Release reset
        reset = 0;
        @(posedge clk);
        $display("Test 2: Reset inactive");
        
        // After reset release, outputs should still be zero until new data propagates
        verify_outputs("Test 2", data_o, expected_data_o, weights_o, expected_weights_o);
        
        // Test 3: Basic data flow - simple values
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = i + 1;     // [1,2,3,4,5,6,7,8]
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = i + 1;  // [1,2,3,4,5,6,7,8]
        end
        
        print_arrays("Test 3 inputs", data_i, weights_i);
        
        // Wait for data to propagate through the PE array
        // In a 2x2 systolic array, data needs 3 cycles to fully propagate
        @(posedge clk); // Cycle 1 - Data enters DP1 and DP2
        @(posedge clk); // Cycle 2 - Data propagates to DP3 and DP4
        @(posedge clk); // Cycle 3 - Data reaches output buffers
        
        // Expected outputs after 3 clock cycles:
        // Data flow: data_i[0:3] -> DP1 -> DP3 -> data_o[0:3]
        //           data_i[4:7] -> DP2 -> DP4 -> data_o[4:7]
        // Weight flow: weights_i[0:3] -> DP1 -> DP2 -> weights_o[0:3]
        //             weights_i[4:7] -> DP3 -> DP4 -> weights_o[4:7]
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = i + 1;       // data_i[0:3] should appear at data_o[0:3]
            expected_data_o[i+B] = i + 1 + B; // data_i[4:7] should appear at data_o[4:7]
            
            expected_weights_o[i] = i + 1;    // weights_i[0:3] should appear at weights_o[0:3]
            expected_weights_o[i+B] = i + 1 + B; // weights_i[4:7] should appear at weights_o[4:7]
        end
        
        print_output_arrays("Test 3 outputs", data_o, weights_o);
        verify_outputs("Test 3", data_o, expected_data_o, weights_o, expected_weights_o);
        $display("Test 3: Basic data flow complete");
        
        // Test 4: Alternating positive/negative values
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = (i % 2 == 0) ? 10 : -10;  // [10,-10,10,-10,10,-10,10,-10]
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = (i % 2 == 0) ? 5 : -5; // [5,-5,5,-5,5,-5,5,-5]
        end
        
        print_arrays("Test 4 inputs", data_i, weights_i);
        
        // Wait for several clock cycles
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        // Expected alternating pattern after propagation
        for (int i = 0; i < B*C; i++) begin
            expected_data_o[i] = (i % 2 == 0) ? 10 : -10;
        end
        
        for (int i = 0; i < B*A; i++) begin
            expected_weights_o[i] = (i % 2 == 0) ? 5 : -5;
        end
        
        print_output_arrays("Test 4 outputs", data_o, weights_o);
        verify_outputs("Test 4", data_o, expected_data_o, weights_o, expected_weights_o);
        $display("Test 4: Alternating values test complete");
        
        // Test 5: Random values within INT8 range
        for (int i = 0; i < B*C; i++) begin
            // Generate random value between -128 and 127 (INT8 range)
            data_i[i] = $random(seed) % 256 - 128;
            random_data[i] = data_i[i];  // Save for verification
        end
        
        for (int i = 0; i < B*A; i++) begin
            // Generate random value between -128 and 127 (INT8 range)
            weights_i[i] = $random(seed) % 256 - 128;
            random_weights[i] = weights_i[i];  // Save for verification
        end
        
        print_arrays("Test 5 inputs", data_i, weights_i);
        
        // Wait for several clock cycles
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        // Set expected outputs based on the random inputs
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = random_data[i];       // data from top-left DP
            expected_data_o[i+B] = random_data[i+B];   // data from top-right DP
            
            expected_weights_o[i] = random_weights[i];    // weights from top-left DP
            expected_weights_o[i+B] = random_weights[i+B]; // weights from bottom-left DP
        end
        
        print_output_arrays("Test 5 outputs", data_o, weights_o);
        verify_outputs("Test 5", data_o, expected_data_o, weights_o, expected_weights_o);
        $display("Test 5: Random values test complete");
        
        // Test 6: Maximum values test
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = 127;  // Max positive INT8
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = 127; // Max positive INT8
        end
        
        print_arrays("Test 6 inputs", data_i, weights_i);
        
        // Wait for several clock cycles
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        // All outputs should be max positive value
        for (int i = 0; i < B*C; i++) begin
            expected_data_o[i] = 127;
        end
        
        for (int i = 0; i < B*A; i++) begin
            expected_weights_o[i] = 127;
        end
        
        print_output_arrays("Test 6 outputs", data_o, weights_o);
        verify_outputs("Test 6", data_o, expected_data_o, weights_o, expected_weights_o);
        $display("Test 6: Maximum values test complete");
        
        // Test 7: Minimum values test
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = -128;  // Min negative INT8
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = -128; // Min negative INT8
        end
        
        print_arrays("Test 7 inputs", data_i, weights_i);
        
        // Wait for several clock cycles
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        // All outputs should be min negative value
        for (int i = 0; i < B*C; i++) begin
            expected_data_o[i] = -128;
        end
        
        for (int i = 0; i < B*A; i++) begin
            expected_weights_o[i] = -128;
        end
        
        print_output_arrays("Test 7 outputs", data_o, weights_o);
        verify_outputs("Test 7", data_o, expected_data_o, weights_o, expected_weights_o);
        $display("Test 7: Minimum values test complete");
        
        // Test 8: Reset during operation
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = i * 2;  // [0,2,4,6,8,10,12,14]
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = i * 3; // [0,3,6,9,12,15,18,21]
        end
        
        print_arrays("Test 8 inputs", data_i, weights_i);
        
        // Wait for one clock cycle and then reset
        @(posedge clk);
        reset = 1;
        
        @(posedge clk);
        
        // After reset, all outputs should be zero
        for (int i = 0; i < B*C; i++) begin
            expected_data_o[i] = 0;
        end
        
        for (int i = 0; i < B*A; i++) begin
            expected_weights_o[i] = 0;
        end
        
        print_output_arrays("Test 8 outputs (after reset)", data_o, weights_o);
        verify_outputs("Test 8", data_o, expected_data_o, weights_o, expected_weights_o);
        $display("Test 8: Reset during operation test complete");
        
        // Test 9: Verify systolic data flow with consecutive different inputs
        reset = 0;
        @(posedge clk);
        
        // First set of inputs
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = i + 1;  // [1,2,3,4,5,6,7,8]
            input_data_1[i] = data_i[i];
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = 10 + i; // [10,11,12,13,14,15,16,17]
            input_weights_1[i] = weights_i[i];
        end
        
        print_arrays("Test 9.1 inputs", data_i, weights_i);
        @(posedge clk);
        
        // Second set of inputs
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = 20 + i;  // [20,21,22,23,24,25,26,27]
            input_data_2[i] = data_i[i];
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = 30 + i; // [30,31,32,33,34,35,36,37]
            input_weights_2[i] = weights_i[i];
        end
        
        print_arrays("Test 9.2 inputs", data_i, weights_i);
        @(posedge clk);
        
        // Third set of inputs
        for (int i = 0; i < B*C; i++) begin
            data_i[i] = 40 + i;  // [40,41,42,43,44,45,46,47]
            input_data_3[i] = data_i[i];
        end
        
        for (int i = 0; i < B*A; i++) begin
            weights_i[i] = 50 + i; // [50,51,52,53,54,55,56,57]
            input_weights_3[i] = weights_i[i];
        end
        
        print_arrays("Test 9.3 inputs", data_i, weights_i);
        
        // Wait for several cycles to let data propagate through the systolic array
        // Cycle 1: First input in DP1/DP2
        // Cycle 2: First input in DP3/DP4, Second input in DP1/DP2
        // Cycle 3: First input at outputs, Second input in DP3/DP4, Third input in DP1/DP2
        // Cycle 4: Second input at outputs, Third input in DP3/DP4
        // Cycle 5: Third input at outputs
        @(posedge clk);
        @(posedge clk);
        
        // At this point, the first set of inputs should be at the outputs
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = input_data_1[i];       // First data set from top-left DP
            expected_data_o[i+B] = input_data_1[i+B];   // First data set from top-right DP
            
            expected_weights_o[i] = input_weights_1[i];    // First weights set from top-left DP
            expected_weights_o[i+B] = input_weights_1[i+B]; // First weights set from bottom-left DP
        end
        
        $display("Test 9 - After 3 cycles (first set at outputs):");
        print_output_arrays("Test 9.3 outputs", data_o, weights_o);
        verify_outputs("Test 9.3", data_o, expected_data_o, weights_o, expected_weights_o);
        
        @(posedge clk);
        
        // After one more cycle, the second set of inputs should be at the outputs
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = input_data_2[i];       
            expected_data_o[i+B] = input_data_2[i+B];   
            
            expected_weights_o[i] = input_weights_2[i];    
            expected_weights_o[i+B] = input_weights_2[i+B]; 
        end
        
        $display("Test 9 - After 4 cycles (second set at outputs):");
        print_output_arrays("Test 9.4 outputs", data_o, weights_o);
        verify_outputs("Test 9.4", data_o, expected_data_o, weights_o, expected_weights_o);
        
        @(posedge clk);
        
        // After one more cycle, the third set of inputs should be at the outputs
        for (int i = 0; i < B; i++) begin
            expected_data_o[i] = input_data_3[i];       
            expected_data_o[i+B] = input_data_3[i+B];   
            
            expected_weights_o[i] = input_weights_3[i];    
            expected_weights_o[i+B] = input_weights_3[i+B]; 
        end
        
        $display("Test 9 - After 5 cycles (third set at outputs):");
        print_output_arrays("Test 9.5 outputs", data_o, weights_o);
        verify_outputs("Test 9.5", data_o, expected_data_o, weights_o, expected_weights_o);
        
        $display("Test 9: Systolic data flow test complete");
        
        $display("All tests completed!");
        $finish;
    end
endmodule