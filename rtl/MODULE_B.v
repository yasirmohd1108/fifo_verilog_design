`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mohammad Yasir
// Module Name: MODULE_B
// Project Name: FIFO
// Target Devices: FPGA
// Description: Consumer module updated to interface directly with FWFT FIFO
//////////////////////////////////////////////////////////////////////////////////

module MODULE_B #(
    parameter DATA_WIDTH = 8
)(
    input clk, reset,
    input empty,                          // Handshaking flag from FIFO
    input out_ready,                      // Ready from next stage

    input  [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out, // Sequential output (holds value)
    output rd_en
);

    // In FWFT FIFO, valid data is combinationally ready on data_in whenever empty is low.
    // Assert rd_en to pop the FIFO in the same cycle downstream accepts data.
    assign rd_en = !empty && out_ready;

    // Capture output data on clock edge whenever read operation is active
    always @(posedge clk) begin
        if (reset) begin
            data_out <= {DATA_WIDTH{1'b0}};
        end else if (rd_en) begin
            data_out <= data_in;
        end
    end

endmodule