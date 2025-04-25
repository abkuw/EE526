// Abhishek Kumar, Keith Phou
// EE 526

// Module to add 5 8-bit numbers together with signed numbers
module five_number_adder_signed_8bit(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    input [7:0] e,
    output [7:0] sum // 8-bit output with saturation for 2's complement
);
    // Treat MSB as sign bit for sign extension
    wire [8:0] sum1;   // 9 bits for a+b
    wire [9:0] sum2;   // 10 bits for a+b+c
    wire [10:0] sum3;  // 11 bits for a+b+c+d
    wire [10:0] final_sum; // 11 bits for a+b+c+d+e
    
    // Step 1: Add a and b with sign extension
    // For a: replicate sign bit (a[7]) once, concatenate with a
    assign sum1 = {a[7], a} + {b[7], b};
    
    // Step 2: Add c to the previous sum with sign extension
    assign sum2 = {sum1[8], sum1} + {{2{c[7]}}, c};
    
    // Step 3: Add d to the previous sum with sign extension
    assign sum3 = {sum2[9], sum2} + {{3{d[7]}}, d};
    
    // Step 4: Add e to get the final sum with sign extension
    assign final_sum = sum3 + {{3{e[7]}}, e};
    
    // Saturation logic for signed values
    wire overflow_pos, overflow_neg;
    
    // Detect positive overflow: if all high-order bits are 0 but result MSB is 1
    assign overflow_pos = (final_sum[10:7] == 4'b0000) ? 1'b0 : 
                         (final_sum[10] == 1'b0) ? 1'b1 : 1'b0;
    
    // Detect negative overflow: if all high-order bits are 1 but result MSB is 0
    assign overflow_neg = (final_sum[10:7] == 4'b1111) ? 1'b0 : 
                         (final_sum[10] == 1'b1) ? 1'b1 : 1'b0;
    
    // Apply saturation based on overflow
    assign sum = overflow_pos ? 8'b01111111 :  // Saturate to 127 (max positive)
                overflow_neg ? 8'b10000000 :  // Saturate to -128 (max negative)
                final_sum[7:0];              // No overflow, use actual result
    
endmodule