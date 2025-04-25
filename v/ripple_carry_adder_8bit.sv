// Abhishek Kumar, Keith Phou
// EE 526

// 8-bit Ripple Carry Adder 
module ripple_carry_adder_8bit(
    input [7:0] a,
    input [7:0] b,
    input cin,
    output [7:0] sum,
    output cout
);
    wire [6:0] c; // Internal carry wires
    
    // Instantiate 8 full adders
    fulladder fa0(a[0], b[0], cin, sum[0], c[0]);
    fulladder fa1(a[1], b[1], c[0], sum[1], c[1]);
    fulladder fa2(a[2], b[2], c[1], sum[2], c[2]);
    fulladder fa3(a[3], b[3], c[2], sum[3], c[3]);
    fulladder fa4(a[4], b[4], c[3], sum[4], c[4]);
    fulladder fa5(a[5], b[5], c[4], sum[5], c[5]);
    fulladder fa6(a[6], b[6], c[5], sum[6], c[6]);
    fulladder fa7(a[7], b[7], c[6], sum[7], cout);
endmodule