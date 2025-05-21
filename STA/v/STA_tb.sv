// Abhishek Kumar, Keith Phou
// EE 526 - Systolic Tensor Array (STA) Testbench

module STA_tb;

    //===================================================================
    // Waveform dump and simulation setup
    //===================================================================
    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars();
    end

    //===================================================================
    // Parameters
    //===================================================================
    // Architecture parameters
    localparam N = 2;                  // Number of PE columns
    localparam M = 2;                  // Number of PE rows
    localparam B = 4;                  // Multipliers per DP
    localparam QUANTIZED_WIDTH = 8;    // Bit-width of inputs
    
    // Derived parameters for test matrices
    localparam A_ROWS = M * 2;         // Input A matrix rows
    localparam A_COLS = B;             // Input A matrix columns
    localparam B_ROWS = B;             // Input B matrix rows
    localparam B_COLS = N * 2;         // Input B matrix columns
    localparam CLK_PERIOD = 100;       // Clock period in ns (100MHz)

    //===================================================================
    // Signals and Variables
    //===================================================================
    // Clock and control signals
    logic clk;
    logic reset;
    logic clear_acc;

    // DUT I/O signals
    logic signed [QUANTIZED_WIDTH-1:0] data_i[N*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[M*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] data_o[N*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[M*B*2-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0][2-1:0][2-1:0];

    // Test matrices (reference model)
    logic signed [QUANTIZED_WIDTH-1:0] matrix_A[A_ROWS-1:0][A_COLS-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] matrix_B[B_ROWS-1:0][B_COLS-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] expected_C[A_ROWS-1:0][B_COLS-1:0];

    // Task variables for test execution
    integer i, j, k, pe_row, pe_col, dp_row, dp_col, row_idx, col_idx;
    integer error_count, cycle;
    logic signed [4*QUANTIZED_WIDTH-1:0] actual, expected;
    int row_a, col_a, row_b, col_b;
    bit fed_a[A_ROWS][A_COLS];
    bit fed_b[B_ROWS][B_COLS];
    int weight_idx, data_idx;

    //===================================================================
    // Global Coverage Flags
    //===================================================================
    // Matrix A characteristics flags
    static bit saw_matrix_a_has_zeros = 0;
    static bit saw_matrix_a_no_zeros = 0;
    static bit saw_matrix_a_has_positives = 0;
    static bit saw_matrix_a_no_positives = 0;
    static bit saw_matrix_a_has_negatives = 0;
    static bit saw_matrix_a_no_negatives = 0;
    static bit saw_matrix_a_constant = 0;
    static bit saw_matrix_a_not_constant = 0;

    // Matrix B characteristics flags
    static bit saw_matrix_b_has_zeros = 0;
    static bit saw_matrix_b_no_zeros = 0;
    static bit saw_matrix_b_has_positives = 0;
    static bit saw_matrix_b_no_positives = 0;
    static bit saw_matrix_b_has_negatives = 0;
    static bit saw_matrix_b_no_negatives = 0;
    static bit saw_matrix_b_constant = 0;
    static bit saw_matrix_b_not_constant = 0;

    // Matrix pattern flags
    static bit saw_matrices_are_identity = 0;
    static bit saw_matrices_not_identity = 0;
    static bit saw_matrices_have_diagonal = 0;
    static bit saw_matrices_no_diagonal = 0;

    // Result characteristics flags
    static bit saw_result_has_zeros = 0;
    static bit saw_result_no_zeros = 0;
    static bit saw_result_has_positives = 0;
    static bit saw_result_no_positives = 0;
    static bit saw_result_has_negatives = 0;
    static bit saw_result_no_negatives = 0;
    static bit saw_result_has_large_values = 0;
    static bit saw_result_no_large_values = 0;
    static bit saw_result_has_small_values = 0;
    static bit saw_result_no_small_values = 0;
    static bit saw_result_is_diagonal = 0;
    static bit saw_result_not_diagonal = 0;
    static bit saw_result_is_identity = 0;
    static bit saw_result_not_identity = 0;

    //===================================================================
    // Coverage Classes
    //===================================================================
    
    // Element-level coverage class for individual matrix elements
    class MatrixElementGenerator;
        randc bit signed [QUANTIZED_WIDTH-1:0] value;

        // Value distribution coverage
        covergroup value_coverage;
            coverpoint value {
                bins negative = {[$:-1]};  // Negative values
                bins zero = {0};           // Zero
                bins positive = {[1:$]};   // Positive values
            }
        endgroup
        
        // Constructor
        function new();
            value_coverage = new();
        endfunction
        
        // Coverage sampling method
        function void sample_coverage();
            value_coverage.sample();
        endfunction

        // Constraint for value range
        constraint value_range_c {
            value inside {[-20:20]}; 
        }
    endclass

    // Matrix and result level coverage class
    class MatrixCoverageCollector;
        // Matrix references
        local logic signed [QUANTIZED_WIDTH-1:0] matrix_A[A_ROWS-1:0][A_COLS-1:0];
        local logic signed [QUANTIZED_WIDTH-1:0] matrix_B[B_ROWS-1:0][B_COLS-1:0];
        local logic signed [4*QUANTIZED_WIDTH-1:0] result_matrix[A_ROWS-1:0][B_COLS-1:0];
        
        // Status flags for matrix characteristics
        bit matrix_a_has_zeros, matrix_a_has_positives, matrix_a_has_negatives;
        bit matrix_b_has_zeros, matrix_b_has_positives, matrix_b_has_negatives;
        bit matrices_are_identity, matrices_have_diagonal;
        bit matrix_a_constant, matrix_b_constant;

        // Status flags for result characteristics
        bit result_has_zeros;
        bit result_has_positives;
        bit result_has_negatives;
        bit result_has_large_values;      // Values using more than half the bit width
        bit result_has_small_values;      // Values close to 0 but not 0
        bit result_is_diagonal;           // Non-zero values only on diagonal
        bit result_is_identity;           // Identity matrix result
        
        // Combined coverage group for all characteristics
        covergroup matrix_coverage;
            // Matrix A characteristics
            coverpoint matrix_a_has_zeros {
                bins has_zeros = {1};
                bins no_zeros = {0};
            }
            
            coverpoint matrix_a_has_positives {
                bins has_positives = {1};
                bins no_positives = {0};
            }
            
            coverpoint matrix_a_has_negatives {
                bins has_negatives = {1};
                bins no_negatives = {0};
            }
            
            // Matrix B characteristics
            coverpoint matrix_b_has_zeros {
                bins has_zeros = {1};
                bins no_zeros = {0};
            }
            
            coverpoint matrix_b_has_positives {
                bins has_positives = {1};
                bins no_positives = {0};
            }
            
            coverpoint matrix_b_has_negatives {
                bins has_negatives = {1};
                bins no_negatives = {0};
            }
            
            // Matrix patterns
            coverpoint matrices_are_identity {
                bins is_identity = {1};
                bins not_identity = {0};
            }
            
            coverpoint matrices_have_diagonal {
                bins has_diagonal = {1};
                bins no_diagonal = {0};
            }
            
            coverpoint matrix_a_constant {
                bins is_constant = {1};
                bins not_constant = {0};
            }
            
            coverpoint matrix_b_constant {
                bins is_constant = {1};
                bins not_constant = {0};
            }

            // Result value distribution
            coverpoint result_has_zeros {
                bins has_zeros = {1};
                bins no_zeros = {0};
            }
            
            coverpoint result_has_positives {
                bins has_positives = {1};
                bins no_positives = {0};
            }
            
            coverpoint result_has_negatives {
                bins has_negatives = {1};
                bins no_negatives = {0};
            }
            
            coverpoint result_has_large_values {
                bins has_large = {1};
                bins no_large = {0};
            }
            
            coverpoint result_has_small_values {
                bins has_small = {1};
                bins no_small = {0};
            }
            
            // Result pattern coverage
            coverpoint result_is_diagonal {
                bins is_diagonal = {1};
                bins not_diagonal = {0};
            }
            
            coverpoint result_is_identity {
                bins is_identity = {1};
                bins not_identity = {0};
            }
            
            // Cross coverage between inputs and results
            cross matrix_a_has_negatives, matrix_b_has_negatives, result_has_negatives;
            cross matrix_a_constant, matrix_b_constant, result_is_diagonal;
        endgroup
        
        // Constructor - initialize references and coverage
        function new(ref logic signed [QUANTIZED_WIDTH-1:0] a_matrix[A_ROWS-1:0][A_COLS-1:0], 
                    ref logic signed [QUANTIZED_WIDTH-1:0] b_matrix[B_ROWS-1:0][B_COLS-1:0],
                    ref logic signed [4*QUANTIZED_WIDTH-1:0] expected_result[A_ROWS-1:0][B_COLS-1:0]);
            this.matrix_A = a_matrix;
            this.matrix_B = b_matrix;
            this.result_matrix = expected_result;
            matrix_coverage = new();
        endfunction
        
        //-------------------------------------------------------------------------
        // Matrix Analysis Functions
        //-------------------------------------------------------------------------
        // Check for negative values in a matrix
        function bit has_negative_values(ref logic signed [QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][A_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < A_COLS; j++) begin
                    if (matrix[i][j] < 0) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check for zero values in a matrix
        function bit has_zero_values(ref logic signed [QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][A_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < A_COLS; j++) begin
                    if (matrix[i][j] == 0) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check for positive values in a matrix
        function bit has_positive_values(ref logic signed [QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][A_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < A_COLS; j++) begin
                    if (matrix[i][j] > 0) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check if a matrix is identity
        function bit is_identity_matrix(ref logic signed [QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][A_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < A_COLS; j++) begin
                    if (i == j) begin
                        if (matrix[i][j] != 1) return 0;
                    end else begin
                        if (matrix[i][j] != 0) return 0;
                    end
                end
            end
            return 1;
        endfunction
        
        // Check if a matrix has non-zero diagonal elements
        function bit has_diagonal_pattern(ref logic signed [QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][A_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < A_COLS; j++) begin
                    if (i == j) begin
                        if (matrix[i][j] == 0) return 0;
                    end
                end
            end
            return 1;
        endfunction
        
        // Check if all elements in a matrix have the same value
        function bit has_constant_values(ref logic signed [QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][A_COLS-1:0]);
            logic signed [QUANTIZED_WIDTH-1:0] first_val;
            first_val = matrix[0][0];
            
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < A_COLS; j++) begin
                    if (matrix[i][j] != first_val) return 0;
                end
            end
            return 1;
        endfunction

        //-------------------------------------------------------------------------
        // Result Matrix Analysis Functions
        //-------------------------------------------------------------------------
        // Check for large values in the result matrix
        function bit has_large_values(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            logic signed [4*QUANTIZED_WIDTH-1:0] threshold = 1 << (2*QUANTIZED_WIDTH - 1);
            
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (matrix[i][j] > threshold || matrix[i][j] < -threshold) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check for small (near-zero) values in the result matrix
        function bit has_small_values(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (matrix[i][j] != 0 && matrix[i][j] > -10 && matrix[i][j] < 10) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check if the result matrix is diagonal
        function bit is_result_diagonal(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (i != j && matrix[i][j] != 0) return 0;
                end
            end
            // Make sure diagonal elements are non-zero
            for (int i = 0; i < A_ROWS && i < B_COLS; i++) begin
                if (matrix[i][i] == 0) return 0;
            end
            return 1;
        endfunction
        
        // Check if the result matrix is identity
        function bit is_result_identity(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (i == j) begin
                        if (matrix[i][j] != 1) return 0;
                    end else begin
                        if (matrix[i][j] != 0) return 0;
                    end
                end
            end
            return 1;
        endfunction

        // Check for zero values in the result matrix
        function bit has_zero_values_result(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (matrix[i][j] == 0) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check for positive values in the result matrix
        function bit has_positive_values_result(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (matrix[i][j] > 0) return 1;
                end
            end
            return 0;
        endfunction
        
        // Check for negative values in the result matrix
        function bit has_negative_values_result(ref logic signed [4*QUANTIZED_WIDTH-1:0] matrix[A_ROWS-1:0][B_COLS-1:0]);
            for (int i = 0; i < A_ROWS; i++) begin
                for (int j = 0; j < B_COLS; j++) begin
                    if (matrix[i][j] < 0) return 1;
                end
            end
            return 0;
        endfunction

        //-------------------------------------------------------------------------
        // Coverage Methods
        //-------------------------------------------------------------------------
        // Update global coverage flags
        function void update_global_flags();
            // Update matrix A status
            if (has_zero_values(matrix_A))
                saw_matrix_a_has_zeros = 1;
            else
                saw_matrix_a_no_zeros = 1;
                
            if (has_positive_values(matrix_A))
                saw_matrix_a_has_positives = 1;
            else
                saw_matrix_a_no_positives = 1;
                
            if (has_negative_values(matrix_A))
                saw_matrix_a_has_negatives = 1;
            else
                saw_matrix_a_no_negatives = 1;
                
            if (has_constant_values(matrix_A))
                saw_matrix_a_constant = 1;
            else
                saw_matrix_a_not_constant = 1;
            
            // Update matrix B status
            if (has_zero_values(matrix_B))
                saw_matrix_b_has_zeros = 1;
            else
                saw_matrix_b_no_zeros = 1;
                
            if (has_positive_values(matrix_B))
                saw_matrix_b_has_positives = 1;
            else
                saw_matrix_b_no_positives = 1;
                
            if (has_negative_values(matrix_B))
                saw_matrix_b_has_negatives = 1;
            else
                saw_matrix_b_no_negatives = 1;
                
            if (has_constant_values(matrix_B))
                saw_matrix_b_constant = 1;
            else
                saw_matrix_b_not_constant = 1;
            
            // Update pattern recognition
            if (is_identity_matrix(matrix_A) && is_identity_matrix(matrix_B))
                saw_matrices_are_identity = 1;
            else
                saw_matrices_not_identity = 1;
                
            if (has_diagonal_pattern(matrix_A) || has_diagonal_pattern(matrix_B))
                saw_matrices_have_diagonal = 1;
            else
                saw_matrices_no_diagonal = 1;

            // Update results status
            if (has_zero_values_result(result_matrix))
                saw_result_has_zeros = 1;
            else
                saw_result_no_zeros = 1;
                
            if (has_positive_values_result(result_matrix))
                saw_result_has_positives = 1;
            else
                saw_result_no_positives = 1;
                
            if (has_negative_values_result(result_matrix))
                saw_result_has_negatives = 1;
            else
                saw_result_no_negatives = 1;
                
            if (has_large_values(result_matrix))
                saw_result_has_large_values = 1;
            else
                saw_result_no_large_values = 1;
                
            if (has_small_values(result_matrix))
                saw_result_has_small_values = 1;
            else
                saw_result_no_small_values = 1;
                
            if (is_result_diagonal(result_matrix))
                saw_result_is_diagonal = 1;
            else
                saw_result_not_diagonal = 1;
                
            if (is_result_identity(result_matrix))
                saw_result_is_identity = 1;
            else
                saw_result_not_identity = 1;
        endfunction

        // Sample coverage - analyze matrices and update flags
        function void sample_coverage();
            // Update matrix A status
            matrix_a_has_zeros = has_zero_values(matrix_A);
            matrix_a_has_positives = has_positive_values(matrix_A);
            matrix_a_has_negatives = has_negative_values(matrix_A);
            matrix_a_constant = has_constant_values(matrix_A);
            
            // Update matrix B status
            matrix_b_has_zeros = has_zero_values(matrix_B);
            matrix_b_has_positives = has_positive_values(matrix_B);
            matrix_b_has_negatives = has_negative_values(matrix_B);
            matrix_b_constant = has_constant_values(matrix_B);
            
            // Update pattern recognition
            matrices_are_identity = is_identity_matrix(matrix_A) && is_identity_matrix(matrix_B);
            matrices_have_diagonal = has_diagonal_pattern(matrix_A) || has_diagonal_pattern(matrix_B);

            // Update results status
            result_has_zeros = has_zero_values_result(result_matrix);
            result_has_positives = has_positive_values_result(result_matrix);
            result_has_negatives = has_negative_values_result(result_matrix);
            result_has_large_values = has_large_values(result_matrix);
            result_has_small_values = has_small_values(result_matrix);
            result_is_diagonal = is_result_diagonal(result_matrix);
            result_is_identity = is_result_identity(result_matrix);

            // Update global flags
            update_global_flags();
            
            // Sample the coverage group
            matrix_coverage.sample();
        endfunction
        
        // Get coverage percentage
        function real get_coverage();
            return matrix_coverage.get_coverage();
        endfunction
        
    endclass

    //===================================================================
    // Global Coverage Report Function
    //===================================================================
    function void report_global_coverage;
        // Display coverage report
        $display("\n----- Global Coverage Report -----");
        $display("  Matrices analyzed: A(%0dx%0d), B(%0dx%0d)", A_ROWS, A_COLS, B_ROWS, B_COLS);
        
        // Matrix A characteristics
        $display("\n  Matrix A Characteristics:");
        $display("    Has zeros:     %.2f%% covered", 
                (saw_matrix_a_has_zeros && saw_matrix_a_no_zeros) ? 100.0 : (saw_matrix_a_has_zeros || saw_matrix_a_no_zeros) ? 50.0 : 0.0);
        $display("    Has positives: %.2f%% covered", 
                (saw_matrix_a_has_positives && saw_matrix_a_no_positives) ? 100.0 : (saw_matrix_a_has_positives || saw_matrix_a_no_positives) ? 50.0 : 0.0);
        $display("    Has negatives: %.2f%% covered", 
                (saw_matrix_a_has_negatives && saw_matrix_a_no_negatives) ? 100.0 : (saw_matrix_a_has_negatives || saw_matrix_a_no_negatives) ? 50.0 : 0.0);
        $display("    Is constant:   %.2f%% covered", 
                (saw_matrix_a_constant && saw_matrix_a_not_constant) ? 100.0 : (saw_matrix_a_constant || saw_matrix_a_not_constant) ? 50.0 : 0.0);
        
        // Matrix B characteristics
        $display("\n  Matrix B Characteristics:");
        $display("    Has zeros:     %.2f%% covered", 
                (saw_matrix_b_has_zeros && saw_matrix_b_no_zeros) ? 100.0 : (saw_matrix_b_has_zeros || saw_matrix_b_no_zeros) ? 50.0 : 0.0);
        $display("    Has positives: %.2f%% covered", 
                (saw_matrix_b_has_positives && saw_matrix_b_no_positives) ? 100.0 : (saw_matrix_b_has_positives || saw_matrix_b_no_positives) ? 50.0 : 0.0);
        $display("    Has negatives: %.2f%% covered", 
                (saw_matrix_b_has_negatives && saw_matrix_b_no_negatives) ? 100.0 : (saw_matrix_b_has_negatives || saw_matrix_b_no_negatives) ? 50.0 : 0.0);
        $display("    Is constant:   %.2f%% covered", 
                (saw_matrix_b_constant && saw_matrix_b_not_constant) ? 100.0 : (saw_matrix_b_constant || saw_matrix_b_not_constant) ? 50.0 : 0.0);
        
        // Matrix patterns
        $display("\n  Matrix Patterns:");
        $display("    Are identity:  %.2f%% covered", 
                (saw_matrices_are_identity && saw_matrices_not_identity) ? 100.0 : (saw_matrices_are_identity || saw_matrices_not_identity) ? 50.0 : 0.0);
        $display("    Have diagonal: %.2f%% covered", 
                (saw_matrices_have_diagonal && saw_matrices_no_diagonal) ? 100.0 : (saw_matrices_have_diagonal || saw_matrices_no_diagonal) ? 50.0 : 0.0);
        
        // Result characteristics
        $display("\n  Result Characteristics:");
        $display("    Has zeros:      %.2f%% covered", 
                (saw_result_has_zeros && saw_result_no_zeros) ? 100.0 : (saw_result_has_zeros || saw_result_no_zeros) ? 50.0 : 0.0);
        
        $display("    Has positives:  %.2f%% covered", 
                (saw_result_has_positives && saw_result_no_positives) ? 100.0 : (saw_result_has_positives || saw_result_no_positives) ? 50.0 : 0.0);
        $display("    Has negatives:  %.2f%% covered", 
                (saw_result_has_negatives && saw_result_no_negatives) ? 100.0 : (saw_result_has_negatives || saw_result_no_negatives) ? 50.0 : 0.0);
        $display("    Has large vals: %.2f%% covered", 
                (saw_result_has_large_values && saw_result_no_large_values) ? 100.0 : (saw_result_has_large_values || saw_result_no_large_values) ? 50.0 : 0.0);
        $display("    Has small vals: %.2f%% covered", 
                (saw_result_has_small_values && saw_result_no_small_values) ? 100.0 : (saw_result_has_small_values || saw_result_no_small_values) ? 50.0 : 0.0);
        $display("    Is diagonal:    %.2f%% covered", 
                (saw_result_is_diagonal && saw_result_not_diagonal) ? 100.0 : (saw_result_is_diagonal || saw_result_not_diagonal) ? 50.0 : 0.0);
        $display("    Is identity:    %.2f%% covered", 
                (saw_result_is_identity && saw_result_not_identity) ? 100.0 : (saw_result_is_identity || saw_result_not_identity) ? 50.0 : 0.0);
        
        // Calculate and display overall coverage
        $display("\n  Overall coverage percentage: %.2f%%", (
            ((saw_matrix_a_has_zeros && saw_matrix_a_no_zeros) ? 100.0 : (saw_matrix_a_has_zeros || saw_matrix_a_no_zeros) ? 50.0 : 0.0) +
            ((saw_matrix_a_has_positives && saw_matrix_a_no_positives) ? 100.0 : (saw_matrix_a_has_positives || saw_matrix_a_no_positives) ? 50.0 : 0.0) +
            ((saw_matrix_a_has_negatives && saw_matrix_a_no_negatives) ? 100.0 : (saw_matrix_a_has_negatives || saw_matrix_a_no_negatives) ? 50.0 : 0.0) +
            ((saw_matrix_a_constant && saw_matrix_a_not_constant) ? 100.0 : (saw_matrix_a_constant || saw_matrix_a_not_constant) ? 50.0 : 0.0) +
            ((saw_matrix_b_has_zeros && saw_matrix_b_no_zeros) ? 100.0 : (saw_matrix_b_has_zeros || saw_matrix_b_no_zeros) ? 50.0 : 0.0) +
            ((saw_matrix_b_has_positives && saw_matrix_b_no_positives) ? 100.0 : (saw_matrix_b_has_positives || saw_matrix_b_no_positives) ? 50.0 : 0.0) +
            ((saw_matrix_b_has_negatives && saw_matrix_b_no_negatives) ? 100.0 : (saw_matrix_b_has_negatives || saw_matrix_b_no_negatives) ? 50.0 : 0.0) +
            ((saw_matrix_b_constant && saw_matrix_b_not_constant) ? 100.0 : (saw_matrix_b_constant || saw_matrix_b_not_constant) ? 50.0 : 0.0) +
            ((saw_matrices_are_identity && saw_matrices_not_identity) ? 100.0 : (saw_matrices_are_identity || saw_matrices_not_identity) ? 50.0 : 0.0) +
            ((saw_matrices_have_diagonal && saw_matrices_no_diagonal) ? 100.0 : (saw_matrices_have_diagonal || saw_matrices_no_diagonal) ? 50.0 : 0.0) +
            ((saw_result_has_zeros && saw_result_no_zeros) ? 100.0 : (saw_result_has_zeros || saw_result_no_zeros) ? 50.0 : 0.0) +
            ((saw_result_has_positives && saw_result_no_positives) ? 100.0 : (saw_result_has_positives || saw_result_no_positives) ? 50.0 : 0.0) +
            ((saw_result_has_negatives && saw_result_no_negatives) ? 100.0 : (saw_result_has_negatives || saw_result_no_negatives) ? 50.0 : 0.0) +
            ((saw_result_has_large_values && saw_result_no_large_values) ? 100.0 : (saw_result_has_large_values || saw_result_no_large_values) ? 50.0 : 0.0) +
            ((saw_result_has_small_values && saw_result_no_small_values) ? 100.0 : (saw_result_has_small_values || saw_result_no_small_values) ? 50.0 : 0.0) +
            ((saw_result_is_diagonal && saw_result_not_diagonal) ? 100.0 : (saw_result_is_diagonal || saw_result_not_diagonal) ? 50.0 : 0.0) +
            ((saw_result_is_identity && saw_result_not_identity) ? 100.0 : (saw_result_is_identity || saw_result_not_identity) ? 50.0 : 0.0)
        ) / 17.0);
    endfunction

    //===================================================================
    // DUT Instantiation
    //===================================================================
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

    //===================================================================
    // Clock Generation
    //===================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //===================================================================
    // Coverage Instances
    //===================================================================
    MatrixElementGenerator gen_a = new();
    MatrixElementGenerator gen_b = new();
    MatrixCoverageCollector matrix_coverage_collector = new(matrix_A, matrix_B, expected_C);

    //===================================================================
    // Utility Tasks
    //===================================================================
    
    // Initialize all inputs to zeros
    task automatic initialize_zeros;
        for (i = 0; i < N*B*2; i = i + 1) begin
            data_i[i] = 0;
        end
        
        for (i = 0; i < M*B*2; i = i + 1) begin
            weights_i[i] = 0;
        end
    endtask

    // Map reference matrices to STA inputs
    task automatic map_matrices_to_inputs;
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
    task automatic calculate_expected_result;
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

    // Display results from PE grid
    task automatic display_results;
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
    task automatic verify_results;
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

    //===================================================================
    // Test Execution Tasks
    //===================================================================
    
    // Run a test cycle with the current matrix values
    task automatic run_test_cycle;
        // Reset everything
        reset = 1;
        clear_acc = 1;
        initialize_zeros();
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        clear_acc = 0;
        cycle = 0;
        
        // Update global coverage flags based on current test matrices
        saw_matrix_a_has_zeros |= matrix_coverage_collector.has_zero_values(matrix_A);
        saw_matrix_a_no_zeros |= !matrix_coverage_collector.has_zero_values(matrix_A);
        saw_matrix_a_has_positives |= matrix_coverage_collector.has_positive_values(matrix_A);
        saw_matrix_a_no_positives |= !matrix_coverage_collector.has_positive_values(matrix_A);
        saw_matrix_a_has_negatives |= matrix_coverage_collector.has_negative_values(matrix_A);
        saw_matrix_a_no_negatives |= !matrix_coverage_collector.has_negative_values(matrix_A);
        saw_matrix_a_constant |= matrix_coverage_collector.has_constant_values(matrix_A);
        saw_matrix_a_not_constant |= !matrix_coverage_collector.has_constant_values(matrix_A);
        
        saw_matrix_b_has_zeros |= matrix_coverage_collector.has_zero_values(matrix_B);
        saw_matrix_b_no_zeros |= !matrix_coverage_collector.has_zero_values(matrix_B);
        saw_matrix_b_has_positives |= matrix_coverage_collector.has_positive_values(matrix_B);
        saw_matrix_b_no_positives |= !matrix_coverage_collector.has_positive_values(matrix_B);
        saw_matrix_b_has_negatives |= matrix_coverage_collector.has_negative_values(matrix_B);
        saw_matrix_b_no_negatives |= !matrix_coverage_collector.has_negative_values(matrix_B);
        saw_matrix_b_constant |= matrix_coverage_collector.has_constant_values(matrix_B);
        saw_matrix_b_not_constant |= !matrix_coverage_collector.has_constant_values(matrix_B);
        
        saw_matrices_are_identity |= (matrix_coverage_collector.is_identity_matrix(matrix_A) && matrix_coverage_collector.is_identity_matrix(matrix_B));
        saw_matrices_not_identity |= !(matrix_coverage_collector.is_identity_matrix(matrix_A) && matrix_coverage_collector.is_identity_matrix(matrix_B));
        saw_matrices_have_diagonal |= (matrix_coverage_collector.has_diagonal_pattern(matrix_A) || matrix_coverage_collector.has_diagonal_pattern(matrix_B));
        saw_matrices_no_diagonal |= !(matrix_coverage_collector.has_diagonal_pattern(matrix_A) || matrix_coverage_collector.has_diagonal_pattern(matrix_B));
        
        calculate_expected_result();
        
        // Check result characteristics
        saw_result_has_zeros |= matrix_coverage_collector.has_zero_values_result(expected_C);
        saw_result_no_zeros |= !matrix_coverage_collector.has_zero_values_result(expected_C);
        saw_result_has_positives |= matrix_coverage_collector.has_positive_values_result(expected_C);
        saw_result_no_positives |= !matrix_coverage_collector.has_positive_values_result(expected_C);
        saw_result_has_negatives |= matrix_coverage_collector.has_negative_values_result(expected_C);
        saw_result_no_negatives |= !matrix_coverage_collector.has_negative_values_result(expected_C);
        saw_result_has_large_values |= matrix_coverage_collector.has_large_values(expected_C);
        saw_result_no_large_values |= !matrix_coverage_collector.has_large_values(expected_C);
        saw_result_has_small_values |= matrix_coverage_collector.has_small_values(expected_C);
        saw_result_no_small_values |= !matrix_coverage_collector.has_small_values(expected_C);
        saw_result_is_diagonal |= matrix_coverage_collector.is_result_diagonal(expected_C);
        saw_result_not_diagonal |= !matrix_coverage_collector.is_result_diagonal(expected_C);
        saw_result_is_identity |= matrix_coverage_collector.is_result_identity(expected_C);
        saw_result_not_identity |= !matrix_coverage_collector.is_result_identity(expected_C);
        
        // Feed data diagonally through the systolic array
        
        // Cycle 0: Feed diagonal 0 (just the top-left element)
        initialize_zeros();
        weights_i[0] = matrix_A[0][0];  // Top-left PE, data from A
        data_i[0] = matrix_B[0][0];     // Top-left PE, data from B
        @(posedge clk);
        cycle++;
        
        // Cycle 1: Feed diagonal 1
        initialize_zeros();
        weights_i[0] = matrix_A[0][1];  // A[0][1] to top-left PE
        weights_i[B] = matrix_A[1][0];  // A[1][0] to bottom-left PE
        data_i[0] = matrix_B[1][0];     // B[1][0] to top-left PE
        data_i[B] = matrix_B[0][1];     // B[0][1] to top-right PE
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
        @(posedge clk);
        cycle++;
        
        // Cycle 5: Feed diagonal 5
        initialize_zeros();
        weights_i[B*2] = matrix_A[2][3]; // A[2][3]
        weights_i[B*3] = matrix_A[3][2]; // A[3][2]
        data_i[B*2] = matrix_B[3][2];    // B[3][2]
        data_i[B*3] = matrix_B[2][3];    // B[2][3]
        @(posedge clk);
        cycle++;
        
        // Cycle 6: Feed diagonal 6
        initialize_zeros();
        weights_i[B*3] = matrix_A[3][3]; // A[3][3]
        data_i[B*3] = matrix_B[3][3];    // B[3][3]
        @(posedge clk);
        cycle++;
        
        // Feed zeros for propagation cycles
        initialize_zeros();
        
        // Need additional cycles for full propagation
        for (i = 0; i < 20; i++) begin
            @(posedge clk);
            cycle++;
        end
        
        // Display and verify results
        display_results();
        verify_results();
        
        @(posedge clk);
    endtask

    // Run a standard test case with specified preparation
    task automatic run_test_case(string test_name, string prep_task_name);
        $display("\n=== Test Case: %s ===", test_name);
        
        // Use a case statement to call the appropriate task
        case(prep_task_name)
            "identity":        prepare_identity_test();
            "constant":        prepare_constant_test();
            "sequential":      prepare_sequential_test();
            "boundary":        prepare_boundary_test();
            "sparse":          prepare_sparse_test();
            "random":          prepare_random_test();
            "zeros":           prepare_zeros_test();
            "negative":        prepare_negative_test();
            "mixed_signs":     prepare_mixed_signs_test();
            "diagonal_only":   prepare_diagonal_only_test();
            "large_values":    prepare_large_values_test();
            "alternating":     prepare_alternating_zeros_test();
            "no_negatives":    prepare_no_negatives_test();
            "no_diagonal":     prepare_no_diagonal_test();
            "large_result":    prepare_large_values_result_test();
            "small_result":    prepare_small_values_result_test();
            "a_no_zeros":      prepare_matrix_a_no_zeros_test();
            "b_no_negatives":  prepare_matrix_b_no_negatives_test();
            "has_diagonal":    prepare_has_diagonal_test();
            "result_no_zeros": prepare_result_no_zeros_test();
            default:           $display("Unknown test case: %s", prep_task_name);
        endcase
        
        run_test_cycle();
    endtask

    //===================================================================
    // Test Matrix Preparation Tasks
    //===================================================================
    
    // Identity Matrix test
    task automatic prepare_identity_test;
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = (i == j) ? 1 : 0;
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = (i == j) ? 1 : 0;
                gen_b.sample_coverage();
            end
        end

        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Constant Value test
    task automatic prepare_constant_test;
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = 2; // All 2's
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = 3; // All 3's
                gen_b.sample_coverage();
            end
        end

        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Sequential Value test
    task automatic prepare_sequential_test;
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = i*A_COLS + j + 1; // Sequential values
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = i*B_COLS + j + 1; // Sequential values
                gen_b.sample_coverage();
            end
        end

        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Boundary Value test
    task automatic prepare_boundary_test;
        logic signed [QUANTIZED_WIDTH-1:0] max_val = (1 << (QUANTIZED_WIDTH-1)) - 1;
        logic signed [QUANTIZED_WIDTH-1:0] min_val = -(1 << (QUANTIZED_WIDTH-1));
        
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = ((i+j) % 2 == 0) ? max_val : min_val;
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = ((i+j) % 2 == 0) ? 1 : -1;
                gen_b.sample_coverage();
            end
        end

        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Sparse Matrix test
    task automatic prepare_sparse_test;
        // Initialize all to zero
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = 0;
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = 0;
                gen_b.sample_coverage();
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
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Zero Matrix test
    task automatic prepare_zeros_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = 0;
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = 0;
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Negative Values test
    task automatic prepare_negative_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = -((i+j) % 10 + 1); // Different negative values
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = -((i*j) % 10 + 1); // Different negative values
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask
    // Mixed Signs test
    task automatic prepare_mixed_signs_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = ((i+j) % 2 == 0) ? (i+j+1) : -(i+j+1);
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = ((i+j) % 2 == 0) ? (i+j+1) : -(i+j+1);
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Diagonal-Only Matrix test
    task automatic prepare_diagonal_only_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = (i == j) ? (i+1) : 0; // Non-identity diagonal
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = (i == j) ? (i+2) : 0; // Different diagonal values
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Large Values test
    task automatic prepare_large_values_test;
        logic signed [QUANTIZED_WIDTH-1:0] max_val = (1 << (QUANTIZED_WIDTH-1)) - 1;
        
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = max_val - (i*j % 10); // Near max values
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = max_val - (i+j % 10); // Near max values
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Alternating Zeros test
    task automatic prepare_alternating_zeros_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = ((i+j) % 2 == 0) ? 5 : 0;
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = ((i+j) % 2 == 0) ? 0 : 5;
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Random Matrix test
    task automatic prepare_random_test;
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = $urandom_range(20) - 10; // Range: -10 to 10
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = $urandom_range(20) - 10; // Range: -10 to 10
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Non-Negative Matrix test
    task automatic prepare_no_negatives_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = $urandom_range(20); // Range: 0 to 20 (no negatives)
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = $urandom_range(20); // Range: 0 to 20 (no negatives)
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Non-Diagonal Matrix test
    task automatic prepare_no_diagonal_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                if (i == j) begin
                    matrix_A[i][j] = 0; // Zero on diagonal
                end else begin
                    matrix_A[i][j] = $urandom_range(20) - 10; // Random elsewhere
                end
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                if (i == j) begin
                    matrix_B[i][j] = 0; // Zero on diagonal
                end else begin
                    matrix_B[i][j] = $urandom_range(20) - 10; // Random elsewhere
                end
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Large Result Values test
    task automatic prepare_large_values_result_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = 100 + i + j; // Large positive values
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = 100 + i + j; // Large positive values
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Small Result Values test
    task automatic prepare_small_values_result_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                // Create opposing values that nearly cancel each other out
                if ((i+j) % 2 == 0) begin
                    matrix_A[i][j] = 1;
                end else begin
                    matrix_A[i][j] = -1;
                end
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                // Small values
                matrix_B[i][j] = (i+j) % 3;
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Matrix A with No Zeros test
    task automatic prepare_matrix_a_no_zeros_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = i+j+1; // Guaranteed non-zero positive
                gen_a.sample_coverage();
            end
        end
        
        // Random values for matrix B
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = $urandom_range(20) - 10;
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Matrix B with No Negatives test
    task automatic prepare_matrix_b_no_negatives_test;
        // Random values for matrix A
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = $urandom_range(20) - 10;
                gen_a.sample_coverage();
            end
        end
        
        // Create matrix B with NO negative values
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = $urandom_range(20); // Range: 0 to 20 (no negatives)
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Strong Diagonal Pattern test
    task automatic prepare_has_diagonal_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                if (i == j) begin
                    matrix_A[i][j] = 10; // Large value on diagonal
                end else begin
                    matrix_A[i][j] = 1; // Small values elsewhere
                end
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                if (i == j) begin
                    matrix_B[i][j] = 10; // Large value on diagonal
                end else begin
                    matrix_B[i][j] = 1; // Small values elsewhere
                end
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    // Result with No Zeros test
    task automatic prepare_result_no_zeros_test;
        for (i = 0; i < A_ROWS; i++) begin
            for (j = 0; j < A_COLS; j++) begin
                matrix_A[i][j] = 1; // All ones
                gen_a.sample_coverage();
            end
        end
        
        for (i = 0; i < B_ROWS; i++) begin
            for (j = 0; j < B_COLS; j++) begin
                matrix_B[i][j] = 1; // All ones
                gen_b.sample_coverage();
            end
        end
        
        matrix_coverage_collector.sample_coverage();
        map_matrices_to_inputs();
    endtask

    //===================================================================
    // Randomized Testing
    //===================================================================
    
    // Run multiple randomized tests with randc values
    task automatic prepare_randc_tests(int num_tests);
        $display("\n=== Running %0d Randomized Tests with Comprehensive Coverage ===", num_tests);
        
        // Create a new coverage collector for each new test
        matrix_coverage_collector = new(matrix_A, matrix_B, expected_C);
        
        for (int test_idx = 0; test_idx < num_tests; test_idx++) begin
            $display("\n--- Randc Test Iteration %0d of %0d ---", test_idx+1, num_tests);
            
            // Reset the DUT for each test
            reset = 1;
            clear_acc = 1;
            initialize_zeros();
            @(posedge clk);
            @(posedge clk);
            reset = 0;
            clear_acc = 0;
            
            // Generate matrix A with randc values
            for (i = 0; i < A_ROWS; i++) begin
                for (j = 0; j < A_COLS; j++) begin
                    void'(gen_a.randomize());
                    matrix_A[i][j] = gen_a.value;
                    gen_a.sample_coverage();
                end
            end
            
            // Generate matrix B with randc values
            for (i = 0; i < B_ROWS; i++) begin
                for (j = 0; j < B_COLS; j++) begin
                    void'(gen_b.randomize());
                    matrix_B[i][j] = gen_b.value;
                    gen_b.sample_coverage();
                end
            end

            // Sample coverage
            matrix_coverage_collector.sample_coverage();
            
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

            // Run the test
            calculate_expected_result();
            run_test_cycle();
        end
        
        // Final summary
        $display("\n=== Completed %0d Randomized Tests ===", num_tests);
    endtask

    //===================================================================
    // Main Test Sequence
    //===================================================================
    initial begin
        // Setup and reset
        reset = 1;
        clear_acc = 0;
        initialize_zeros();
        cycle = 0;
        
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        
        $display("\n====================================================");
        $display("=== Starting STA Test with Comprehensive Coverage ===");
        $display("====================================================");
        $display("Configuration: %0d x %0d PE grid, each PE contains 2x2 DPs, B=%0d", M, N, B);
       
        //------------------------------------------------------------------
        // Standard Test Suite
        //------------------------------------------------------------------
        run_test_case("Identity Matrix", "identity");
        run_test_case("Constant Matrix", "constant");
        run_test_case("Sequential Values", "sequential");
        run_test_case("Boundary Testing", "boundary");
        run_test_case("Sparse Matrix", "sparse");
        run_test_case("Random Matrix", "random");
        
        //------------------------------------------------------------------
        // Coverage-focused Test Suite
        //------------------------------------------------------------------
        run_test_case("All Zeros Matrix", "zeros");
        run_test_case("All Negative Values", "negative");
        run_test_case("Mixed Signs (No Zeros)", "mixed_signs");
        run_test_case("Diagonal-Only Matrix", "diagonal_only");
        run_test_case("Large Values", "large_values");
        run_test_case("Alternating Zeros", "alternating");

        $display("\n=== Adding directed tests for missing coverage bins ===");
        
        // Tests for specific matrix characteristics
        $display("\n--- Directed Test: No Negative Values ---");
        prepare_no_negatives_test();
        run_test_cycle();
        
        $display("\n--- Directed Test: No Diagonal Pattern ---");
        prepare_no_diagonal_test();
        run_test_cycle();
        
        $display("\n--- Directed Test: Matrix A No Zeros ---");
        prepare_matrix_a_no_zeros_test();
        run_test_cycle();
        
        $display("\n--- Directed Test: Matrix B No Negatives ---");
        prepare_matrix_b_no_negatives_test();
        run_test_cycle();
        
        $display("\n--- Directed Test: Strong Diagonal Pattern ---");
        prepare_has_diagonal_test();
        run_test_cycle();
        
        // Tests for specific result characteristics
        $display("\n--- Directed Test: Large Result Values ---");
        prepare_large_values_result_test();
        run_test_cycle();
        
        $display("\n--- Directed Test: Small Result Values ---");
        prepare_small_values_result_test();
        run_test_cycle();
        
        $display("\n--- Directed Test: Result With No Zeros ---");
        prepare_result_no_zeros_test();
        run_test_cycle();
            
        //------------------------------------------------------------------
        // Randomized testing with coverage analysis
        //------------------------------------------------------------------
        prepare_randc_tests(20); // Multiple random tests
        
        //------------------------------------------------------------------
        // Display final global coverage report
        //------------------------------------------------------------------
        report_global_coverage();
               
        // End simulation
        @(posedge clk);
        @(posedge clk);
        $display("\n=== STA Test Complete ===");
        $finish();
    end
endmodule

/*
// STA 8x8 Matrix Multiplication Test
// Abhishek Kumar, Keith Phou
module STA_tb;

    // ----- SIMULATION SETUP -----
    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars();
    end

    // ----- PARAMETERS -----
    localparam N = 4;                  // Number of PE columns (changed from 2 to 4)
    localparam M = 4;                  // Number of PE rows (changed from 2 to 4)
    localparam B = 8;                  // Multipliers per DP (changed from 4 to 8)
    localparam QUANTIZED_WIDTH = 8;    // Bit-width of inputs
    
    // Test matrix dimensions
    localparam A_ROWS = M * 2;         // Input A matrix rows (8)
    localparam A_COLS = B;             // Input A matrix columns (8)
    localparam B_ROWS = B;             // Input B matrix rows (8) 
    localparam B_COLS = N * 2;         // Input B matrix columns (8)
    localparam CLK_PERIOD = 100;       // Clock period in ns (100MHz)

    // ----- SIGNALS -----
    // Clock and control
    logic clk;
    logic reset;
    logic clear_acc;

    // Input/output signals
    logic signed [QUANTIZED_WIDTH-1:0] data_i[N*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_i[M*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] data_o[N*B*2-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] weights_o[M*B*2-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] result_o[M-1:0][N-1:0][2-1:0][2-1:0];

    // Test matrices
    logic signed [QUANTIZED_WIDTH-1:0] matrix_A[A_ROWS-1:0][A_COLS-1:0];
    logic signed [QUANTIZED_WIDTH-1:0] matrix_B[B_ROWS-1:0][B_COLS-1:0];
    logic signed [4*QUANTIZED_WIDTH-1:0] expected_C[A_ROWS-1:0][B_COLS-1:0];

    // Task variables
    integer i, j, k;
    integer pe_row, pe_col, dp_row, dp_col, row_idx, col_idx;
    integer error_count, cycle, test_num;
    integer diag, row_a, col_a, row_b, col_b;
    integer pe_row_a, dp_row_a, weight_idx;
    integer pe_col_b, dp_col_b, data_idx;
    logic signed [4*QUANTIZED_WIDTH-1:0] actual, expected;

    // ----- DUT INSTANTIATION -----
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

    // ----- CLOCK GENERATION -----
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ----- HELPER TASKS -----
    // Initialize all inputs to zeros
    task automatic initialize_zeros;
        for (i = 0; i < N*B*2; i = i + 1) begin
            data_i[i] = 0;
        end
        
        for (i = 0; i < M*B*2; i = i + 1) begin
            weights_i[i] = 0;
        end
    endtask

    // Map reference matrices to STA inputs
    task automatic map_matrices_to_inputs;
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
    task automatic calculate_expected_result;
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

    // Display results from PE grid
    task automatic display_results;
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
    task automatic verify_results;
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

    // Generate random matrices for testing
    task automatic generate_random_matrices;
        // Create matrices with random values in a constrained range (-20 to 20)
        for (i = 0; i < A_ROWS; i = i + 1) begin
            for (j = 0; j < A_COLS; j = j + 1) begin
                matrix_A[i][j] = $urandom_range(41) - 20; // Range: -20 to 20
            end
        end
        
        for (i = 0; i < B_ROWS; i = i + 1) begin
            for (j = 0; j < B_COLS; j = j + 1) begin
                matrix_B[i][j] = $urandom_range(41) - 20; // Range: -20 to 20
            end
        end
        
        map_matrices_to_inputs();
        calculate_expected_result();
    endtask

    // Run a test cycle with the current matrix values
    task automatic run_test_cycle;
        // Reset everything
        reset = 1;
        clear_acc = 1;
        initialize_zeros();
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        clear_acc = 0;
        cycle = 0;
        
        // 8x8 matrix multiplication requires feeding through more diagonals
        // We need to feed a total of A_ROWS + B_COLS - 1 = 15 diagonals
        
        for (diag = 0; diag < A_ROWS + B_COLS - 1; diag = diag + 1) begin
            initialize_zeros();
            
            // For each diagonal, determine which elements to feed
            for (i = 0; i <= diag; i = i + 1) begin
                row_a = i;
                col_a = diag - i;
                
                // Only process if the indices are within matrix bounds
                if (row_a < A_ROWS && col_a < A_COLS && row_a >= 0 && col_a >= 0) begin
                    // Calculate the corresponding PE and DP indices
                    pe_row_a = row_a / 2;
                    dp_row_a = row_a % 2;
                    weight_idx = pe_row_a * (2*B) + dp_row_a * B + col_a;
                    
                    // Only set if within bounds
                    if (weight_idx < M*B*2) begin
                        weights_i[weight_idx] = matrix_A[row_a][col_a];
                    end
                    
                    // Calculate corresponding B matrix element
                    row_b = col_a;
                    col_b = row_a;
                    
                    // Only process if the indices are within matrix B bounds
                    if (row_b < B_ROWS && col_b < B_COLS && row_b >= 0 && col_b >= 0) begin
                        pe_col_b = col_b / 2;
                        dp_col_b = col_b % 2;
                        data_idx = pe_col_b * (2*B) + dp_col_b * B + row_b;
                        
                        // Only set if within bounds
                        if (data_idx < N*B*2) begin
                            data_i[data_idx] = matrix_B[row_b][col_b];
                        end
                    end
                end
            end
            
            @(posedge clk);
            cycle = cycle + 1;
        end
        
        // Feed zeros for propagation cycles
        initialize_zeros();
        
        // Need additional cycles for full propagation through the array
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            cycle = cycle + 1;
        end
        
        // Display and verify results
        display_results();
        verify_results();
        
        @(posedge clk);
    endtask

    // ----- TEST EXECUTION -----
    initial begin
        // Setup and reset
        reset = 1;
        clear_acc = 0;
        initialize_zeros();
        cycle = 0;
        test_num = 0;
        
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        
        $display("\n=================================================");
        $display("=== Starting STA Test for 8x8 Matrix Multiply ===");
        $display("=================================================");
        $display("Configuration: %0d x %0d PE grid, each PE contains 2x2 DPs, B=%0d", M, N, B);
        $display("Matrix dimensions: A(%0d x %0d) * B(%0d x %0d) = C(%0d x %0d)",
                 A_ROWS, A_COLS, B_ROWS, B_COLS, A_ROWS, B_COLS);
        
        // Run 5 random matrix multiplication tests
        for (test_num = 1; test_num <= 5; test_num = test_num + 1) begin
            $display("\n\n=== Test %0d of 5: Random 8x8 Matrix Multiplication ===", test_num);
            generate_random_matrices();
            run_test_cycle();
        end
               
        // End simulation
        @(posedge clk);
        @(posedge clk);
        $display("\n=== STA 8x8 Matrix Multiplication Test Complete ===");
        $finish();
    end
        
endmodule
*/