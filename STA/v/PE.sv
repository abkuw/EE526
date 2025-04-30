`include "v/DP.sv"
`include "/homes/akumar08/basejump_stl/bsg_misc/bsg_buf.v"
module PE #(parameter B =4,
            parameter C =2,
            parameter A =2,
            parameter quantized_size = 8)
    (
        input clk_i,
        input reset_i,
        input [2*B -1 :0] data_i[quantized_size-1:0],
        input [2*B-1 :0] weights_i[quantized_size-1:0],
        output [2*B-1:0] data_o[quantized_size-1:0],
        output [2*B-1:0] weights_o[quantized_size-1:0]
        
    );
    //row
    logic [quantized_size-1:0] datadp1_o;
    logic [quantized_size-1:0] weightdp1_o;

    logic [quantized_size-1:0] datadp2_o;
    logic [quantized_size-1:0] weightdp3_o;

    // output is sent to the buffer
    logic [quantized_size-1:0] buff2_i;
    logic [quantized_size-1:0] buff3_i;
    logic [quantized_size-1:0] buff4w_i;
    logic [quantized_size-1:0] buff4d_i;
    //results
    logic resultdp1, resultdp2, resultdp3, resultdp4;

    //first row
    DP DP1 (.clk_i(clk_i),.reset_i(reset_i),.data_i(data_i[quantized_size/2 -1 :0]),.weight_i(weights_i[quantized_size/2 -1:0]),.weight_h_o(weightdp1_o),.data_v_o(datadp1_o),.result(resultdp1));
    DP DP2 (.clk_i(clk_i),.reset_i(reset_i),.data_i(data_i[quantized_size-1 :quantized_size/2+1]),.weight_i(weightdp1_o),.weight_h_o(buff2_i),.data_v_o(datadp2_o),.result(resultdp2));
 
    //second row
    DP DP3 (.clk_i(clk_i),.reset_i(reset_i),.data_i(datadp1_o),.weight_i(weights_i[quantized_size-1:quantized_size/2+1]),.weight_h_o(weightdp3_o),.data_v_o(buff3_i),.result(resultdp3));
    DP DP4 (.clk_i(clk_i),.reset_i(reset_i),.data_i(datadp2_o),.weight_i(weightdp3_o),.weight_h_o(buff4w_i),.data_v_o(buff4d_i),.result(resultdp4));

    bsg_buf #(.width_p(quantized_size)) buff2(.i(buff2_i),.o(data_o[quantized_size/2-1:0]));
    bsg_buf #(.width_p(quantized_size)) buff3(.i(buff3_i),.o(weights_o[quantized_size/2-1:0]));
    bsg_buf #(.width_p(quantized_size)) buff4w(.i(buff4w_i),.o(weights_o[quantized_size-1:quantized_size/2+1]));
    bsg_buf #(.width_p(quantized_size)) buff4d(.i(buff4d_i),.o(data_o[quantized_size-1: quantized_size/2+1]));


endmodule
