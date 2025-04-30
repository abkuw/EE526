// Abhishek Kumar, Keith Phou
// EE 526

`timescale 1ns / 1ps

module tb_STA;
    // Parameters
    parameter N = 4;     // Using smaller dimensions for initial testing
    parameter M = 4;
    parameter A = 2;
    parameter C = 2;
    parameter B = 1;     // Assuming B=1 for 8-bit data width
    
    // Testbench signals
    logic clk_i;
    logic reset_i;
    logic [8*B-1:0] data_i [M-1:0];
    logic [8*B-1:0] weights_i [N-1:0];
    logic [31:0] results_o [M-1:0][N-1:0];
    
    // Instantiate the STA module
    STA #(
        .N(N),
        .M(M),
        .A(A),
        .C(C),
        .B(B)  // Adding B parameter
    ) sta_inst (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .data_i(data_i),
        .weights_i(weights_i),
        .results_o(results_o)
    );
	 
	//clock setup
	parameter clock_period = 100;

	initial begin
		clk_i <= 0;
		forever #(clock_period /2) clk_i <= ~clk_i;
					
	end
	
	 // For result checking
    integer i, j;
    
    // Test stimulus
    initial begin
        // Initialize inputs
        reset_i = 1;
        
        // Initialize arrays explicitly instead of using loops
        data_i[0] = 8'h00;
        data_i[1] = 8'h00;
        data_i[2] = 8'h00;
        data_i[3] = 8'h00;
        
        weights_i[0] = 8'h00;
        weights_i[1] = 8'h00;
        weights_i[2] = 8'h00;
        weights_i[3] = 8'h00;
        
        // Apply reset
        #20 reset_i = 0;
        #10 reset_i = 1;
        
        // Apply test vectors
        #10;
        
        // Test Case 1: Simple matrix multiplication pattern
        $display("Starting Test Case 1");
        
        // Set data values explicitly
        data_i[0] = 8'h01;
        data_i[1] = 8'h02;
        data_i[2] = 8'h03;
        data_i[3] = 8'h04;
        
        // Set weight values explicitly
        weights_i[0] = 8'h01;
        weights_i[1] = 8'h02;
        weights_i[2] = 8'h03;
        weights_i[3] = 8'h04;
        
        // Wait for computation to complete
        #100; // might change later
        
        // Display results (using fixed indices instead of loops)
        $display("Results for Test Case 1:");
        for (i = 0; i < M; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                $display("results_o[%0d][%0d] = %0d", i, j, results_o[i][j]);
            end
        end
        
        // Test Case 2: Another test pattern
        #10;
        $display("Starting Test Case 2");
        
        // Set data values for test case 2
        data_i[0] = 8'h02;
        data_i[1] = 8'h04;
        data_i[2] = 8'h06;
        data_i[3] = 8'h08;
        
        // Set all weights to 1
        weights_i[0] = 8'h01;
        weights_i[1] = 8'h01;
        weights_i[2] = 8'h01;
        weights_i[3] = 8'h01;
        
        // Wait for computation
        #100;
        
        // Display results
        $display("Results for Test Case 2:");
        for (i = 0; i < M; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                $display("results_o[%0d][%0d] = %0d", i, j, results_o[i][j]);
            end
        end
        
        // End simulation
        #100 $finish;
    end
    
endmodule
