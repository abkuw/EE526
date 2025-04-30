// Abhishek Kumar, Keith Phou
// EE 526

module BERT_top #(
    // Model parameters
    parameter S = 64,             // Number of tokens per batch
    parameter D_MODEL = 768,      // Number of features
    parameter H = 12,             // Number of heads
    parameter L = 12,             // Number of layers
    parameter D_HEAD = D_MODEL/H, // Features per head (64)
    
    // STA parameters
    parameter A = 2,              // STA dimension parameter
    parameter C = 2,              // STA dimension parameter
    parameter B = 4,              // STA dimension parameter
    parameter M = 32,             // STA array size
    parameter N = 32,             // STA array size
    parameter QUANT_SIZE = 8      // Quantized integer bit width
) (
    input  logic                clk_i,
    input  logic                reset_i,
    
    // External memory interface (71MB) for weight and bias 
    input  logic [4095:0]       ext_mem_rdata,     // 512x8bit = 4096bit max read width
    output logic [31:0]         ext_mem_raddr,
    output logic                ext_mem_ren,
    output logic [511:0]        ext_mem_wdata,     // 64x8bit = 512bit max write width
    output logic [31:0]         ext_mem_waddr,
    output logic                ext_mem_wen,
    
    // Control signals can use for testing
    input  logic                start_i,
    output logic                done_o,
    
    // Configuration signals
    input  logic [3:0]          op_mode_i,         // Operation mode (MHA, FFN, etc.)
    input  logic [3:0]          layer_id_i         // Current transformer layer ID
);

    // Local signals
    logic [4095:0]              sta_input_data;    // Input data to STA
    logic [4095:0]              sta_weight_data;   // Weight data to STA
    logic [4095:0]              sta_output_data;   // Output data from STA

    // SOFTMAX and LayerNorm modules 
    // LayerNorm: 64x2 input and output

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