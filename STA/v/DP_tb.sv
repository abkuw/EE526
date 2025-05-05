// Abhishek Kumar, Keith Phou
// EE 526

// Testbench for the DP (Dot Product)
module DP_tb;
    localparam int B = 4;                   // Number of parallel multipliers
    localparam int QUANTIZED_WIDTH = 8;     // Bit-width of input data/weights
    localparam int RESULT_WIDTH = 4*QUANTIZED_WIDTH;  // Width of accumulator
    
    // Define signals
    logic                          clk;
    logic                          reset;     
    logic signed [QUANTIZED_WIDTH-1:0] data_i   [B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weight_i [B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] data_v_o   [B-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weight_h_o [B-1:0];
    logic signed [RESULT_WIDTH-1:0]    result;
    logic signed [RESULT_WIDTH-1:0]    expected_result; // hold expected value
    
    DP #(
        .B(B),
        .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
    ) dut (
        .clk_i(clk),
        .reset_i(reset),
        .data_i(data_i),
        .weight_i(weight_i),
        .data_v_o(data_v_o),
        .weight_h_o(weight_h_o),
        .result(result)
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
        logic signed [QUANTIZED_WIDTH-1:0] data [B-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] weights [B-1:0]
    );
        $write("%s: data = [", test_name);
        for (int i = 0; i < B; i++) begin
            $write("%d", $signed(data[i]));
            if (i < B-1) $write(", ");
        end
        $write("], weights = [");
        for (int i = 0; i < B; i++) begin
            $write("%d", $signed(weights[i]));
            if (i < B-1) $write(", ");
        end
        $write("]\n");
    endfunction
    
    // Test case function to calculate expected result
    function automatic logic signed [RESULT_WIDTH-1:0] calculate_expected(
        logic signed [QUANTIZED_WIDTH-1:0] data [B-1:0],
        logic signed [QUANTIZED_WIDTH-1:0] weights [B-1:0],
        logic signed [RESULT_WIDTH-1:0] prev_result
    );
        logic signed [RESULT_WIDTH-1:0] sum = 0;
        for (int i = 0; i < B; i++) begin
            sum += data[i] * weights[i];
        end
        return prev_result + sum;
    endfunction
    
    initial begin
        // Initialize signals
        reset = 1;
        expected_result = 0;
        
        for (int i = 0; i < B; i++) begin
            data_i[i] = 0;
            weight_i[i] = 0;
        end
        
        // Test 1: Reset active
        @(posedge clk);
        $display("Test 1: Reset active, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 2: Release reset
        reset = 0;
        @(posedge clk);
        $display("Test 2: Reset inactive, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 3: Basic dot product calculation
        for (int i = 0; i < B; i++) begin
            data_i[i] = i + 1;         // [1, 2, 3, 4]
            weight_i[i] = 1;           // [1, 1, 1, 1]
        end
        print_arrays("Test 3", data_i, weight_i);
        
        // Wait for these inputs to be processed
        @(posedge clk);
        
        // Calculate what the result should be after the inputs were processed
        expected_result = calculate_expected(
            '{1, 2, 3, 4},  // The inputs we just applied
            '{1, 1, 1, 1},  // The weights we just applied
            0               // Previous accumulation (0 here as we started fresh)
        );
        
        $display("Test 3: Basic dot product, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 4: Dot product with negative weights
        for (int i = 0; i < B; i++) begin
            data_i[i] = i + 1;         // [1, 2, 3, 4]
            weight_i[i] = -1;          // [-1, -1, -1, -1]
        end
        print_arrays("Test 4", data_i, weight_i);
        
        @(posedge clk);
        
        // Expected is now previous result plus new calculation
        expected_result = calculate_expected(
            '{1, 2, 3, 4},      // The inputs we just applied
            '{-1, -1, -1, -1},  // The weights we just applied
            expected_result     // Previous accumulation (from Test 3)
        );
        
        $display("Test 4: Negative weights, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 5: Mixed dot product
        data_i[0] = 10;    weight_i[0] = -5;
        data_i[1] = -7;    weight_i[1] = 3;
        data_i[2] = 12;    weight_i[2] = 4;
        data_i[3] = -9;    weight_i[3] = -6;
        print_arrays("Test 5", data_i, weight_i);
        
        @(posedge clk);
        
        expected_result = calculate_expected(
            '{10, -7, 12, -9},  // The inputs we just applied
            '{-5, 3, 4, -6},    // The weights we just applied
            expected_result     // Previous accumulation
        );
        
        $display("Test 5: Mixed values, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 6: Accumulation over multiple cycles
        data_i[0] = 5;     weight_i[0] = 5;
        data_i[1] = 5;     weight_i[1] = 5;
        data_i[2] = 5;     weight_i[2] = 5;
        data_i[3] = 5;     weight_i[3] = 5;
        print_arrays("Test 6", data_i, weight_i);
        
        @(posedge clk);
        
        expected_result = calculate_expected(
            '{5, 5, 5, 5},    // The inputs we just applied
            '{5, 5, 5, 5},    // The weights we just applied
            expected_result   // Previous accumulation
        );
        
        $display("Test 6: Accumulation cycle 1, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 7: Continue accumulation
        data_i[0] = 10;    weight_i[0] = 10;
        data_i[1] = 10;    weight_i[1] = 10;
        data_i[2] = 10;    weight_i[2] = 10;
        data_i[3] = 10;    weight_i[3] = 10;
        print_arrays("Test 7", data_i, weight_i);
        
        @(posedge clk);
        
        expected_result = calculate_expected(
            '{10, 10, 10, 10},  // The inputs we just applied
            '{10, 10, 10, 10},  // The weights we just applied
            expected_result     // Previous accumulation
        );
        
        $display("Test 7: Accumulation cycle 2, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 8: Check systolic pass-through
        data_i[0] = 20;    weight_i[0] = 30;
        data_i[1] = 21;    weight_i[1] = 31;
        data_i[2] = 22;    weight_i[2] = 32;
        data_i[3] = 23;    weight_i[3] = 33;
        print_arrays("Test 8", data_i, weight_i);
        
        @(posedge clk);
        
        expected_result = calculate_expected(
            '{20, 21, 22, 23},  // The inputs we just applied
            '{30, 31, 32, 33},  // The weights we just applied
            expected_result     // Previous accumulation
        );
        
        // Check pass-through outputs
        $write("Test 8: Systolic pass-through data = [");
        for (int i = 0; i < B; i++) begin
            $write("%d", $signed(data_v_o[i]));
            if (i < B-1) $write(", ");
        end
        $write("], weights = [");
        for (int i = 0; i < B; i++) begin
            $write("%d", $signed(weight_h_o[i]));
            if (i < B-1) $write(", ");
        end
        $write("]\n");
        
        $display("Test 8: Accumulation cycle 3, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 9: Reset again
        reset = 1;
        @(posedge clk);
        
        expected_result = 0;  // Reset makes the expected value 0
        
        $display("Test 9: Reset active, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test 10: Check the boundary values
        reset = 0;
        data_i[0] = 127;   weight_i[0] = 127;   // Max positive INT8
        data_i[1] = -128;  weight_i[1] = -128;  // Min negative INT8
        data_i[2] = 127;   weight_i[2] = -128;
        data_i[3] = -128;  weight_i[3] = 127;
        print_arrays("Test 10", data_i, weight_i);
        
        @(posedge clk);
        
        expected_result = calculate_expected(
            '{127, -128, 127, -128},   // The inputs we just applied
            '{127, -128, -128, 127},   // The weights we just applied
            expected_result           // Previous accumulation (0 after reset)
        );
        
        $display("Test 10: Boundary values, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
		          
		  @(posedge clk);
		  @(posedge clk);
		  @(posedge clk);
		  @(posedge clk);
        
        $finish;
    end
endmodule