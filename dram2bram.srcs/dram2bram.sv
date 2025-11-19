// DRAM to BRAM packer.

`timescale 1ns/1ps
module dram2bram #(
  parameter int NUM_BYTES = 64
) (
    output reg [NUM_BYTES*8-1:0] bram_wrdata_o,  // if only one byte then it's in bits 7:0
    output reg bram_wr_o, // write strobe for BRAM
    output reg bram_incr_addr_after_wr_o, // 1 = incr bram addr AFTER this write

    input reg [NUM_BYTES*8-1:0] dram_data_i,  // if only one byte then it's in bits 7:0
    input reg [NUM_BYTES-1:0] tkeep_i,     // valid vector - bit per byte. 1=valid 0=unused
    input reg dram_data_vld_i, // 1 = incoming data is valid
    input reg rst,
    input reg clk
);

    localparam C_WIDTH = $clog2(NUM_BYTES);
    localparam NUM8BITS = NUM_BYTES >> 3;

    //-------------------------------------------------
    // Merge two byte sequences based on mask.
    function [NUM_BYTES*8-1:0] mask_merge;
        input [NUM_BYTES*8-1:0] i0;
        input [NUM_BYTES*8-1:0] i1;
        input [NUM_BYTES-1:0] mask;
        reg [NUM_BYTES*8-1:0] merged;
    begin
        for (integer i=0; i < NUM_BYTES; i++) 
            merged[i*8 +: 8] = mask[i] ? i1[i*8 +: 8] : i0[i*8 +: 8];
        return merged;
    end
    endfunction: mask_merge
    //-------------------------------------------------

    //-------------------------------------------------
    // This assumes the 1s are always packed starting from bit 0
    function [3:0] count_packed_ones_in_byte;
        input [7:0] vec;
        begin
            casex(vec)
            8'bxxxxxxx0 : return 4'd0;
            8'bxxxxxx01 : return 4'd1;
            8'bxxxxx01x : return 4'd2;
            8'bxxxx01xx : return 4'd3;
            8'bxxx01xxx : return 4'd4;
            8'bxx01xxxx : return 4'd5;
            8'bx01xxxxx : return 4'd6;
            8'b01xxxxxx : return 4'd7;
            8'b1xxxxxxx : return 4'd8;
            endcase
        end
    endfunction: count_packed_ones_in_byte
    //-------------------------------------------------

    //-------------------------------------------------
    // count number of packed (from bit 0) 1's in a vector (0-NUM_BYTES).
    // Vector must be multiple of 8 in size.
    function [C_WIDTH:0] count_packed_ones;
        input [NUM_BYTES-1:0] vec;
        reg [C_WIDTH:0] sum;
        begin
            sum = 0;
            for (integer i=0; i < NUM8BITS; i++) 
                sum += count_packed_ones_in_byte(vec[i*8 +: 8]);
            return sum;
        end 
    endfunction: count_packed_ones
    //-------------------------------------------------

    reg [NUM_BYTES*8-1:0] residue;   // keep residue to merge with new incoming data
    reg [C_WIDTH-1:0] num_residue_bytes; // number of valid bytes in residue (from previous data) 0 - NUM_BYTES-1
    reg new_residue_vld;  // 1 = The residue flops MUST be written this clock regardless of new input or not.

    wire [2*NUM_BYTES*8-1:0] dram_data_shl_dbl;  // twice the width.
    wire [NUM_BYTES*8-1:0] dram_data_merge; // dram data to be merged with current residue.
    wire [NUM_BYTES*8-1:0] dram_data_new_residue; // dram data that forms new residue.

    // Yes, the following is a bit shift that will only do byte shifts. 
    // Let's hope synthesis tool optimizes this otherwise might need to
    // manually code a barrel shifter.
    assign dram_data_shl_dbl     = {{NUM_BYTES*8{1'b0}}, dram_data_i} << {num_residue_bytes, 3'd0};
    assign dram_data_merge       = dram_data_shl_dbl[NUM_BYTES*8-1:0];
    assign dram_data_new_residue = dram_data_shl_dbl[2*NUM_BYTES*8-1:NUM_BYTES*8];

    // Compute same operations on tkeep so we know which bytes are valid.
    wire [NUM_BYTES:0] tkeep_shl_dbl;
    wire [NUM_BYTES-1:0] tkeep_merge;
    wire tkeep_new_residue;

    assign tkeep_shl_dbl     = {1'b0, tkeep_i} << num_residue_bytes;
    assign tkeep_merge       = tkeep_shl_dbl[NUM_BYTES-1:0];
    assign tkeep_new_residue = tkeep_shl_dbl[NUM_BYTES];

    // Extract some helpful bits.
    wire incr_bram_addr; // 1 = the bram word is completely full so incr addr AFTER this write.
    assign incr_bram_addr = tkeep_merge[NUM_BYTES-1];
    wire have_new_residue;  // 1 = we will use up the old residue and we will have at least 1 byte new residue.
    assign have_new_residue = tkeep_new_residue;

    // compute the BRAM data - merge the current residue with as much new data as possible.
    wire [NUM_BYTES*8-1:0] merged_data;
    assign merged_data = mask_merge(.i0(residue), .i1(dram_data_merge), .mask(tkeep_merge));

    // compute residue for next clock cycle:
    // If new data does not fill the word then we use merged_data.
    // If new data does fill word then we use any new bytes that didnt fit (0 - NUM_BYTES-1).
    wire [NUM_BYTES*8-1:0] residue_nxt;   // new value for residue;
    assign residue_nxt = have_new_residue ? dram_data_new_residue : merged_data;

    wire [C_WIDTH:0] num_new_bytes;
    assign num_new_bytes = dram_data_vld_i ? count_packed_ones(tkeep_i) : '0;
    wire [C_WIDTH:0] num_new_plus_residue;
    assign num_new_plus_residue = num_new_bytes + {1'b0, num_residue_bytes};

    always @(posedge clk) begin
        bram_wrdata_o <= merged_data;
        bram_wr_o <= rst ? '0 : dram_data_vld_i | new_residue_vld;
        bram_incr_addr_after_wr_o <= rst ? 1'b0 : incr_bram_addr;
        residue <= residue_nxt;
        new_residue_vld <= rst ? '0 : have_new_residue & dram_data_vld_i;
        num_residue_bytes <= rst ? '0 : num_new_plus_residue[C_WIDTH-1:0]; 
    end

endmodule: dram2bram

