// Abhishek Kumar, Keith Phou
// EE 526

// Testbench for the DP module (Digital Processing module for multiply and accumulate)
module DP_tb;
    // Define parameters
    localparam int B = 4;
    localparam int quantized_width = 8;
    
    // Define signals
    logic                            clk_i;
    logic                            reset_i;
    logic [quantized_width-1:0]      data_i;
    logic [quantized_width-1:0]      weight_i;
    logic [quantized_width-1:0]      weight_h_o;
    logic [quantized_width-1:0]      data_v_o;
    logic [2*quantized_width-1:0]    result;
    logic [2*quantized_width-1:0]    expected_result; // To hold expected value for comparison
    logic [2*quantized_width-1:0]    product;  // To calculate product
    
    // Instantiate the device under test
    DP #(
        .B(B),
        .quantized_width(quantized_width)
    ) dut(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .data_i(data_i),
        .weight_i(weight_i),
        .weight_h_o(weight_h_o),
        .data_v_o(data_v_o),
        .result(result)
    );
    
    // Clock generation
    parameter time clock_period = 100ns;
    initial begin
        clk_i = 0;
        forever #(clock_period/2) clk_i = ~clk_i;
    end
    
    initial begin
        // Initialize variables
        expected_result = 0;
        
        // Initialize with reset
        reset_i = 1; data_i = 0; weight_i = 0;
        @(posedge clk_i);
        $display("Test 1: Reset active, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Release reset
        reset_i = 0; data_i = 0; weight_i = 0;
        @(posedge clk_i);
        $display("Test 2: Reset inactive, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Test positive multiplication and accumulation
        data_i = 8'sd10; weight_i = 8'sd5; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = product; // Update expected result after the clock edge
        $display("Test 3: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("          result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("          data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        // Test negative * positive multiplication
        data_i = -8'sd7; weight_i = 8'sd3; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = expected_result + product; // Update expected after clock edge
        $display("Test 4: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("          result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("          data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        // Test positive * negative multiplication
        data_i = 8'sd8; weight_i = -8'sd6; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = expected_result + product; // Update expected after clock edge
        $display("Test 5: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("          result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("          data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        // Test negative * negative multiplication
        data_i = -8'sd9; weight_i = -8'sd4; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = expected_result + product; // Update expected after clock edge
        $display("Test 6: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("          result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("          data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        // Test maximum positive values
        data_i = 8'sh7F; weight_i = 8'sh7F; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = expected_result + product; // Update expected after clock edge
        $display("Test 7: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("          result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("          data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        // Test maximum negative value with zero
        data_i = 8'sh80; weight_i = 8'sh00; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = expected_result + product; // Update expected after clock edge
        $display("Test 8: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("          result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("          data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        // Test reset during operation
        reset_i = 1; data_i = 8'sd1; weight_i = 8'sd1; 
        @(posedge clk_i);
        expected_result = 0; // Reset expected after the clock edge
        $display("Test 9: Reset active, result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        
        // Final test after reset
        reset_i = 0; data_i = 8'sd15; weight_i = 8'sd2; 
        product = $signed(data_i) * $signed(weight_i);
        @(posedge clk_i);
        expected_result = product; // First product after reset
        $display("Test 10: Applied data = %d, weight = %d, expected product = %d", 
                 $signed(data_i), $signed(weight_i), $signed(product));
        $display("           result = %d (Expected: %d)", $signed(result), $signed(expected_result));
        $display("           data_v_o = %d (Expected: %d), weight_h_o = %d (Expected: %d)",
                 $signed(data_v_o), $signed(data_i), $signed(weight_h_o), $signed(weight_i));
        
        $finish;
    end
endmodule
