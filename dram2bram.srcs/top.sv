// DRAM to BRAM packer.

`timescale 1ns/1ps
module top #(
  parameter int NUM_BYTES = 32
) (
    output reg [NUM_BYTES*8-1:0] bram_wrdata_io,  // if only one byte then it's in bits 7:0
    output reg bram_wr_io, // write strobe for BRAM
    output reg bram_incr_addr_after_wr_io, // 1 = incr bram addr AFTER this write

    input reg [NUM_BYTES*8-1:0] dram_data_io,  // if only one byte then it's in bits 7:0
    input reg [NUM_BYTES-1:0] tkeep_io,     // valid vector - bit per byte. 1=valid 0=unused
    input reg dram_data_vld_io, // 1 = incoming data is valid
    input reg rst,
    input reg clk
);

    localparam FULL_NUM_BYTES=64;

    wire [FULL_NUM_BYTES*8-1:0] bram_wrdata_o;  // if only one byte then it's in bits 7:0
    wire bram_wr_o; // write strobe for BRAM
    wire bram_incr_addr_after_wr_o; // 1 = incr bram addr AFTER this write

    reg [FULL_NUM_BYTES*8-1:0] dram_data_i;  // if only one byte then it's in bits 7:0
    reg [FULL_NUM_BYTES-1:0] tkeep_i;     // valid vector - bit per byte. 1=valid 0=unused
    reg dram_data_vld_i; // 1 = incoming data is valid

always @(posedge clk) begin
    bram_wrdata_io <= bram_wrdata_o[255:0] | bram_wrdata_o[511:256];
    bram_wr_io <= bram_wr_o;
    bram_incr_addr_after_wr_io <= bram_incr_addr_after_wr_o;

    dram_data_i <= {dram_data_io, dram_data_io};   // meaningless - only for synthesis
    tkeep_i <= {tkeep_io, tkeep_io};  // meaningless - only for synthesis
    dram_data_vld_i <= dram_data_vld_io;

end


dram2bram #(.NUM_BYTES(FULL_NUM_BYTES)) dram2bram (
    .bram_wrdata_o (bram_wrdata_o),
    .bram_wr_o (bram_wr_o),
    .bram_incr_addr_after_wr_o(bram_incr_addr_after_wr_o),
    .dram_data_i(dram_data_i),
    .tkeep_i(tkeep_i),
    .dram_data_vld_i(dram_data_vld_i),
    .clk(clk),
    .rst(rst)
);

endmodule: top
