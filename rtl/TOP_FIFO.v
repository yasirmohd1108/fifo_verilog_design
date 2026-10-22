`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mohammad Yasir
// Module Name: TOP_FIFO
// Project Name: FIFO
// Target Devices: FPGA
// Description: Integrated top-level module combining MODULE_A, FIFO, and MODULE_B
//////////////////////////////////////////////////////////////////////////////////

module TOP_FIFO #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 8,
    parameter ADDR_WIDTH = 3
)(
    input clk,
    input reset,
    input in_valid,
    input out_ready,
    input  [DATA_WIDTH-1:0] data_in_top,

    output [DATA_WIDTH-1:0] data_out_top
);

    // Internal wires mapping MODULE_A -> FIFO
    wire [DATA_WIDTH-1:0] a_to_fifo_data;
    wire wr_en_wire;
    wire full_wire;
    
    // Internal wires mapping FIFO -> MODULE_B
    wire [DATA_WIDTH-1:0] fifo_to_b_data;
    wire rd_en_wire;
    wire empty_wire;

    // 1. Instantiate the Input Module (Producer)
    MODULE_A #(
        .DATA_WIDTH(DATA_WIDTH)
    ) producer (
        .clk(clk),
        .reset(reset),
        .full(full_wire),           
        .in_valid(in_valid),
        .data_in(data_in_top),      
        .data_out(a_to_fifo_data),  
        .wr_en(wr_en_wire)          
    );

    // 2. Instantiate the FIFO
    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) fifo (
        .clk(clk),
        .rst(reset),
        .wr_en(wr_en_wire),
        .rd_en(rd_en_wire),
        .din(a_to_fifo_data),
        .full(full_wire),
        .empty(empty_wire),
        .dout(fifo_to_b_data)
    );

    // 3. Instantiate the Output Module (Consumer)
    MODULE_B #(
        .DATA_WIDTH(DATA_WIDTH)
    ) consumer (
        .clk(clk),
        .reset(reset),
        .empty(empty_wire),         
        .out_ready(out_ready),
        .data_in(fifo_to_b_data),   
        .data_out(data_out_top),  
        .rd_en(rd_en_wire)          
    );

endmodule