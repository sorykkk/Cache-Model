/*
* Sorin Besleaga
* Last modified: 14.05.24
* Status: unfinished
*/
//byte-addressable
`define WOFFSET 1:0   //word offset
`define BOFFSET 5:2   //block offset
`define INDEX   12:6  // index slice
`define TAG     31:13 // tag slice

module cache_data #(
    parameter SIZE        = 2>>18,
    parameter NWAYS       = 4,
    parameter NSETS       = 128,
    parameter BLOCK_SIZE  = 64,
    parameter CWIDTH      = 32,

    parameter MEM_WIDTH   = 64,
    parameter INDEX_WIDTH = 7,
    parameter TAG_WIDTH   = 19,
    parameter BOFFSET     = 4,
    parameter WOFFSET     = 2,
)
(
    input  wire                 clk,
    input  wire [WIDTH-1:0]     addr,        // addr from CPU
    input  wire [WIDTH-1:0]     data_in,     // data from CPU
    input  wire                 rd_en,       // 1 if load instr
    input  wire                 w_en,        // 1 if store instr
    
    output wire                 hit_miss,    // 1 if hit, 0 if miss
    output wire [WIDTH-1:0]     data_out,    // data from cache to CPU
    output wire [WIDTH-1:0]     mem_rd_addr, // memory read addr 
    output wire                 mem_rd_en,   // 1 if reading from memory
    output wire [WIDTH-1:0]     mem_wr_addr, // memory write address
    output wire                 mem_wr_en,   // 1 if writing to memory

    input  wire [MEM_WIDTH-1:0] mem_data_in  // data from memory to cache
    output wire [MEM_WIDTH-1:0] mem_data_out,// data from cache to memory
);

    //put all ways
    reg                  valid [0:NWAYS][0:NSETS-1];
    reg                  dirty [0:NWAYS][0:NSETS-1];
    reg [1:0]            lru   [0:NWAYS][0:NSETS-1];
    reg [TAG_WIDTH-1:0]  tag   [0:NWAYS][0:NSETS-1];
    reg [BLOCK_SIZE-1:0] data  [0:NWAYS][0:NSETS-1];

    //init to 0
    integer i, j;
    initial begin 
        for(i = 0; i < NWAYS; i = i + 1)
            for(j = 0; j < NSETS; j = j + 1) begin 
                valid[i][j] = 1'b0;
                dirty[i][j] = 1'b0;
                lru  [i][j] = 2'b00;
            end
    end

    
    



endmodule
