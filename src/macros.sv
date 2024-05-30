//byte-addressable
`ifndef _macros_h
`define _macros_h
//Phisical Address:
`define WOFFSET 1:0   // word offset
`define BOFFSET 5:2   // block offset
`define INDEX   12:6  // index slice
`define TAG     31:13 // tag slice

//Cache defines:
localparam BYTE      = 8;       // 1 B =  8 bits
localparam SIZE      = (1<<18); // total size of cache data size in bits
localparam NWAYS     = 4;       // number of set associetivity
localparam NSETS     = 128;     // number of sets in cache
localparam BLK_WIDTH = 512;     // size of the block in bits
localparam PA_WIDTH  = 32;      // width of physical address and  in bits
localparam WRD_WIDTH = 32;      // width of a word in bits


localparam IDX_WIDTH = 7;       // 128 sets (1 set = 4 blocks)
localparam TAG_WIDTH = 19;
localparam BO_WIDTH  = 4;       // 16 words/block
localparam WO_WIDTH  = 2;       // 4 B/word

`endif
