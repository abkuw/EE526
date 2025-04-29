// Abhishek Kumar, Keith Phou
// EE 526

module fulladder(
    input a, b, cin, 
    output sum, cout
    );
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);
endmodule