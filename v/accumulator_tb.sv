// Abhishek Kumar, Keith Phou
// EE 526
// Testbench for the accumulator
module accumulator_tb;
    // Define parameters
    localparam int WIDTH = 32;
    
    // Define signals
    reg                 clk;
    reg                 reset;     
    reg [WIDTH-1:0]     in;
    wire [WIDTH-1:0]    out;
    reg [WIDTH-1:0]     expected; // To hold expected value for comparison
    
    // Instantiate the device under test
    accumulator #(.WIDTH(WIDTH)) dut(
        .clk(clk),
        .reset(reset),
        .in(in),
        .out(out)
    );
    
    // Clock generation
    parameter clock_period = 100;
    initial begin
        clk = 0;
        forever #(clock_period/2) clk = ~clk;
    end
    
    initial begin
        // Initialize with reset
        reset = 1; in = 0; expected = 0;
        @(posedge clk);
        $display("Test 1: Reset active, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Release reset
        reset = 0; in = 0; expected = 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 2: Reset inactive, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Add positive value
        in = 'd10; expected = 'd10;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 3: Add 10, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Add negative value
        in = -'d5; expected = 'd5; // 10 + (-5) = 5
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 4: Add -5, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Add another negative value
        in = -'d15; expected = -'d10; // 5 + (-15) = -10
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 5: Add -15, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Add positive value to negative accumulation
        in = 'd25; expected = 'd15; // -10 + 25 = 15
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 6: Add 25 to -10, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Add large negative value
        in = -'d100; expected = -'d85; // 15 + (-100) = -85
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 7: Add -100, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Add large positive value
        in = 'd200; expected = 'd115; // -85 + 200 = 115
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 8: Add 200, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Reset again
        reset = 1; expected = 'd0;
        @(posedge clk);
        $display("Test 9: Reset active, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        // Final check after reset
        reset = 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Test 10: After reset, out = %d (Expected: %d)", $signed(out), $signed(expected));
        
        $finish;
    end
endmodule
