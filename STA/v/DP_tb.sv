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
    logic                          clear_acc;  // New signal to clear accumulator  
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
        .clear_acc_i(clear_acc),  // Connect the new signal
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
        clear_acc = 0;
        expected_result = 0;
        
        for (int i = 0; i < B; i++) begin
            data_i[i] = 0;
            weight_i[i] = 0;
        end
        
        // Test 1: Reset active
        @(posedge clk);
        $display("Test 1: Reset active, result = %d (Expected: %d)", $signed(result), 0);
        
        // Test 2: Release reset
        reset = 0;
        @(posedge clk);
        $display("Test 2: Reset inactive, result = %d (Expected: %d)", $signed(result), 0);
        
        // Test 3: Basic dot product calculation
        // Set inputs for test 3
        for (int i = 0; i < B; i++) begin
            data_i[i] = i + 1;         // [1, 2, 3, 4]
            weight_i[i] = 1;           // [1, 1, 1, 1]
        end
        print_arrays("Test 3 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Result should now reflect the dot product of [1,2,3,4] * [1,1,1,1] = 10
        expected_result = 10;  // 1*1 + 2*1 + 3*1 + 4*1 = 10
        $display("Test 3: Basic dot product, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 4: Dot product with negative weights
        // Set inputs for test 4
        for (int i = 0; i < B; i++) begin
            data_i[i] = i + 1;         // [1, 2, 3, 4]
            weight_i[i] = -1;          // [-1, -1, -1, -1]
        end
        print_arrays("Test 4 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Result should now reflect the accumulated dot product: 
        // Previous 10 + ([1,2,3,4] * [-1,-1,-1,-1]) = 10 + (-10) = 0
        expected_result = 0;  // Previous 10 + dot product of -10
        $display("Test 4: Negative weights, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 5: Clear accumulator using clear_acc signal
        clear_acc = 1;  // Assert clear_acc signal
        data_i[0] = 10;    weight_i[0] = -5;
        data_i[1] = -7;    weight_i[1] = 3;
        data_i[2] = 12;    weight_i[2] = 4;
        data_i[3] = -9;    weight_i[3] = -6;
        print_arrays("Test 5 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        clear_acc = 0;  // De-assert clear_acc signal
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Since we cleared the accumulator, result should be just this dot product:
        // 10*(-5) + (-7)*3 + 12*4 + (-9)*(-6) = -50 - 21 + 48 + 54 = 31
        expected_result = 31;
        $display("Test 5: Clear accumulator and mixed values, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 6: Accumulation over multiple cycles
        data_i[0] = 5;     weight_i[0] = 5;
        data_i[1] = 5;     weight_i[1] = 5;
        data_i[2] = 5;     weight_i[2] = 5;
        data_i[3] = 5;     weight_i[3] = 5;
        print_arrays("Test 6 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Previous 31 + (5*5 + 5*5 + 5*5 + 5*5) = 31 + 100 = 131
        expected_result = 131;
        $display("Test 6: Accumulation cycle 1, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 7: Continue accumulation
        data_i[0] = 10;    weight_i[0] = 10;
        data_i[1] = 10;    weight_i[1] = 10;
        data_i[2] = 10;    weight_i[2] = 10;
        data_i[3] = 10;    weight_i[3] = 10;
        print_arrays("Test 7 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Previous 131 + (10*10 + 10*10 + 10*10 + 10*10) = 131 + 400 = 531
        expected_result = 531;
        $display("Test 7: Accumulation cycle 2, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 8: Check systolic pass-through with clear_acc
        clear_acc = 1;  // Assert clear_acc signal again
        data_i[0] = 20;    weight_i[0] = 30;
        data_i[1] = 21;    weight_i[1] = 31;
        data_i[2] = 22;    weight_i[2] = 32;
        data_i[3] = 23;    weight_i[3] = 33;
        print_arrays("Test 8 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        clear_acc = 0;  // De-assert clear_acc signal
        
        // Check pass-through outputs immediately after first clock edge
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
        
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Since we cleared the accumulator, result should be just this dot product:
        // 20*30 + 21*31 + 22*32 + 23*33 = 600 + 651 + 704 + 759 = 2714
        expected_result = 2714;
        $display("Test 8: Clear accumulator and check systolic pass-through, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 9: Reset again
        reset = 1;
        @(posedge clk);
        //@(posedge clk); // Add an extra clock cycle for reset to take effect
        expected_result = 0;  // Reset makes the expected value 0
        $display("Test 9: Reset active, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 10: Check the boundary values
        reset = 0;
        data_i[0] = 127;   weight_i[0] = 127;   // Max positive INT8
        data_i[1] = -128;  weight_i[1] = -128;  // Min negative INT8
        data_i[2] = 127;   weight_i[2] = -128;
        data_i[3] = -128;  weight_i[3] = 127;
        print_arrays("Test 10 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // 127*127 + (-128)*(-128) + 127*(-128) + (-128)*127 = 16129 + 16384 - 16256 - 16256 = 1
        expected_result = 1;
        $display("Test 10: Boundary values, result = %d (Expected: %d)", $signed(result), expected_result);
        
        // Test 11: Verify clear_acc doesn't affect data flow
        clear_acc = 1;  // Assert clear_acc signal
        data_i[0] = 1;    weight_i[0] = 1;
        data_i[1] = 1;    weight_i[1] = 1;
        data_i[2] = 1;    weight_i[2] = 1;
        data_i[3] = 1;    weight_i[3] = 1;
        print_arrays("Test 11 inputs", data_i, weight_i);
        
        // First clock edge - inputs are registered
        @(posedge clk);
        clear_acc = 0;  // De-assert clear_acc signal
        
        // Check pass-through outputs immediately after first clock edge
        $write("Test 11: Data flow with clear_acc - data = [");
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
        
        // Second clock edge - outputs are available
        //@(posedge clk);
        
        // Since we cleared the accumulator, result should be just this dot product:
        // 1*1 + 1*1 + 1*1 + 1*1 = 4
        expected_result = 4;
        $display("Test 11: Clear accumulator and verify data flow, result = %d (Expected: %d)", $signed(result), expected_result);
          
        // Extra cycles for any final observations
        @(posedge clk);
        @(posedge clk);
        
        $finish;
    end
endmodule