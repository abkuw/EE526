`timescale 1ns/1ps

module STA_tb;
    // Parameters
    localparam N = 2;                  // Number of PE columns
    localparam M = 2;                  // Number of PE rows
    localparam B = 4;                  // Multipliers per DP
    localparam QUANTIZED_WIDTH = 8;    // Bit-width of inputs
    
    // Test matrix dimensions for reference
    localparam A_ROWS = M * 2;  // Input A matrix rows (matches PE grid M*2 for 2x2 DPs per PE)
    localparam A_COLS = B;      // Input A matrix columns (equals B)
    localparam B_ROWS = B;      // Input B matrix rows (equals B)
    localparam B_COLS = N * 2;  // Input B matrix columns (matches PE grid N*2 for 2x2 DPs per PE)

    // Clock and reset
    logic clk;
    logic reset;
    logic clear_acc;

    // Input signals
    logic signed [QUANTIZED_WIDTH-1:0] data_i[N*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[M*B*2-1:0];
    
    // Output signals
    logic signed [QUANTIZED_WIDTH-1:0] data_o[N*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[M*B*2-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0][2-1:0][2-1:0];

    // Test matrices for reference calculations
    logic signed [QUANTIZED_WIDTH-1:0] matrix_A[A_ROWS-1:0][A_COLS-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] matrix_B[B_ROWS-1:0][B_COLS-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] expected_C[A_ROWS-1:0][B_COLS-1:0];

    // Variables used in tasks
    integer i, j, k, pe_row, pe_col, dp_row, dp_col, row_idx, col_idx;
    integer error_count;
    logic signed [4*QUANTIZED_WIDTH-1:0] actual, expected;

    // DUT instantiation
    STA #(
        .N(N),
        .M(M),
        .B(B),
        .QUANTIZED_WIDTH(QUANTIZED_WIDTH)
    ) dut (
        .clk_i(clk),
        .reset_i(reset),
        .clear_acc_i(clear_acc),
        .data_i(data_i),
        .weights_i(weights_i),
        .data_o(data_o),
        .weights_o(weights_o),
        .result_o(result_o)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end

    // Test stimulus
    initial begin
        // Initialize signals
        reset = 1;
        clear_acc = 0;
        initialize_data_and_weights();
        
        // Reset the DUT
        #20 reset = 0;
        
        $display("=== Starting STA Test ===");
        $display("Configuration: %0d x %0d PE grid, each PE contains 2x2 DPs, B=%0d", M, N, B);
        
        // First test: Identity matrices
        $display("\n=== Test Case 1: Identity-like Matrices ===");
        prepare_identity_test();
        run_test_cycle();
        
        // Second test: Constant matrices
        $display("\n=== Test Case 2: Constant Matrices ===");
        prepare_constant_test();
        run_test_cycle();

        // Third test: Sequential values
        $display("\n=== Test Case 3: Sequential Values ===");
        prepare_sequential_test();
        run_test_cycle();
        
        // End simulation
        #20 $display("\n=== STA Test Complete ===");
        $finish;
    end

    // Initialize all inputs to zeros
    task initialize_data_and_weights();
        for (i = 0; i < N*B*2; i = i + 1) begin
            data_i[i] = 0;
        end
        
        for (i = 0; i < M*B*2; i = i + 1) begin
            weights_i[i] = 0;
        end
    endtask

    // Run a full test cycle
    task run_test_cycle();
        // Clear accumulators to start new computation
        clear_acc = 1;
        #10 clear_acc = 0;
        
        // Allow cycles for data to propagate through the array
        // For an M×N array, we need at least M+N-1 cycles for full propagation
        $display("Running systolic array for %0d cycles...", M+N+5);
        for (i = 0; i < M+N+5; i = i + 1) begin
            #10; // Wait one clock cycle
        end
        
        // Display and verify results
        display_results();
        verify_results();
    endtask

    // Prepare identity-like test matrices
    task prepare_identity_test();
        // Create reference matrices for calculation
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = (i == j) ? 1 : 0;
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = (i == j) ? 1 : 0;
            end
        end
        
        // Load matrices into STA inputs in the correct format
        map_matrices_to_inputs();
        
        // Calculate expected results
        calculate_expected_result();
    endtask

    // Prepare constant value test matrices
    task prepare_constant_test();
        // A matrix with all 2's
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = 2;
            end
        end
        
        // B matrix with all 3's
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = 3;
            end
        end
        
        // Load matrices into STA inputs
        map_matrices_to_inputs();
        
        // Calculate expected results
        calculate_expected_result();
    endtask

    // Prepare sequential value test matrices
    task prepare_sequential_test();
        // A matrix with sequential values
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = i*A_COLS + j + 1;
            end
        end
        
        // B matrix with sequential values
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = i*B_COLS + j + 1;
            end
        end
        
        // Load matrices into STA inputs
        map_matrices_to_inputs();
        
        // Calculate expected results
        calculate_expected_result();
    endtask

    // Map reference matrices to STA inputs
    task map_matrices_to_inputs();
        // The mapping here depends on the specific layout of your STA
        // For a 2x2 PE grid with 2x2 DPs per PE and B=4:
        
        // Map matrix A to weights input
        // This is a simplified mapping and would need to be adjusted
        // based on how your PE processes the weights
        for (pe_row = 0; pe_row < M; pe_row = pe_row + 1) begin
            for (dp_row = 0; dp_row < 2; dp_row = dp_row + 1) begin
                for (k = 0; k < B; k = k + 1) begin
                    row_idx = pe_row * 2 + dp_row;
                    i = pe_row * (2*B) + dp_row * B + k;
                    weights_i[i] = matrix_A[row_idx][k];
                end
            end
        end
        
        // Map matrix B to data input
        // This is a simplified mapping and would need to be adjusted
        // based on how your PE processes the data
        for (pe_col = 0; pe_col < N; pe_col = pe_col + 1) begin
            for (dp_col = 0; dp_col < 2; dp_col = dp_col + 1) begin
                for (k = 0; k < B; k = k + 1) begin
                    col_idx = pe_col * 2 + dp_col;
                    j = pe_col * (2*B) + dp_col * B + k;
                    data_i[j] = matrix_B[k][col_idx];
                end
            end
        end
        
        // Display the input matrices for reference
        $display("Matrix A (%0d x %0d):", A_ROWS, A_COLS);
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                $write("%4d ", matrix_A[i][j]);
            end
            $write("\n");
        end
        
        $display("Matrix B (%0d x %0d):", B_ROWS, B_COLS);
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                $write("%4d ", matrix_B[i][j]);
            end
            $write("\n");
        end
    endtask

    // Calculate expected result matrix
    task calculate_expected_result();
        // Initialize expected result matrix to zeros
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                expected_C[i][j] = 0;
            end
        end
        
        // Calculate matrix multiplication A * B = C
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                expected_C[i][j] = 0;
                for (k = 0; k < A_COLS; k = k + 1) begin
                    expected_C[i][j] = expected_C[i][j] + matrix_A[i][k] * matrix_B[k][j];
                end
            end
        end
        
        // Display expected result matrix
        $display("Expected Result Matrix (%0d x %0d):", A_ROWS, B_COLS);
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                $write("%8d ", expected_C[i][j]);
            end
            $write("\n");
        end
    endtask

    // Display current state of inputs, outputs, and results
    task display_results();
        $display("\n=== STA Results ===");
        
        // Display results from each PE
        $display("Result Matrix from PE Grid:");
        for (pe_row = 0; pe_row < M; pe_row = pe_row + 1) begin
            for (dp_row = 0; dp_row < 2; dp_row = dp_row + 1) begin
                for (pe_col = 0; pe_col < N; pe_col = pe_col + 1) begin
                    for (dp_col = 0; dp_col < 2; dp_col = dp_col + 1) begin
                        $write("%8d ", result_o[pe_row][pe_col][dp_row][dp_col]);
                    end
                end
                $write("\n");
            end
        end
    endtask

    // Verify PE results against expected values
    task verify_results();
        $display("\n=== Verification ===");
        error_count = 0;
        
        // Compare each element of the result matrix with the expected value
        for (pe_row = 0; pe_row < M; pe_row = pe_row + 1) begin
            for (dp_row = 0; dp_row < 2; dp_row = dp_row + 1) begin
                for (pe_col = 0; pe_col < N; pe_col = pe_col + 1) begin
                    for (dp_col = 0; dp_col < 2; dp_col = dp_col + 1) begin
                        row_idx = pe_row * 2 + dp_row;
                        col_idx = pe_col * 2 + dp_col;
                        actual = result_o[pe_row][pe_col][dp_row][dp_col];
                        expected = expected_C[row_idx][col_idx];
                        
                        if (actual != expected) begin
                            $display("Error at position [%0d,%0d]: Expected=%0d, Actual=%0d",
                                     row_idx, col_idx, expected, actual);
                            error_count = error_count + 1;
                        end
                    end
                end
            end
        end
        
        if (error_count == 0) begin
            $display("PASS: All results match expected values!");
        end else begin
            $display("FAIL: %0d verification errors found!", error_count);
        end
    endtask
    
endmodule