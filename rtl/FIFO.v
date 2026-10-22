`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mohammad Yasir
// Module Name: FIFO
// Project Name: FIFO
// Target Devices: FPGA
// Description: Parameterized FWFT FIFO with clean output and initialized memory
//////////////////////////////////////////////////////////////////////////////////

module FIFO #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                  clk,
    input  wire                  rst,      // Active high synchronous reset
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire                  empty,
    output wire                  full
);

    // Calculate pointer width dynamically using $clog2
    localparam PTR_WIDTH   = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam COUNT_WIDTH = PTR_WIDTH + 1;

    // Memory array
    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    // Read/write pointers and word count with initial values
    reg [PTR_WIDTH-1:0]   wr_ptr = 0;
    reg [PTR_WIDTH-1:0]   rd_ptr = 0;
    reg [COUNT_WIDTH-1:0] count  = 0;

    integer k;

    // Initialize memory array to 0 at startup to prevent 'X' in waveform
    initial begin
        wr_ptr = 0;
        rd_ptr = 0;
        count  = 0;
        for (k = 0; k < DEPTH; k = k + 1) begin
            memory[k] = {DATA_WIDTH{1'b0}};
        end
    end

    // Status flags
    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    // Valid operation conditions
    wire do_write = wr_en && !full;
    wire do_read  = rd_en && !empty;

    // Write Logic
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (do_write) begin
            memory[wr_ptr] <= din;
            if (wr_ptr == DEPTH - 1)
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read Logic
    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
        end else if (do_read) begin
            if (rd_ptr == DEPTH - 1)
                rd_ptr <= 0;
            else
                rd_ptr <= rd_ptr + 1'b1;
        end 
    end

    // Combinational output for FWFT FIFO
    always @(*) begin
        if (rst || empty) begin
            dout = {DATA_WIDTH{1'b0}};
        end else begin
            dout = memory[rd_ptr];
        end
    end

    // Count Logic
    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else begin
            case ({do_write, do_read})
                2'b10: count <= count + 1'b1; // Write only
                2'b01: count <= count - 1'b1; // Read only
                default: count <= count;       // Simultaneous R/W or Idle
            endcase
        end
    end

endmodule