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

//byte-addressable
`define WOFFSET 1:0   // word offset
`define BOFFSET 5:2   // block offset
`define INDEX   12:6  // index slice
`define TAG     31:13 // tag slice

module cache_data #(
    parameter SIZE        = 2>>18, // total size of cache data size in bits
    parameter NWAYS       = 4,     // number of set associetivity
    parameter NSETS       = 128,   // number of sets in cache
    parameter BLOCK_SIZE  = 512,   // size of the block in bits
    parameter PA_WIDTH    = 32,    // width of physical address and  in bits
    parameter WORD_WIDTH  = 32,    // width of a word in bits

    parameter MEM_WIDTH   = 32,    // = 1 word

    parameter INDEX_WIDTH = 7,     // 128 sets (1 set = 4 blocks)
    parameter TAG_WIDTH   = 19,
    parameter BO_WIDTH    = 4,     // 16 words/block
    parameter WO_WIDTH    = 2      // 4 B/word
)
(
    input  wire                  clk,
    input  wire [PA_WIDTH-1:0]   addr,        // addr from CPU
    input  wire [WORD_WIDTH-1:0] data_in,     // data from CPU
    input  wire                  rd_en,       // 1 if load instr
    input  wire                  w_en,        // 1 if store instr
    
    output wire                  hit,         // 1 if hit, 0 if miss
    output wire [WORD_WIDTH-1:0] data_out,    // data from cache to CPU
    output wire [PA_WIDTH-1:0]   mem_rd_addr, // memory read addr 
    output wire                  mem_rd_en,   // 1 if reading from memory
    output wire [PA_WIDTH-1:0]   mem_wr_addr, // memory write address
    output wire                  mem_wr_en,   // 1 if writing to memory

    input  wire [MEM_WIDTH-1:0]  mem_data_in  // data from memory to cache
    output wire [MEM_WIDTH-1:0]  mem_data_out,// data from cache to memory
);

    //put all ways
    reg                  valid [0:NWAYS-1][0:NSETS-1];
    reg                  dirty [0:NWAYS-1][0:NSETS-1];
    reg [1:0]            lru   [0:NWAYS-1][0:NSETS-1];
    reg [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1];
    reg [BLOCK_SIZE-1:0] data  [0:NWAYS-1][0:NSETS-1];

    //init to 0
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


    // internal reg
    reg                  _hit_miss     = 1'b0;
    reg [WORD_WIDTH-1:0] _data_out     = {WORD_WIDTH{1'b0}};
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
    assign data_out     = _data_out;


    cache_fsm cache_cntrl();
    
    



endmodule
