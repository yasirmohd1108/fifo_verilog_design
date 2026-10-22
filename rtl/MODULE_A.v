`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mohammad Yasir
// Module Name: MODULE_A
// Project Name: FIFO
// Target Devices: FPGA
// Description: Producer module - combinational passthrough with handshaking
//////////////////////////////////////////////////////////////////////////////////

module MODULE_A #(
    parameter DATA_WIDTH = 8
)(
    input clk, reset,                     // Kept for interface compatibility
    input full,                           // Handshaking flag from FIFO
    input in_valid,                       // Data valid from previous stage

    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    output wr_en
);

    // Combinational passthrough: data flows directly to FIFO when valid and not full
    assign data_out = data_in;
    assign wr_en    = in_valid & ~full;

endmodule