`timescale 1ns/1ns
`include "macros.sv"
`include "cache_data.sv"
`include "mem.sv"

module cache_tb;

    localparam CLK_PERIOD = 100,
               CLK_CYCLES = 10,
               RST_PULSE  = 25;

    reg                  clk, rst_n;
    
    reg [PA_WIDTH-1:0]   addr;
    reg [WRD_WIDTH-1:0]  data_wr;
    
    reg                  rd_en, wr_en;
    
    //memory control outputs
    wire [BLK_WIDTH-1:0] mem_rd_blk;
    reg [PA_WIDTH-1:0]   mem_addr;
    reg                  mem_rd_en, mem_wr_en;
    reg [BLK_WIDTH-1:0]  mem_wr_blk;

    reg                  hit;
    reg [WRD_WIDTH-1:0]  word_out;
    reg [BYTE-1:0]       byte_out;

    //cache signals
    reg                  cache_mem_wr_en, cache_mem_rd_en;
    reg [BLK_WIDTH-1:0]  cache_mem_wr_blk;
    reg [PA_WIDTH-1:0]   cache_mem_addr;

    cache_data CACHE_DUT(
        .clk        (clk), 
        .rst_n      (rst_n),
        .rd_en      (rd_en),
        .wr_en      (wr_en),
        .addr       (addr),
        .data_wr    (data_wr),

        .mem_rd_blk (mem_rd_blk),
        .mem_addr   (mem_addr),
        .mem_rd_en  (mem_rd_en),
        .mem_wr_en  (mem_wr_en),
        .mem_wr_blk (mem_wr_blk),
                            
        .hit        (hit),
        .word_out   (word_out),
        .byte_out   (byte_out)
    );

    mem MEM_DUT(
        .clk     (clk),
        .addr    (mem_addr),
        .rd_en   (mem_rd_en),
        .wr_en   (mem_wr_en),
        .wr_data (mem_wr_blk),
        .rd_data (mem_rd_blk)
    );

    initial begin 
        $dumpfile("cache_data.vcd");
        $dumpvars(0, cache_tb);
    end

    initial begin 
        clk = 1'b1;
        repeat(CLK_CYCLES*2) #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin 
        // mem_wr_en = 1'b0;
        // mem_rd_en = 1'b0;
        // rst_n = 1'b0;
        // #(RST_PULSE);
        // rst_n = 1'b1;
        // mem_rd_en = 1'b1;
        // #(CLK_PERIOD-RST_PULSE);
        // mem_addr <= 32'h00;
        // #(CLK_PERIOD);
        // mem_addr <= mem_addr + 32'h40;
        // #(CLK_PERIOD);
        // mem_addr <= mem_addr + 32'h40;

        // #(CLK_PERIOD);
        // mem_addr <= mem_addr + 32'h40;

        // #(CLK_PERIOD);
    end

endmodule
