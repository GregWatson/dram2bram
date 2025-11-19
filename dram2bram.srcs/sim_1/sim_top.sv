// DRAM to BRAM packer.
// Top level sim
`timescale 1ns/1ps
module sim_top();

localparam FULL_NUM_BYTES = 64;

    wire [FULL_NUM_BYTES*8-1:0] bram_wrdata_o;  // if only one byte then it's in bits 7:0
    wire bram_wr_o; // write strobe for BRAM
    wire bram_incr_addr_after_wr_o; // 1 = incr bram addr AFTER this write

    reg [FULL_NUM_BYTES*8-1:0] dram_data_i;  // if only one byte then it's in bits 7:0
    reg [FULL_NUM_BYTES-1:0] tkeep_i;     // valid vector - bit per byte. 1=valid 0=unused
    reg dram_data_vld_i; // 1 = incoming data is valid

    reg clk;
    reg rst;

always #5 clk=~clk;
reg [7:0] cur_byte;

task set_input;
input [31:0] num_bytes;
begin
    for (integer i=0; i< num_bytes;i++) begin
        dram_data_i[8*i +: 8] = cur_byte;
        cur_byte += 1;
    end
    dram_data_vld_i = 1'b1;
    tkeep_i = 2**num_bytes-1; 
end
endtask: set_input

task clear_input;
begin
    dram_data_i = '0;
    dram_data_vld_i = 1'b0;
    tkeep_i = '0;
end
endtask

initial begin
    clk = 1'b1;
    rst = 1'b1;
    dram_data_i = '0;
    dram_data_vld_i = 1'b0;
    tkeep_i = '0;
    cur_byte = '0;

    #20 @(negedge clk) rst = 1'b0;

    #10 @(negedge clk) set_input(10);
    @(negedge clk) clear_input;

    #30 @(negedge clk) set_input(60);
    @(negedge clk) clear_input;

    // 6 in residue. Finish off.
    #30 @(negedge clk) set_input(58);
    @(negedge clk) clear_input;

    // Put 63 in new word
    #30 @(negedge clk) set_input(63);
    // Add 2 more
    @(negedge clk) set_input(2);
    @(negedge clk) clear_input;

    // Bunch of 64B
    #30 @(negedge clk) set_input(64);
    @(negedge clk) set_input(64);
    @(negedge clk) set_input(64);
    @(negedge clk) set_input(64);
    @(negedge clk) clear_input;


    #40 $display("Finishing.");
    $finish;

end

always @(posedge clk) 
    if (~rst & bram_wr_o) $display("Output = %64h", bram_wrdata_o);

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

endmodule: sim_top
