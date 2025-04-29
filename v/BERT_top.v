// Abhishek Kumar, Keith Phou
// EE 526

module BERT_top #(
    //parameter
) (

);
    // SOFTMAX and LayerNorm modules (what wire size? 8 bits)

    // Local SRAM find BSG module possible for this 350KB
    // Output of the SRAM (256 x 8-bit):
        // Input
        // Q
        // SoftMAX (Q*K)
        // Martic A
        // MHA ?
        // FFN1 ?
        //
        // K
        // V

    // 6 to 1 MUX for outputs going to STA

    // 2 to 1 MUX for K and v

    // 2 to 1 MUX for weight/Bias MEM and output of previous MUX

    // instantiate STA

    // 2 to 1 MUX for weight/Bias MEM and partial sum
    
    // 2 to 1 MUX with output of STA or MUX of weight/Bias MEM and partial sum

    // int 8 quantize



endmodule