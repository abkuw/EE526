// Abhishek Kumar, Keith Phou
// EE 526

module STA_tb;

    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars();
    end

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
    integer error_count, cycle;
    logic signed [4*QUANTIZED_WIDTH-1:0] actual, expected;
    // For Sparse task
    int row_a;
    int col_a;
    int row_b;
    int col_b;

    // // Randc for random matrix gen
    // class MatrixElementGenerator;
    //     randc bit signed [QUANTIZED_WIDTH-1:0] value;

    //     // Define a covergroup to track value distributions
    //     covergroup value_coverage;
    //         // Define a coverpoint to track the 'value' variable
    //         coverpoint value {
    //             // Define bins to categorize values
    //             bins negative = {[$:-1]};         // All negative values
    //             bins zero = {0};                  // Exactly zero
    //             bins small_pos = {[1:5]};         // Small positive values
    //             bins medium_pos = {[6:10]};       // Medium positive values
    //             bins large_pos = {[11:$]};        // Large positive values
    //         }
    //     endgroup
        
    //     // Constructor - create the covergroup instance
    //     function new();
    //         value_coverage = new();
    //     endfunction
        
    //     // Function to sample coverage after randomization
    //     function void sample_coverage();
    //         value_coverage.sample();
    //     endfunction

    //     // Constraint the range 
    //     constraint value_range_c {
    //         value inside {[-20:20]}; 
    //     }
    // endclass

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

    // Clock period
    localparam CLK_PERIOD = 100; // 100ns (100MHz)

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        reset = 1;
        clear_acc = 0;
        initialize_zeros();
        
        // Reset the DUT
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        
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

        // Fourth test: Boundary Testing alternating 1 and -1
        $display("\n=== Test Case 4: Boundary Testing ===");
        prepare_boundary_test();
        run_test_cycle();

        // Fifth test: Sparse Array
        $display("\n=== Test Case 5: Sparse Array ===");
        prepare_sparse_test();
        run_test_cycle();

        // Fifth test: Random array
        $display("\n=== Test Case 6: Random Array ===");
        prepare_random_test();
        run_test_cycle();

        // Sixth test: Randc array
        $display("\n=== Test Case 6: Randc Array ===");
        prepare_randc_tests(5);
        //run_test_cycle();
                
        // End simulation
        @(posedge clk);
        @(posedge clk);
        $display("\n=== STA Test Complete ===");
        $finish();
    end

    // Initialize all inputs to zeros
    task initialize_zeros();
        for (i = 0; i < N*B*2; i = i + 1) begin
            data_i[i] = 0;
        end
        
        for (i = 0; i < M*B*2; i = i + 1) begin
            weights_i[i] = 0;
        end
    endtask

    // Initialize arrays to track which elements have been fed
    bit fed_a[A_ROWS][A_COLS];
    bit fed_b[B_ROWS][B_COLS];
    int weight_idx, data_idx;
    int row_a, col_a, row_b, col_b;

    task run_test_cycle();
        // Reset everything
        reset = 1;
        clear_acc = 1;
        initialize_zeros();
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        clear_acc = 0;
        
        //$display("=== Starting New Test with Reset/Clear ===");
        
        // Cycle 0: Feed diagonal 0 (just the top-left element)
        initialize_zeros();
        weights_i[0] = matrix_A[0][0];  // Top-left PE, data from A
        data_i[0] = matrix_B[0][0];     // Top-left PE, data from B
        //$display("Cycle %0d: Feeding diagonal 0", cycle);
        @(posedge clk);
        cycle++;
        
        // Cycle 1: Feed diagonal 1
        initialize_zeros();
        weights_i[0] = matrix_A[0][1];  // A[0][1] to top-left PE
        weights_i[B] = matrix_A[1][0];  // A[1][0] to bottom-left PE
        data_i[0] = matrix_B[1][0];     // B[1][0] to top-left PE
        data_i[B] = matrix_B[0][1];     // B[0][1] to top-right PE
        //$display("Cycle %0d: Feeding diagonal 1", cycle);
        @(posedge clk);
        cycle++;
        
        // Cycle 2: Feed diagonal 2
        initialize_zeros();
        weights_i[0] = matrix_A[0][2];  // A[0][2] to top-left PE
        weights_i[B] = matrix_A[1][1];  // A[1][1] to bottom-left PE
        weights_i[B*2] = matrix_A[2][0]; // A[2][0] to top PE in second row
        data_i[0] = matrix_B[2][0];     // B[2][0] to top-left PE
        data_i[B] = matrix_B[1][1];     // B[1][1] to top-right PE
        data_i[B*2] = matrix_B[0][2];   // B[0][2] to PE in second column
        //$display("Cycle %0d: Feeding diagonal 2", cycle);
        @(posedge clk);
        cycle++;
        
        // Cycle 3: Feed diagonal 3
        initialize_zeros();
        weights_i[0] = matrix_A[0][3];   // A[0][3]
        weights_i[B] = matrix_A[1][2];   // A[1][2]
        weights_i[B*2] = matrix_A[2][1]; // A[2][1]
        weights_i[B*3] = matrix_A[3][0]; // A[3][0]
        data_i[0] = matrix_B[3][0];      // B[3][0]
        data_i[B] = matrix_B[2][1];      // B[2][1]
        data_i[B*2] = matrix_B[1][2];    // B[1][2]
        data_i[B*3] = matrix_B[0][3];    // B[0][3]
        //$display("Cycle %0d: Feeding diagonal 3", cycle);
        @(posedge clk);
        cycle++;
        
        // Cycle 4: Feed diagonal 4
        initialize_zeros();
        weights_i[B] = matrix_A[1][3];   // A[1][3]
        weights_i[B*2] = matrix_A[2][2]; // A[2][2]
        weights_i[B*3] = matrix_A[3][1]; // A[3][1]
        data_i[B] = matrix_B[3][1];      // B[3][1]
        data_i[B*2] = matrix_B[2][2];    // B[2][2]
        data_i[B*3] = matrix_B[1][3];    // B[1][3]
        //$display("Cycle %0d: Feeding diagonal 4", cycle);
        @(posedge clk);
        cycle++;
        
        // Cycle 5: Feed diagonal 5
        initialize_zeros();
        weights_i[B*2] = matrix_A[2][3]; // A[2][3]
        weights_i[B*3] = matrix_A[3][2]; // A[3][2]
        data_i[B*2] = matrix_B[3][2];    // B[3][2]
        data_i[B*3] = matrix_B[2][3];    // B[2][3]
        //$display("Cycle %0d: Feeding diagonal 5", cycle);
        @(posedge clk);
        cycle++;
        
        // Cycle 6: Feed diagonal 6 (just the bottom-right element)
        initialize_zeros();
        weights_i[B*3] = matrix_A[3][3]; // A[3][3]
        data_i[B*3] = matrix_B[3][3];    // B[3][3]
        //$display("Cycle %0d: Feeding diagonal 6", cycle);
        @(posedge clk);
        cycle++;
        
        // Feed zeros for a few more cycles to allow propagation
        initialize_zeros();
        //$display("Feeding zeros...");
        
        // Need additional cycles
        for (i = 0; i < 20; i++) begin
            @(posedge clk);
            cycle++;
        end
        
        //$display("Results should be stable now");
        
        // Display and verify results
        display_results();
        verify_results();
        
        @(posedge clk);
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

    // Test boundary conditions with special matrices
    task prepare_boundary_test();
        // Create matrix A with edge-case values (max/min signed values)
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                if ((i+j) % 2 == 0) 
                    matrix_A[i][j] = (1 << (QUANTIZED_WIDTH-1)) - 1;  // Max positive
                else
                    matrix_A[i][j] = -(1 << (QUANTIZED_WIDTH-1));     // Min negative
            end
        end
        
        // Create matrix B with alternating 1s and -1s
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = ((i+j) % 2 == 0) ? 1 : -1;
            end
        end
        
        // Load matrices and calculate expected results
        map_matrices_to_inputs();
        calculate_expected_result();
    endtask

    // Test with sparse matrices (mostly zeros)
    task prepare_sparse_test();
        // Initialize all to zero
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = 0;
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = 0;
            end
        end

        // Add a few non-zero values at random positions
        for (i = 0; i < 3; i = i + 1) begin
            row_a = $urandom_range(A_ROWS-1);
            col_a = $urandom_range(A_COLS-1);
            matrix_A[row_a][col_a] = $urandom_range(10) + 1;
            
            row_b = $urandom_range(B_ROWS-1);
            col_b = $urandom_range(B_COLS-1);
            matrix_B[row_b][col_b] = $urandom_range(10) + 1;
        end
        
        // Load matrices and calculate expected results
        map_matrices_to_inputs();
        calculate_expected_result();
    endtask

    // Create a new test case for randomized matrices
    task prepare_random_test();
        // Create matrices with random values in a constrained range
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                // Random values between -10 and 10
                matrix_A[i][j] = $urandom_range(20) - 10;
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                // Random values between -10 and 10
                matrix_B[i][j] = $urandom_range(20) - 10;
            end
        end
        
        // Load matrices into STA inputs
        map_matrices_to_inputs();
        // Calculate expected results
        calculate_expected_result();
    endtask

    task prepare_randc_tests(int num_tests);
        MatrixElementGenerator gen_a = new();
        MatrixElementGenerator gen_b = new();
        
        $display("\n=== Starting %0d Randomized Tests with randc ===", num_tests);
        
        for (int test_idx = 0; test_idx < num_tests; test_idx++) begin
            $display("\n=== randc Test Iteration %0d of %0d ===", test_idx+1, num_tests);
            
            // Reset the DUT for each test
            reset = 1;
            clear_acc = 1;
            initialize_zeros();
            @(posedge clk);
            @(posedge clk);
            reset = 0;
            clear_acc = 0;
            
            // Fill matrix A with randc values
            for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                void'(gen_a.randomize());
                matrix_A[i][j] = gen_a.value;
            end
            end
            
            // Fill matrix B with randc values
            for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                void'(gen_b.randomize());
                matrix_B[i][j] = gen_b.value;
            end
            end
            
            // Display the generated matrices
            $display("Test %0d: Matrix A (%0d x %0d):", test_idx+1, A_ROWS, A_COLS);
            for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                $write("%4d ", matrix_A[i][j]);
            end
            $write("\n");
            end
            
            $display("Test %0d: Matrix B (%0d x %0d):", test_idx+1, B_ROWS, B_COLS);
            for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                $write("%4d ", matrix_B[i][j]);
            end
            $write("\n");
            end

            // Calculate the expected results
            calculate_expected_result();
            // Run the test cycle
            run_test_cycle();
        end
        
        // Final summary
        $display("\n=== Completed %0d Randomized Tests ===", num_tests);

    endtask

    // Map reference matrices to STA inputs
    task map_matrices_to_inputs();
        // Mapping here depends on the specific layout of STA
        // For a 2x2 PE grid with 2x2 DPs per PE and B=4: would change later for different sizes
        
        // Map matrix A to weights input
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
                    expected_C[i][j] = expected_C[i][j] + (matrix_A[i][k] * matrix_B[k][j]);
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

    // // Helper function to print coverage bins 
    // function void print_coverage_bins(covergroup cg);
    //     $display("  negative bin coverage: collected");
    //     $display("  zero bin coverage: collected");
    //     $display("  small_pos bin coverage: collected");
    //     $display("  medium_pos bin coverage: collected");
    //     $display("  large_pos bin coverage: collected");
    // endfunction
    
    
endmodule