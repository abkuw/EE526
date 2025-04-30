'include "PE.v"
// Systolic Tensor Array (STA) Module
module STA #(parameter N = 32,
            parameter M =32,
            //PE paramters
            parameter B = 4,
            parameter C = 2,
            parameter A = 2,
            parameter quantized_size = 8
            ),
            (
                input clk_i,
                input reset_i,
                input[N-1:0] data_i[2*B-1:0][quantized_size-1:0],
                input[M-1:0]weights_i[2*B-1:0][quantized_size-1:0],
                output[N-1:0] data_o[2*B-1:0][quantized_size-1:0],
                output[M-1:0]weights_o[2*B-1:0][quantized_size-1:0], 
                

            );

    typedef logic [2*B-1:0]data_element_t[quantized_size-1:0];


    data_element_t data_signals[M:0][N-1:0];
    data_element_t weights_signals[M-1:0][N:0];

    // Connect STA inputs to the first row/column of signals
    assign data_signals[0] = data_i; 

    genvar r;
    generate
        for (r =0; r<M; r=r+1) begin: assign_weights_i
            assign_weights_signals[r][0] = weights_i[r]; 
        end
    endgenerate

    genvar i,j;
    generate
        for(i =0; i<M; i=i+1) begin: row_gen
            for(j=0; j<N; j=j+1) begin : col_gen
                // Instantiate the Processing Element
                PE #(
                    .B(B),
                    .C(C),
                    .A(A),
                    .quantized_size(quantized_size)
                ) pe_inst (
                    .clk_i      (clk_i),
                    .reset_i    (reset_i),
                    // Connect data input from PE above or STA input
                    .data_i     (data_signals[i][j]),
                    // Connect weight input from PE to the left or STA input
                    .weights_i  (weights_signals[i][j]),
                    // Connect data output to PE below or STA output
                    .data_o     (data_signals[i+1][j]),
                    // Connect weight output to PE to the right or STA output
                    .weights_o  (weights_signals[i][j+1])
                );
            end
        end
    endgenerate
    // Connect the last row of data_signals to the output
    assign data_o = data_signals[M];
    genvar k;
    generate
        for(k=0; k<M; k=k+1) begin: assign_weights_o
            assign weights_o[k] =weights_signals[k][N];
        end
    endgenerate
          
endmodule