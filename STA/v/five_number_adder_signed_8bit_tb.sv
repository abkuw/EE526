// Abhishek Kumar, Keith Phou
// EE 526

// Testbench for the signed 5-number adder
module five_number_adder_signed_8bit_tb;
    reg [7:0] a, b, c, d, e;
    wire [7:0] sum;
    reg [10:0] expected; // To hold expected value for comparison
    
    // Instantiate the device under test
    five_number_adder_signed_8bit dut(
        .a(a),
        .b(b),
        .c(c),
        .d(d),
        .e(e),
        .sum(sum)
    );
    
    initial begin
        // Test case 1: All positive numbers
        a = 8'h0A;  // 10 in hex
        b = 8'h0F;  // 15 in hex
        c = 8'h14;  // 20 in hex
        d = 8'h19;  // 25 in hex
        e = 8'h1E;  // 30 in hex
        expected = 11'd100; // Expected: 10+15+20+25+30 = 100
        #10;
        $display("Test 1: %d + %d + %d + %d + %d = %d (Expected: %d)", 
                 $signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
                 $signed(sum), $signed(expected[7:0]));
        
        // Test case 2: All negative numbers
        a = 8'hF6;  // -10 in 2's complement
        b = 8'hF1;  // -15 in 2's complement
        c = 8'hEC;  // -20 in 2's complement
        d = 8'hE7;  // -25 in 2's complement
        e = 8'hE2;  // -30 in 2's complement
        expected = -11'd100; // Expected: -10+(-15)+(-20)+(-25)+(-30) = -100
        #10;
        $display("Test 2: %d + %d + %d + %d + %d = %d (Expected: %d)", 
                 $signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
                 $signed(sum), $signed(expected[7:0]));
        
        // Test case 3: Mix of positive and negative
        a = 8'h32;  // 50 in hex
        b = 8'hEC;  // -20 in 2's complement
        c = 8'h1E;  // 30 in hex
        d = 8'hF1;  // -15 in 2's complement
        e = 8'h05;  // 5 in hex
        expected = 11'd50; // Expected: 50+(-20)+30+(-15)+5 = 50
        #10;
        $display("Test 3: %d + %d + %d + %d + %d = %d (Expected: %d)", 
                 $signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
                 $signed(sum), $signed(expected[7:0]));
        
        // Test case 4: Positive saturation (> 127)
        a = 8'h64;  // 100 in hex
        b = 8'h64;  // 100 in hex
        c = 8'h64;  // 100 in hex
        d = 8'h64;  // 100 in hex
        e = 8'h64;  // 100 in hex
        expected = 11'd500; // Expected: 100+100+100+100+100 = 500 (saturated to 127)
        #10;
        $display("Test 4: %d + %d + %d + %d + %d = %d (Expected: 127 due to saturation)", 
                 $signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
                 $signed(sum));
        
        // Test case 5: Negative saturation (< -128)
        a = 8'h9C;  // -100 in 2's complement
        b = 8'h9C;  // -100 in 2's complement
        c = 8'h9C;  // -100 in 2's complement
        d = 8'h9C;  // -100 in 2's complement
        e = 8'h9C;  // -100 in 2's complement
        expected = -11'd500; // Expected: -100+(-100)+(-100)+(-100)+(-100) = -500 (saturated to -128)
        #10;
        $display("Test 5: %d + %d + %d + %d + %d = %d (Expected: -128 due to saturation)", 
                 $signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
                 $signed(sum));
        
        // Test case 6: Edge cases
        a = 8'h7F;  // 127 (maximum positive)
        b = 8'h7F;  // 127
        c = 8'h80;  // -128 (maximum negative)
        d = 8'h80;  // -128
        e = 8'h00;  // 0
        expected = -11'd2; // Expected: 127+127+(-128)+(-128)+0 = -2
        #10;
        $display("Test 6: %d + %d + %d + %d + %d = %d (Expected: %d)", 
                 $signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
                 $signed(sum), $signed(expected[7:0]));
					  
			// Test case 7: Simple negative + positive (-5 + 3 = -2, other inputs 0)
			a = 8'hFB;  // -5 in 2's complement
			b = 8'h03;  // +3
			c = 8'h00;
			d = 8'h00;
			e = 8'h00;
			expected = -11'd2; // -5 + 3 = -2
			#10;
			$display("Test 7: %d + %d + %d + %d + %d = %d (Expected: %d)", 
						$signed(a), $signed(b), $signed(c), $signed(d), $signed(e), 
						$signed(sum), $signed(expected[7:0]));
					  
        $finish;
    end
endmodule