`timescale 1ns/1ns
`include "macros.sv"
`include "cache_data.sv"
`include "mem.sv"

module cache_tb;

    localparam           CLK_PERIOD = 100,
                         CLK_CYCLES = 20,
                         RST_PULSE  = 25;

    reg                  clk, rst_n;
    
    reg [PA_WIDTH-1:0]   addr;
    reg [WRD_WIDTH-1:0]  data_wr;
    
    reg                  rd_en, wr_en;
    
    //memory control outputs
    wire[BLK_WIDTH-1:0]  mem_rd_blk;
    reg [PA_WIDTH-1:0]   mem_addr;
    reg                  mem_rd_en, mem_wr_en;
    reg [BLK_WIDTH-1:0]  mem_wr_blk;

    //cache output
    reg                  hit;
    reg [WRD_WIDTH-1:0]  word_out;
    reg [BYTE-1:0]       byte_out;

    reg                  rdy;

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
        .byte_out   (byte_out),

        .rdy        (rdy)
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
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end
    reg[31:0] i;
    initial begin  
        //reset
        rst_n = 1'b0;
        rd_en = 1'b1;
        wr_en = 1'b0;
        //read miss
        addr = 32'h00;//8
        #(RST_PULSE);
        rst_n = 1'b1;
        @(posedge rdy);


        //read hit
        addr <= 32'h15;
        @(posedge rdy);
        //next word
        //read hit
        addr <= addr + 32'h04;
        @(posedge rdy);

        //write miss
        wr_en <= 1'b1;
        rd_en <= 1'b0;
        data_wr <= 32'hfafa_fafa;
        addr <= 32'h20d5; //8405
        @(posedge rdy);

        //write hit
        data_wr <= 32'hdada_dada;
        addr <= 32'h20d5;
        @(posedge rdy);

        //read hit
        wr_en <= 1'b0;
        rd_en <= 1'b1;
        addr <= 32'h20d5;
        @(posedge rdy);

        //read miss or write miss to replace dirty blocks to MM
        //set 0
        addr = 32'h2000;
        @(posedge rdy);
        addr = 32'h4000;
        @(posedge rdy);
        addr = 32'h6000;
        @(posedge rdy);

        //write hit + lru increment
        rd_en = 1'b0;
        wr_en = 1'b1;
        addr = 32'h4000;
        data_wr = 32'hfafa_fafa;
        @(posedge rdy);

        //read hit 
        rd_en = 1'b1;
        wr_en = 1'b0;
        @(posedge rdy);

        //read/write miss + replacement
        addr = 32'h8000;
        @(posedge rdy);

        @(posedge clk);
        $finish();
        
    end

endmodule
