/*
* Sorin Besleaga
* Last modified: 30.05.24
* Status: unfinished
*/

/*
* Specs:
*       Associativity level: 4   way
*       Cache data size:     32  KiB
*       Block size:          64  B/block
*       Number of sets:      128 sets
*       Word size:           4   B/word
*       Words per block:     16  words/block
*/

`include "macros.sv"
`include "cache_fsm.sv"

module cache_data
(
    input  wire                  clk, rst_n,
    
    input  wire [PA_WIDTH-1:0]   addr,         // addr from CPU
    input  wire [WRD_WIDTH-1:0]  data_wr,      // data from CPU (store instruction) / data to write 
    
    input  wire                  rd_en,        // 1 if load instr
    input  wire                  wr_en,        // 1 if store instr
    
    //memory control outputs
    input  wire [BLK_WIDTH-1:0]  mem_rd_blk,
    output wire [PA_WIDTH-1:0]   mem_addr,
    output wire                  mem_rd_en,
    output wire                  mem_wr_en,    // 1 if writing to memory
    output wire [BLK_WIDTH-1:0]  mem_wr_blk,   // data from cache to memory

    output wire                  hit,          // 1 if hit, 0 if miss
    output wire [WRD_WIDTH-1:0]  word_out,     // data from cache to CPU
    output wire [BYTE-1:0]       byte_out      // byte that is extracted from word
);

    // Define all ways
    reg                  valid [0:NWAYS-1][0:NSETS-1];
    reg                  dirty [0:NWAYS-1][0:NSETS-1];
    reg [1:0]            lru   [0:NWAYS-1][0:NSETS-1];
    reg [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1];
    reg [BLK_WIDTH-1:0]  data  [0:NWAYS-1][0:NSETS-1];

    // Init to 0 all
    integer i, j;
    initial begin 
        for(i = 0; i < NWAYS; i = i + 1) 
        begin
            for(j = 0; j < NSETS; j = j + 1) 
            begin 
                valid[i][j] = 1'b0;
                dirty[i][j] = 1'b0;
                lru  [i][j] = 2'b00;
            end
        end
    end

    // Define internal reg
    // reg                  _hit          = 1'b0;
    // reg [WRD_WIDTH-1:0]  _word_out     = {WRD_WIDTH{1'b0}};
    // reg [BYTE-1:0]       _byte_out     = {BYTE{1'b0}};
    // reg [MEM_WIDTH-1:0]  _mem_wr_data  = {WRD_WIDTH{1'b0}};
    // reg [PA_WIDTH-1:0]   _mem_wr_addr  = {PA_WIDTH{1'b0}};
    // reg                  _mem_wr_en    = 1'b0; 

    // assign hit = _hit;

    // assign mem_wr_en    = _mem_wr_en;
    // assign mem_data_out = _mem_data_out;
    // assign mem_wr_addr  = _mem_wr_addr;
    // assign word_out     = _word_out;
    // assign byte_out     = _byte_out;
    // assign mem_wr_data  = _mem_wr_data;

    control_unit CACHE_CNTRL(   .clk        (clk),     
                                .rst_n      (rst_n),
                                .rd_en      (rd_en),
                                .wr_en      (wr_en),

                                .valid      (valid), 
                                .dirty      (dirty),
                                .tag        (tag),     
                                .data       (data), 
                                .lru        (lru),  

                                .addr       (addr),
                                .data_wr    (data_wr),

                                .mem_wr_en  (mem_wr_en),
                                .mem_rd_en  (mem_rd_en),
                                .mem_rd_blk (mem_rd_blk),
                                .mem_wr_blk (mem_wr_blk),
                                .mem_addr   (mem_addr),

                                .word_out   (word_out),
                                .byte_out   (byte_out), 
                                .hit        (hit)
                            );
    
endmodule
