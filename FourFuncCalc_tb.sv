`timescale 1ns/1ns

module tb_calc;

    parameter W = 11;

	reg         clk;
	reg         clr;	   // C button
	reg         eq;       // = button: displays result so far; does not repeat previous operation
	reg         add;      // + button
	reg         sub;      // - button
	reg         mult;     // x button (multiply)
	reg         div;      // / button (division quotient)
	reg  [W-1:0] num;      // Must be entered in sign-magnitude on SW[W-1:0]
	wire signed [W-1:0] res;      // Calculation result in two's complement
	wire        ovf;      // Indicates result can't be represented in W bits
    wire [4:0]  state;

    // Internal checking registers
    reg        [2*W:0] correct_res;
    reg signed [W-1:0] correct_twoc_res; 
    reg signed [W-1:0] prev_res;
    reg signed [W-1:0] prev_num;
    reg        [W-1:0] correct_ovf;
    reg        [4  :0] prev_op;
    
    // Encoding of previous op
    // This should get performed when eq is asserted
    localparam OP_NONE = 4'b0000;
    localparam OP_ADD  = 4'b0001;
    localparam OP_SUB  = 4'b0010;
    localparam OP_MUL  = 4'b0100;
    localparam OP_DIV  = 4'b1000;
    

    // Instantiate DUT
    // FourFuncCalc #(.W(W)) dut (clk, clr, eq, add, sub, mult, div, num, res, ovf);
    FourFuncCalc #(.W(W)) dut (
        .Clock(clk), 
        .Clear(clr), 
        .Equals(eq), 
        .Add(add), 
        .Subtract(sub), 
        .Multiply(mult),
        .Divide(div),
        .Number(num), 
        .Result(res), 
        .Overflow(ovf)
    );


    // -------------------- OPERATION CHECKERS -------------------- //
    // Track last entered operation to get result
    always @(posedge clk) begin
        prev_op <= clr ? OP_NONE :
                    add  ? OP_ADD :
                    sub  ? OP_SUB : 
                    mult ? OP_MUL : 
                    div  ? OP_DIV : prev_op;
    end

    // Get a printable string of what operation we used
    wire [3*8-1:0] op_str;
    assign op_str = prev_op == OP_NONE ? "LD " :
                    prev_op == OP_ADD  ? "ADD" :
                    prev_op == OP_SUB  ? "SUB" :
                    prev_op == OP_MUL  ? "MUL" :
                    prev_op == OP_DIV  ? "DIV" : "ERR";

    task check_operation();
    begin
        @(posedge clk);
        @(negedge clk);
        // Clear operation and save inputs
        add = 0;
        sub = 0;
        mult = 0;
        div = 0;
        eq = 1;
        prev_res = res;
        // Convert the input to 2's complement
        prev_num = num[W-1] ? {1'b1, ~num[W-2:0]}+1 : num;
        @(posedge clk);
        eq = 0;
        // Calculate correct result based on operation
        if (prev_op == OP_NONE) begin
            correct_res = prev_num;
                        // Wait for result 
            // @(posedge clk);
            // @(posedge clk);
            @(res or ovf);
        end else if (prev_op == OP_ADD) begin
            correct_res = prev_res + prev_num;
            // $display("res:%d", res);
            // $display("ovf:%d", ovf); 
            // @(posedge clk); 
            // @(posedge clk);
            // @(posedge clk); 
            @(res or ovf);
            // $display("pos res:%d", res);
            // $display("pos ovf:%d", ovf); 
        end else if (prev_op == OP_SUB) begin
            correct_res = prev_res - prev_num;
            // @(posedge clk); 
            // @(posedge clk);
            // @(posedge clk); 
            @(res or ovf);
        end else if (prev_op == OP_MUL) begin
            correct_res = prev_res * prev_num;
            // Wait for result 
            // $display("res:%d", res);
            // $display("ovf:%d", ovf);          
            @(res or ovf);
            // $display("h_res:%d", res);
            // $display("h_ovf:%d", ovf); 
        end else if (prev_op == OP_DIV) begin
            if (prev_num == 0) begin
                correct_res = prev_res;
            end else begin
                correct_res = prev_res / prev_num;
            end
            // Wait for result    
            // $display("res:%d", res);
            // $display("ovf:%d", ovf);         
            @(res or ovf);
            // $display("h_res:%d", res);
            // $display("h_ovf:%d", ovf); 
        end

        @(negedge clk);
        // $display("correct_res:%d", correct_res);
        // $display("res:%d", res);
        // $display("ovf:%d", ovf);
        
        // Check for correct overflow
        // No overflow if higher bits are all 0s or all 1s
        correct_twoc_res = correct_res[W-1:0];

        // check it should have overflow but program does not have overflow
        if (~(&correct_res[2*W:W-1] | &(~correct_res[2*W:W-1])) && ovf !== 1) begin
            $display("ERROR overflow:");
            $display("In %d %s %d", prev_res, op_str, prev_num);
            $display("Expected output: overflow %d, result %d", 1, correct_twoc_res);
            $display("Actual output: overflow %d, result %d", ovf, res);
            $finish;
        end 
        // should have overflow
        else if (prev_op == OP_DIV && prev_num==0 && ovf == 0) begin
            $display("ERROR overflow:");
            $display("In %d %s %d", prev_res, op_str, prev_num);
            $display("Expected output: overflow %d, result %d", 1'd1, correct_twoc_res);
            $display("Actual output: overflow %d, result %d", ovf, res);
            $finish;
        end
        // check it shouldn't have overflow but program does have overflow
        else if(prev_op != OP_DIV && ((&correct_res[2*W:W-1] | &(~correct_res[2*W:W-1]))) && ovf !== 0) begin
            $display("ERROR overflow:");
            $display("In %d %s %d", prev_res, op_str, prev_num);
            $display("Expected output: overflow %d, result %d", 1'd0, correct_twoc_res);
            $display("Actual output: overflow %d, result %d", ovf, res);
            $finish;
        end 
        // Check for correct result value
        else if (!(div==1 && ovf==1) && res !== correct_twoc_res) begin 
            $display("ERROR result:");
            $display("In %d %s %d", prev_res, op_str, prev_num);
            $display("Expected output: result %d", correct_twoc_res);
            $display("Actual output: result %d", res);
            $finish;
        end
    end
    endtask

    task clear();
    begin
        clr = 1;
        {eq, add, sub, mult, div, num} = 0;
        @(posedge clk);
        @(negedge clk);
        clr = 0;
    end
    endtask



    // -------------------- BEGIN TESTING -------------------- //
    initial begin
        clk  = 1'b0;
        clr  = 1'b0;
        eq   = 1'b0;
        add  = 1'b0;
        sub  = 1'b0;
        mult = 1'b0;
        div  = 1'b0;
        num  = 0;
        prev_op = OP_NONE;
        
        // ####### LOADING AND CLEARING ####### 
        `ifdef LD_POS
            // Test loading a value
            @(negedge clk);
            num = 3;
            check_operation();
        `endif
        `ifdef LD_NEG
            // Test loading a value
            @(negedge clk);
            num = {1'b1, 10'd4};
            check_operation();
        `endif
        `ifdef CLR
            // Test clearing (Done indirectly, check reloading number would result in new number) TODO: NONCOMPREHENSIVE
            @(negedge clk);
            num = {1'b1, 10'd4};
            check_operation();
            clear();
            num = 200;
            check_operation();
        `endif
        // ####### ADDING ####### 
        `ifdef ADD_BASIC
            // Base case 
            num = 2;
            add = 1;
            check_operation(); // 0 + 2 = 2
        `endif
        `ifdef ADD_INCREMENTAL
            // Base case 
            num = 2;
            add = 1;
            check_operation(); // 0 + 2 = 2
            // Incremental Addition
            num = 1;
            add = 1;
            check_operation();  // 2 + 1 = 3
        `endif            
        `ifdef ADD_NEG
            num = 3;
            check_operation();
            num = {1'b1, 10'd4};
            add = 1;
            check_operation();  // 3 + -4 = -1
        `endif
        `ifdef ADD_OVF
            num = {1'b1, 10'd1};   
            check_operation();         
            // Add negative number with overflow
            num = {1'b1, 10'd1023};
            add = 1;
            check_operation();  // -1 + -1023 = -1024 ovf            
            clear();

            num = {1'b1, 10'd1023}; 
            check_operation();
            num = 'b1;
            add = 1;
            check_operation();  // -1023 + 1 = -1022 
            clear();

            num = {1'b0, 10'd512}; 
            check_operation();
            num = {1'b0, 10'd512};  
            add = 1;
            check_operation();  // 512 + 512 = 1024 ovf
            clear();

            num = {1'b1, 10'd512}; 
            check_operation();
            num = {1'b1, 10'd512};
            add = 1;
            check_operation();  // -512 + -512 = -1024
        `endif
       
        // ####### SUBTRACTION ####### 
        `ifdef SUB_BASIC
            // base case
            num = 2000;
            check_operation();  // Load 2000  
            num = 1557;
            sub = 1;
            check_operation();  // 2000 - 1557 = 443
        `endif 
        `ifdef SUB_NEG
            num = 150;
            check_operation();
            num = 200;
            sub = 1;
            check_operation();  // 150 - 200 = -50
        `endif
        `ifdef SUB_INCREMENTAL
            // Subtract negative number
            num = 150;
            check_operation();
            num = 200;
            sub = 1;
            check_operation();  // 150 - 200 = -50
            num = {1'b1, 8'd50};
            sub = 1;
            check_operation();  // -50 - (-50) = 0

            num = {1'b0, 8'd69};
            sub = 1;
            check_operation();  // 0 - 69 = -69

            num = {1'b0, 10'd900};
            sub = 1;
            check_operation();  // -69 - 900 = - 969
            clear();
        `endif

        `ifdef SUB_OVF
            // Positive overflow
            num = {1'b0, 10'd1023};
            check_operation();  // Load 1023
            num = {1'b1, 10'd200};
            sub = 1;
            check_operation();  // 1023 - (-200) = 1223 ovf
            // Negative overflow
            clear();
            num = {1'b1, 10'd1023};
            check_operation(); // Load 1023
            num = {1'b0, 10'd200};
            sub = 1;
            check_operation();  // -1023 - (200) = -1223 ovf
        `endif

        // ####### MULTIPLICATION ####### 
        `ifdef MUL_BASIC
            // Base case
            num = 9;
            check_operation(); // Load 9;
            num = 10;
            mult = 1;
            check_operation(); // 9 * 10 = 90
        `endif
        `ifdef MUL_INCREMENTAL
            num = 9;
            check_operation(); // Load 9;
            num = 10;
            mult = 1;
            check_operation(); // 9 * 10 = 90
            num = 5;
            mult = 1;
            check_operation(); // 90 * 5 = 450
            
            num = {1'b0, 10'd2};
            mult = 1;
            check_operation();  // 450 * 2 = 900 ovf
        `endif
        `ifdef MUL_OVF
            num = {1'b0, 10'd144};
            check_operation();
            num = {1'b0, 10'd22};
            mult = 1;
            check_operation(); // 144 * 22 = 3168 ovf
            clear();

            // Overflow (multiple times around)
            num = {1'b0, 10'd597};
            check_operation();
            num = {1'b0, 10'd400};
            mult = 1;
            check_operation();  // 597 * 400 = 238800 ovf 
            clear();

            // More overflow
            num = {1'b0, 10'd256};
            check_operation();
            num = {1'b0, 10'd4};
            mult = 1;
            check_operation();  // 256 * 4 = 1024 ovf
            clear();

            // No Overflow
            num = {1'b1, 10'd256};
            check_operation();  // Load -256
            num = {1'b0, 10'd4};
            mult = 1;
            check_operation();  // -256 * 4 = -1024
            clear();
        `endif

        // ####### DIVISION ####### 
        `ifdef DIV_BASIC
            // Base case
            num = {1'b0, 10'd24};
            check_operation();
            num = {1'b0, 10'd4};
            div = 1;
            check_operation();  // 24/4 = 6
            clear();
        `endif
        `ifdef DIV_NONINT
            // Non integer result
            num = {1'b0, 10'd24};
            check_operation();
            num = {1'b0, 10'd5};
            div = 1;
            check_operation();  // 24/5
            clear();
        `endif
        `ifdef DIV_POSNEG
            num = {1'b0, 10'd24};
            check_operation();
            num = {1'b1, 10'd5};
            div = 1;
            check_operation(); // 24/-5
            clear();
        `endif

        `ifdef DIV_NEGNEG
            // Divide 2 negative numbers
            num = {1'b1, 10'd678};
            check_operation();
            num = {1'b1, 10'd5};
            div = 1;
            check_operation(); // -678/-5
            clear();
        `endif

        // ####### Multiple operation buttons presssed ####### 
        `ifdef MIXED
            num = {1'b0, 10'd24};
            check_operation();
            mult = 1;
            mult = 0;
            div = 1;
            div = 0;
            add = 1;
            add = 0;
            sub = 1;
            num = {1'b0, 10'd5};
            check_operation();
            clear();

            num = {1'b0, 10'd24};
            check_operation();
            add = 1;
            add = 0;
            sub = 1;
            sub = 0;
            mult = 1;
            num = {1'b0, 10'd5};
            check_operation();
            clear();

            num = {1'b0, 10'd24};
            check_operation();
            sub = 1;
            sub = 0;
            mult = 1;
            mult = 0;
            add = 1;
            num = {1'b0, 10'd5};
            check_operation();
            clear();

            num = {1'b0, 10'd24};
            check_operation();
            add = 1;
            add = 0;
            mult = 1;
            mult = 0;
            sub = 1;
            num = {1'b0, 10'd5};
            check_operation();
            clear();

        `endif

        //// PRIVATE TESTS ////

        // Test 1: 32 * 32 = 1024, C
    `ifdef P_TEST1
        num = {1'b0, 10'd32};
        check_operation();
        mult = 1;
        check_operation();
        clear();
    `endif

    `ifdef P_TEST2
        // Test 2: 32 * -32 = 1024, C
        num = {1'b0, 10'd32};
        check_operation();
        mult = 1;
        num = {1'b1, 10'd32};
        check_operation();
        clear();
    `endif

    `ifdef P_TEST3
        // Test 3: 32 * 31 = 992, C
        num = {1'b0, 10'd32};
        check_operation();
        mult = 1;
        num = {1'b0, 10'd31};
        check_operation();
        clear();
    `endif

    `ifdef P_TEST4
        // Test 4: 40 * 25 = 1000, C
        num = {1'b0, 10'd40};
        check_operation();
        mult = 1;
        num = {1'b0, 10'd25};
        check_operation();
        clear();
    `endif

    `ifdef P_TEST5
        // Test 5: 32 / 0 = ovf, C
        num = {1'b0, 10'd32};
        check_operation();
        div = 1;
        num = 0;
        check_operation();
        clear();
    `endif

    `ifdef P_TEST6
        // Test 6: 16 + 15 = 31, 31 - 7 = 24, 24 * 7 = 168, 168 / 9 = 18, 18 * 15 = 270, C
        num = {1'b0, 10'd16};
        check_operation();
        add = 1;
        num = {1'b0, 10'd15};
        check_operation();
        sub = 1;
        num = {1'b0, 10'd7};
        check_operation();
        mult = 1;
        num = {1'b0, 10'd7};
        check_operation();
        div = 1;
        num = {1'b0, 10'd9};
        check_operation();
        mult = 1;
        num = {1'b0, 10'd15};
        check_operation();
        clear();
    `endif

        $display("All Tests Passed :)");
        $finish;
    end

    always begin
        #5 clk = ~clk;
    end

endmodule
