/**
DP module to do multiplication, addition and accumulation
*/

// `include "five_number_adder_signed_8bit.sv"
module DP #(parameter B = 4, 
            parameter quantized_width = 8)
    (
        input logic clk_i,
        input logic reset_i,
        input logic prev_acc[quantized_width-1:0],
        input logic [B-1:0] data_i[quantized_width-1:0],
        input logic [B-1:0] weight_i[quantized_width-1:0], 
        output logic [B-1:0] weight_h_o[quantized_width-1:0],
        output logic [B-1:0] data_v_o[quantized_width-1:0],
        output logic [4*quantized_width-1:0] result
        
    );
    logic [4*quantized_width-1:0] sum_product;            // Multiplication result
    

    logic partial_product[quantized_width-1:0];

   
    genvar i;
    generate
        for (i = 0; i<B; i = i+1)begin :part_product
        assign partial_product = data_i[i]*weight_i[i]; 
        assign sum_prioduct = partial_product + sum_product;
        end
    endgenerate


    always_ff @(posedge clk_i or posedge reset_i) begin
        if(reset_i) begin
            data_v_o <='0;
            weight_h_o <='0;
            result <='0;
        end
        else begin
            weight_h_o <= weight_i;
            data_v_o <= data_i;
            result <= result+ sum_product;
        end
    end

     accumulator AC(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .in(product),
        .out(result)
    );

endmodule

