// Abhishek Kumar, Keith Phou
// EE 526

// testbench for accumlator
module accumlator_tb();
    localparam int WIDTH = 32;

    logic                 clk;
    logic                 reset;     
    logic                 enable;
    logic [WIDTH-1:0]     in;
    logic [WIDTH-1:0]     out;

    accumlator #(.WIDTH(WIDTH)) dut (
        .clk,
        .reset,     
        .enable, 
        .in,
        .out
    );

    //clock setup
	parameter clock_period = 100;
		
		initial begin
			clk <= 0;
			forever #(clock_period /2) clk <= ~clk;
					
	end

    // Add the number each cycle then reset
    initial begin
        	reset <= 1;                               @(posedge clk);
			reset <= 0; enable <= 0; in <= 'b0;       @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            enable <= 1; in <= 'b1;                   @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            in <= 'd2;                                @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            in <= 'd3;                                @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            in <= 'd4;                                @(posedge clk); // sum should be 10
            @(posedge clk);
            @(posedge clk);
            enable <= 0; in <= 'b1;                   @(posedge clk); // should skip this one
            @(posedge clk);
            @(posedge clk);
        	reset <= 1;                               @(posedge clk);
			reset <= 0;                               @(posedge clk); // rest total
            @(posedge clk);
            @(posedge clk);

        $finsih;
    end

endmodule
