// Abhishek Kumar, Keith Phou
// EE 526

module adder_tb;
    logic [7:0] a, b;
    logic [7:0] sum;
    logic carry_out;

    Adder #(.WIDTH(8)) dut (
        .a,
        .b,
        .sum,
        .carry_out
    );

    initial begin
        // Test 1
        a = 8'd100; b = 8'd27;
        #10;
        $display("a=%0d, b=%0d, sum=%0d, carry=%b", a, b, sum, carry_out);

        // Test 2
        a = 8'd200; b = 8'd100;
        #10;
        $display("a=%0d, b=%0d, sum=%0d, carry=%b", a, b, sum, carry_out);

        $finish;
    end

endmodule
