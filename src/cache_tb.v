`timesclae 1ns/1ns
`include "cache_data.v"

module cache_tb;
    reg                  clk, rst_n,
    
    reg [PA_WIDTH-1:0]   addr,
    reg [WRD_WIDTH-1:0]  data_wr,
    
    reg                  rd_en, wr_en;
    
    //memory control outputs
    reg [MEM_WIDTH-1:0]  mem_rd_blk;
    reg [PA_WIDTH-1:0]   mem_addr;
    reg                  mem_rd_en, mem_wr_en;
    reg [MEM_WIDTH-1:0]  mem_wr_blk;

    reg                  hit;
    reg [WRD_WIDTH-1:0]  word_out;
    reg [BYTE-1:0]       byte_out;


    cache_data CACHE_DUT(
                            .clk        (clk), 
                            .rst_n      (rst_n),
                            .rd_en      (rd_en),
                            .wr_en      (wr_en),

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
                    .clk(clk),
                    .addr(mem_addr),
                    .rd_en(mem_rd_en),
                    .wr_en(mem_wr_en),
                    .wr_data(mem_wr_blk),
                    .rd_data(mem_rd_blk)
                );

    initial begin 
        clk = 1'b0;
        repeat (50) clk = ~clk;
    end

    always @(*) begin 

    end

endmodule