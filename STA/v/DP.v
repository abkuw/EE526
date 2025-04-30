/**
DP module to do multiplication, addition and accumulation
*/

'include "five_number_adder_signed_8bit.v"
module DP #(parameter B = 4, 
            parameter quantized_width = 8)
    (
        input logic clk_i,
        input logic reset_i,
        input logic prev_acc[quantized_width-1:0],
        input logic [B-1:0] data_i[quantized_width-1:0],
        input logic [B-1:0] weight_i[quantized_width-1:0], 
        output logic [B-1:0] weight_h_o[quantized_size-1:0],
        output logic [B-1:0] data_v_o[quantized_size-1:0],
        output logic [2*quantized_width-1:0] result;
        
    );
    logic [2*quantized_width-1:0] sum_product;            // Multiplication result
    

    logic [B-1:0]partial_product[quantized_width-1:0];

    always_comb begin
    genvar i;
    generate
        for (i = 0; i<B; i = i+1)begin :part_product
        partial_product[i] = data[i]*weight[i]; 
        end
    endgenerate

    end

    five_number_adder_signed_8bit PA #(.a(partial_product[0]),.b(partial_product[1]),.c(partial_product[2]),.d(partial_product[3]),.e(prev_acc))(.sum(product));
    
    always_ff @(posedge clk_i or posedge reset_i) begin
        if(reset_i) begin
            data_v_o <='0;
            weight_h_o <='0;
            result <='0;
        end
        else begin
            weight_h_o <= weight_i;
            data_v_o <= data_i;
            // result <= result+ product;
        end
    end

     accumlator AC(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .in(product),
        .out(result)
    );

endmodule

