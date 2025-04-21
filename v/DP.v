/**
DP module to do multiplication, addition and accumulation
*/

module DP #(parameter B = 4, 
            parameter quantized_width = 8)
    (
        input clk_i,
        input reset_i,
        input [quantized_width-1:0] data_i,
        input [quantized_width-1:0] weight_i,
        output [quantized_width-1:0] data_h_o,
        output[quantized_width-1:0] data_v_o,
        output[quantized_width-1:0] weight_v_o,
        output[2*quantized_width-1:0] result;
        
    );
    logic [2*quantized_width-1:0] product;            // Multiplication result
    


    always_comb begin
        product = $signed (data_i) * $signed(weight_i) ;
    
    end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if(reset_i) begin
            weight_v_o <=0;
            data_h_o <=0;
            result <=0
        end
        else begin
            weight_v_o <= weight_i;
            data_h_o <= data_i;
            result <= result+ product;
        end



    end








endmodule

