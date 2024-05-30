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
    output reg  [PA_WIDTH-1:0]   mem_addr,
    output reg                   mem_rd_en,
    output reg                   mem_wr_en,    // 1 if writing to memory
    output reg  [BLK_WIDTH-1:0]  mem_wr_blk,   // data from cache to memory

    output reg                   hit,          // 1 if hit, 0 if miss
    output reg  [WRD_WIDTH-1:0]  word_out,     // data from cache to CPU
    output reg  [BYTE-1:0]       byte_out      // byte that is extracted from word
);

    // Define all ways
    reg                  valid [0:NWAYS-1][0:NSETS-1];
    reg                  dirty [0:NWAYS-1][0:NSETS-1];
    reg [1:0]            lru   [0:NWAYS-1][0:NSETS-1];
    reg [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1];
    reg [BLK_WIDTH-1:0]  data  [0:NWAYS-1][0:NSETS-1];

    wire                  _valid [0:NWAYS-1][0:NSETS-1];
    wire                  _dirty [0:NWAYS-1][0:NSETS-1];
    wire [1:0]            _lru   [0:NWAYS-1][0:NSETS-1];
    wire [TAG_WIDTH-1:0]  _tag   [0:NWAYS-1][0:NSETS-1];
    wire [BLK_WIDTH-1:0]  _data  [0:NWAYS-1][0:NSETS-1];

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


    always @(posedge clk, negedge rst_n) begin 
        if(!rst_n) begin 
            for(i = 0; i < NWAYS; i = i+1) begin 
                for(j = 0; j < NSETS; j = j+1) begin 
                    valid[i][j] <= 1'b0;
                    dirty[i][j] <= 1'b0;
                    lru[i][j] <= 2'b00;
                end
            end
        end
        else begin 
            for(i = 0; i < NWAYS; i = i+1) begin 
                for(j = 0; j < NSETS; j = j+1) begin 
                    valid[i][j] <= _valid[i][j];
                    dirty[i][j] <= _dirty[i][j];
                    lru[i][j] <= _lru[i][j];
                    tag[i][j] <= _tag[i][j];
                    data[i][j] <= _data[i][j];
                end
            end
        end

    end

    // Define internal reg
    // reg [PA_WIDTH-1:0]  _mem_addr;
    // reg                 _mem_rd_en, _mem_wr_en;
    // reg [BLK_WIDTH-1:0] _mem_wr_blk;
    // reg                 _hit;
    // reg [WRD_WIDTH-1:0] _word_out;
    // reg [BYTE-1:0]      _byte_out;


    // assign mem_addr   = _mem_addr;
    // assign mem_rd_en  = _mem_rd_en;
    // assign mem_wr_en  = _mem_wr_en;
    // assign mem_wr_blk = _mem_wr_blk;
    // assign hit        = _hit;
    // assign word_out   = _word_out;
    // assign byte_out   = _byte_out;



    control_unit CACHE_CNTRL(   .clk        (clk),     
                                .rst_n      (rst_n),
                                .rd_en      (rd_en),
                                .wr_en      (wr_en),

                                .valid      (_valid), 
                                .dirty      (_dirty),
                                .tag        (_tag),     
                                .data       (_data), 
                                .lru        (_lru),  

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
