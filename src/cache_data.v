/*
* Sorin Besleaga
* Last modified: 14.05.24
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

`include "macros.v"
`include "cache_fsm.v"

module cache_data #(
    parameter BYTE      = `BYTE,
    parameter SIZE      = `SIZE,
    parameter NWAYS     = `NWAYS,
    parameter NSETS     = `NSETS,
    parameter BLK_SIZE  = `BLK_SIZE,
    parameter PA_WIDTH  = `PA_WIDTH,
    parameter WRD_WIDTH = `WRD_WIDTH,

    parameter MEM_WIDTH = `MEM_WIDTH,

    parameter IDX_WIDTH = `IDX_WIDTH,
    parameter TAG_WIDTH = `TAG_WIDTH,
    parameter BO_WIDTH  = `BO_WIDTH,
    parameter WO_WIDTH  = `WO_WIDTH
)
(
    input  wire                  clk, rst_n,
    
    input  wire [PA_WIDTH-1:0]   addr,         // addr from CPU
    input  wire [WORD_WIDTH-1:0] data_in,      // data from CPU (store instruction)
    
    input  wire                  rd_en,        // 1 if load instr
    input  wire                  w_en,         // 1 if store instr
    
    output wire                  hit,          // 1 if hit, 0 if miss
    output wire [WORD_WIDTH-1:0] word_out,     // data from cache to CPU
    output wire [BYTE-1:0]       byte_out,     // byte that is extracted from word
    
    output wire                  mem_rd_en,    // 1 if reading from memory
    output wire [PA_WIDTH-1:0]   mem_rd_addr,  // memory read addr 
    output wire                  mem_wr_en,    // 1 if writing to memory
    output wire [PA_WIDTH-1:0]   mem_wr_addr,  // memory write address

    input  wire [MEM_WIDTH-1:0]  mem_data_in   // data from memory to cache
    output wire [MEM_WIDTH-1:0]  mem_data_out, // data from cache to memory
);

    // Define all ways
    reg                  valid [0:NWAYS-1][0:NSETS-1];
    reg                  dirty [0:NWAYS-1][0:NSETS-1];
    reg [1:0]            lru   [0:NWAYS-1][0:NSETS-1];
    reg [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1];
    reg [BLOCK_SIZE-1:0] data  [0:NWAYS-1][0:NSETS-1];

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
    reg                  _hit_miss     = 1'b0;
    reg [WORD_WIDTH-1:0] _word_out     = {WORD_WIDTH{1'b0}};
    reg [BYTE-1:0]       _byte_out     = {BYTE{1'b0}};
    reg [MEM_WIDTH-1:0]  _mem_data_out = {WORD_WIDTH{1'b0}};
    reg [PA_WIDTH-1:0]   _mem_wr_addr  = {PA_WIDTH{1'b0}};
    reg                  _mem_wr_en    = 1'b0; 

    assign hit = _hit;
    // daca oricare block din set este valid si ii tag-ul cautat
    assign mem_rd_en = !((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                       ||(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG]))
                       ||(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                       ||(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));

    assign mem_wr_en    = _mem_wr_en;
    assign mem_data_out = _mem_data_out;
    assign mem_rd_addr  = {addr[`TAG], addr[`INDEX]};
    assign mem_wr_addr  = _mem_wr_addr;
    assign word_out     = _word_out;
    assign byte_out     = _byte_out;


    input reg clk, rst_n,
    input reg rd_en, wr_en, hit,

    reg                  valid [0:NWAYS-1][0:NSETS-1],
    reg                  dirty [0:NWAYS-1][0:NSETS-1],
    reg [1:0]            lru   [0:NWAYS-1][0:NSETS-1],
    reg [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1],
    reg [BLOCK_SIZE-1:0] data  [0:NWAYS-1][0:NSETS-1]

    cache_fsm cache_cntrl(.clk(clk),     .rst_n(rst_n),
                          .valid(valid), .dirty(dirty),
                          .tag(tag),     .data(data), 
                          .lru(lru),     .word_out(_word_out),
                          .byte_out(_byte_out));
    
    



endmodule
