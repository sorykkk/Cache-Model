//byte-addressable

//Phisical Address:
`define WOFFSET 1:0   // word offset
`define BOFFSET 5:2   // block offset
`define INDEX   12:6  // index slice
`define TAG     31:13 // tag slice

//Cache defines:
`define BYTE      8       // 1 B =  8 bits
`define SIZE      (1<<18) // total size of cache data size in bits
`define NWAYS     4       // number of set associetivity
`define NSETS     128     // number of sets in cache
`define BLK_SIZE  512     // size of the block in bits
`define PA_WIDTH  32      // width of physical address and  in bits
`define WRD_WIDTH 32      // width of a word in bits

`define MEM_WIDTH 512     // = 1 word

`define IDX_WIDTH 7       // 128 sets (1 set = 4 blocks)
`define TAG_WIDTH 19
`define BO_WIDTH  4       // 16 words/block
`define WO_WIDTH  2       // 4 B/word

