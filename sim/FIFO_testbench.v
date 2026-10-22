`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Self-Checking Testbench for FIFO Design
// Tests all corner cases and data integrity
//////////////////////////////////////////////////////////////////////////////////

module FIFO_testbench #(
    parameter DATA_WIDTH = 8,      // Must match DUT
    parameter FIFO_DEPTH = 8,      // Must match DUT
    parameter ADDR_WIDTH = 3       // Must match DUT
)();

    //Testbench signals
    reg clk;
    reg reset;
    reg [DATA_WIDTH-1:0] data_in_top;
    wire [DATA_WIDTH-1:0] data_out_top;
    
    //Test variables
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer i, j;
    reg [DATA_WIDTH-1:0] test_data;
    reg [DATA_WIDTH-1:0] expected_data;
    
    // Handshaking signals
    reg in_valid;
    reg out_ready;
    
    //DUT Instantiation
    TOP_FIFO #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) DUT(
        .clk(clk),
        .reset(reset),
        .in_valid(in_valid),
        .out_ready(out_ready),
        .data_in_top(data_in_top),
        .data_out_top(data_out_top)
    );
    
    //Clock generation - 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // ================================================================
    // Basic Task: Apply reset
    // ================================================================
    task reset_dut();
        begin
            @(negedge clk);
            reset = 1;
            data_in_top = 0;
            in_valid = 0;
            out_ready = 0;
            repeat(3) @(negedge clk);
            reset = 0;
            @(negedge clk);
            $display("----> DUT Reset Complete");
        end
    endtask
    
    // ================================================================
    // Basic Task: Write one value into the FIFO
    // MODULE_A is now combinational, so write happens on the SAME 
    // posedge that sees in_valid=1.
    // ================================================================
    task write_one(input [DATA_WIDTH-1:0] data);
        begin
            @(negedge clk);      // Setup data before next posedge
            data_in_top = data;
            in_valid = 1;
            @(negedge clk);      // After posedge: FIFO has written the data
            in_valid = 0;
        end
    endtask
    
    // ================================================================
    // Basic Task: Read one value from the FIFO
    // MODULE_B needs: out_ready pulse -> rd_en (same cycle) -> 
    //   FIFO updates data_out (next cycle) -> MODULE_B captures (next cycle)
    // Total: 2 cycles after out_ready pulse for data to appear on data_out_top
    // ================================================================
    task read_one();
        begin
            @(negedge clk);      // Setup out_ready before next posedge
            out_ready = 1;
            @(negedge clk);      // After posedge: MODULE_B asserted rd_en, goes to WAIT_DATA
            out_ready = 0;
            @(negedge clk);      // After posedge: MODULE_B captured data (ps==WAIT_DATA)
            @(negedge clk);      // After posedge: data_out_top is now stable with captured value
        end
    endtask
    
    // ================================================================
    // Basic Task: Wait N cycles
    // ================================================================
    task wait_cycles(input integer cycles);
        begin
            repeat(cycles) @(posedge clk);
        end
    endtask
    
    // ================================================================
    // TEST 1: Check FIFO is empty after reset
    // ================================================================
    task check_empty_after_reset();
        begin
            test_count = test_count + 1;
            $display("\nTest %0d: Verify FIFO empty after reset", test_count);
            if (DUT.fifo.empty == 1'b1) begin
                $display("  PASS: FIFO is empty after reset");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: FIFO should be empty after reset");
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ================================================================
    // TEST 2: Fill FIFO with sequential data
    // With combinational MODULE_A, each write_one takes 1 effective cycle
    // ================================================================
    task fill_fifo_sequential(input [DATA_WIDTH-1:0] start_val);
        integer idx;
        begin
            $display("\n--- Filling FIFO with Sequential Data (0x%h to 0x%h) ---", 
                     start_val, start_val + FIFO_DEPTH - 1);
            for(idx = 0; idx < FIFO_DEPTH; idx = idx + 1) begin
                test_count = test_count + 1;
                test_data = start_val + idx;
                $display("Test %0d: Writing 0x%h to position %0d", test_count, test_data, idx);
                write_one(test_data);
                // After write_one returns, the FIFO has processed the write
                // Check that FIFO is not yet full (for all but last write)
                if (idx < FIFO_DEPTH - 1) begin
                    if (DUT.fifo.full == 1'b0) begin
                        $display("  PASS: FIFO not full after write %0d/%0d", idx+1, FIFO_DEPTH);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("  FAIL: FIFO should not be full yet (count=%0d)", DUT.fifo.wr_ptr - DUT.fifo.rd_ptr);
                        fail_count = fail_count + 1;
                    end
                end
            end
            wait_cycles(1); // Let last write settle
        end
    endtask
    
    // ================================================================
    // TEST 3: Verify full flag
    // ================================================================
    task check_full_flag();
        begin
            test_count = test_count + 1;
            $display("\nTest %0d: Verify FIFO full flag", test_count);
            if (DUT.fifo.full == 1'b1) begin
                $display("  PASS: FIFO full flag is asserted (wr_ptr=%h, rd_ptr=%h)", 
                         DUT.fifo.wr_ptr, DUT.fifo.rd_ptr);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: FIFO full flag should be asserted (wr_ptr=%h, rd_ptr=%h)", 
                         DUT.fifo.wr_ptr, DUT.fifo.rd_ptr);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ================================================================
    // TEST 4: Write while full (should be ignored)
    // ================================================================
    task write_while_full();
        begin
            test_count = test_count + 1;
            $display("\nTest %0d: Write while FIFO is FULL (should be ignored)", test_count);
            // Save current write pointer
            write_one({DATA_WIDTH{1'b1}});
            wait_cycles(1);
            // After writing 8 values starting from 0x10, wr_ptr wraps to 8 (4'b1000)
            // Lower bits should be 000 since FIFO is full (ptr wrapped once)
            if (DUT.fifo.wr_ptr[ADDR_WIDTH-1:0] == {ADDR_WIDTH{1'b0}}) begin
                $display("  PASS: Write ignored when FIFO full (wr_ptr unchanged)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Write pointer changed when FIFO full (wr_ptr=%h)", DUT.fifo.wr_ptr);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ================================================================
    // TEST 5: Read back all FIFO contents and verify data integrity
    // ================================================================
    task verify_fifo_contents();
        integer idx;
        begin
            $display("\n--- Verifying FIFO Contents via Sequential Reads ---");
            
            for(idx = 0; idx < FIFO_DEPTH; idx = idx + 1) begin
                test_count = test_count + 1;
                expected_data = 8'h10 + idx;
                
                // Perform one read
                read_one();
                
                $display("Test %0d: Expected 0x%h, Got 0x%h (empty=%b, rd_ptr=%h)", 
                         test_count, expected_data, data_out_top, 
                         DUT.fifo.empty, DUT.fifo.rd_ptr);
                
                if (data_out_top == expected_data) begin
                    $display("  PASS: Data match");
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: Data mismatch");
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask
    
    // ================================================================
    // TEST 6: Verify FIFO is empty after reading all data
    // ================================================================
    task empty_fifo_check();
        begin
            test_count = test_count + 1;
            $display("\nTest %0d: Verify FIFO empty after reading all data", test_count);
            wait_cycles(2);
            if (DUT.fifo.empty == 1'b1) begin
                $display("  PASS: FIFO is now empty");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: FIFO should be empty (wr_ptr=%h, rd_ptr=%h)", 
                         DUT.fifo.wr_ptr, DUT.fifo.rd_ptr);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ================================================================
    // TEST 7: Pointer wraparound test
    // ================================================================
    task wraparound_test();
        begin
            $display("\n--- Wraparound Test ---");
            
            // Fill with 0xAA pattern
            test_count = test_count + 1;
            $display("Test %0d: Fill FIFO with 0xAA pattern", test_count);
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                write_one(8'hAA);
            end
            wait_cycles(1);
            
            // Verify full
            test_count = test_count + 1;
            if (DUT.fifo.full == 1'b1) begin
                $display("Test %0d: FIFO full (wraparound test) - PASS", test_count);
                pass_count = pass_count + 1;
            end else begin
                $display("Test %0d: FIFO should be full - FAIL", test_count);
                fail_count = fail_count + 1;
            end
            
            // Read all back and verify 0xAA
            $display("  Reading back 0xAA pattern...");
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                test_count = test_count + 1;
                read_one();
                if (data_out_top == 8'hAA) begin
                    $display("Test %0d: Read 0x%h - PASS", test_count, data_out_top);
                    pass_count = pass_count + 1;
                end else begin
                    $display("Test %0d: Expected 0xAA, Got 0x%h - FAIL", test_count, data_out_top);
                    fail_count = fail_count + 1;
                end
            end
            
            // Verify empty
            test_count = test_count + 1;
            wait_cycles(1);
            if (DUT.fifo.empty == 1'b1) begin
                $display("Test %0d: FIFO empty after wraparound read - PASS", test_count);
                pass_count = pass_count + 1;
            end else begin
                $display("Test %0d: FIFO should be empty - FAIL", test_count);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ================================================================
    // TEST 8: Back-to-back write then read
    // ================================================================
    task back_to_back_write_read();
        begin
            $display("\n--- Back-to-Back Write/Read Test ---");
            
            // Write 4 values
            for(i = 0; i < 4; i = i + 1) begin
                test_count = test_count + 1;
                test_data = 8'h60 + i;
                $display("Test %0d: Write 0x%h", test_count, test_data);
                write_one(test_data);
            end
            wait_cycles(1);
            
            // Read them back and verify
            for(i = 0; i < 4; i = i + 1) begin
                test_count = test_count + 1;
                expected_data = 8'h60 + i;
                read_one();
                if (data_out_top == expected_data) begin
                    $display("Test %0d: Read 0x%h - PASS", test_count, data_out_top);
                    pass_count = pass_count + 1;
                end else begin
                    $display("Test %0d: Expected 0x%h, Got 0x%h - FAIL", 
                             test_count, expected_data, data_out_top);
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask
    
    // ================================================================
    // TEST 9: Verify pointer state
    // ================================================================
    task verify_pointers();
        begin
            test_count = test_count + 1;
            $display("\nTest %0d: Verify pointer state", test_count);
            $display("  Write Pointer: 0x%h", DUT.fifo.wr_ptr);
            $display("  Read Pointer: 0x%h", DUT.fifo.rd_ptr);
            $display("  Empty: %b, Full: %b", DUT.fifo.empty, DUT.fifo.full);
            if (DUT.fifo.empty == 1'b1) begin
                $display("  PASS: Pointers wrapped correctly");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Pointer state incorrect");
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ================================================================
    // Run All Tests
    // ================================================================
    task run_all_tests();
        begin
            $display("\n");
            $display("========================================================");
            $display("       FIFO DESIGN SELF-CHECKING TESTBENCH");
            $display("   DATA_WIDTH=%0d, FIFO_DEPTH=%0d, ADDR_WIDTH=%0d", DATA_WIDTH, FIFO_DEPTH, ADDR_WIDTH);
            $display("       Comprehensive Corner Case Testing");
            $display("========================================================");
            
            // Test 1: Reset
            reset_dut();
            check_empty_after_reset();
            
            // Test 2: Sequential Fill
            fill_fifo_sequential(8'h10);
            check_full_flag();
            
            // Test 3: Write while Full
            write_while_full();
            
            // Test 4: Read Sequence
            verify_fifo_contents();
            empty_fifo_check();
            
            // Test 5: Wraparound (fill + read with new data)
            wraparound_test();
            
            // Test 6: Back-to-Back write/read
            back_to_back_write_read();
            verify_pointers();
            
            // Final Summary
            print_summary();
            $stop;
        end
    endtask
    
    task print_summary();
        begin
            $display("\n");
            $display("========================================================");
            $display("                   TEST SUMMARY");
            $display("========================================================");
            $display(" Total Tests:  %0d", test_count);
            $display(" Passed:       %0d", pass_count);
            $display(" Failed:       %0d", fail_count);
            $display("========================================================");
            if (fail_count == 0) begin
                $display("          >>> ALL TESTS PASSED <<<");
            end else begin
                $display("          >>> SOME TESTS FAILED <<<");
            end
            $display("========================================================");
        end
    endtask
    
    //Main testbench execution
    initial begin
        run_all_tests();
    end

endmodule
