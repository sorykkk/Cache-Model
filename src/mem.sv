/*
* Author:            Sorin Besleaga
* Last modification: 30.05.24
* Status:            finished
*/

`include "macros.sv"
//memory as array of bytes

module mem #(
    parameter DEPTH     = (1<<15),   // 32KB // depending on this parameter, the compilation time can be bigger or smaller
    parameter WIDTH     = BYTE,
    parameter INIT      = 0,         // if 1, resets all the memory
    parameter SEED      = 1,         // if the memory should be initialized with random values
    parameter NSEED_BLK = 512        // number of blocks that should be seeded
)
(
    input  wire                 clk,

    input  wire [PA_WIDTH-1:0]  addr,   // address that should be used to reference MM addresses

    input  wire                 rd_en,
    input  wire                 wr_en,

    input  wire [BLK_WIDTH-1:0] wr_data, // input block that should be written in MM
    output reg  [BLK_WIDTH-1:0] rd_data  // output block from memory to cache
);
    // memory array 
    reg [WIDTH-1:0] MM [0:DEPTH-1];

    integer i, j;
    reg[31:0] seed;
    
    initial begin 
        if(INIT) // initialize with 0 or no
        begin
            for(i = 0; i < DEPTH; i = i+1)
                MM[i] = {WIDTH{1'b0}};
        end
        
        if(SEED) 
        begin 
            // keeping same seed for the ease of debugging
            seed = 32'hDEADBEEF;
            for(i = 0; i < (BLK_WIDTH/BYTE)*NSEED_BLK; i = i+32'h40)
            begin 
                for (j = 0; j < (BLK_WIDTH/BYTE); j = j + 1) 
                begin
                    // generating pseudo-random numbers (my own formula)
                    MM[i+j] = {8'h0f + (i-j*i), 8'hf0 - (i*j+j)} ^ {8'h0, $random(seed)};
                    // visualize the memory bytes
                    //$display("MM[%d] = %h", i+j, MM[i+j]);
                end
            end
        end
    end


    // Calculate the number of words per block
    localparam WORDS_PER_BLOCK = BLK_WIDTH / WRD_WIDTH;
    localparam BYTES_PER_WORD = WRD_WIDTH / WIDTH;

    integer word_idx, byte_idx;

    // Read from Main Memory
    always @(*) begin
        if (rd_en) begin
            for (word_idx = 0; word_idx < WORDS_PER_BLOCK; word_idx = word_idx + 1) begin
                for (byte_idx = 0; byte_idx < BYTES_PER_WORD; byte_idx = byte_idx + 1) begin
                    rd_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH] = MM[addr + (word_idx * BYTES_PER_WORD) + byte_idx];
                end
            end
            
        end
    end

    // Write to Main Memory
    always @(*) begin
        if (wr_en) begin
            for (word_idx = 0; word_idx < WORDS_PER_BLOCK; word_idx = word_idx + 1) begin
                for (byte_idx = 0; byte_idx < BYTES_PER_WORD; byte_idx = byte_idx + 1) begin
                    MM[addr + (word_idx * BYTES_PER_WORD) + byte_idx] = wr_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH];
                    
                    // It assures that when read and write enables at the same time, it will provide at rd_data the value that come in wr_data
                    if(rd_en)
                        rd_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH] = wr_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH];
                    // $display("(addr: %d)(index_addr: %d) %h",addr,addr + (word_idx * BYTES_PER_WORD) + byte_idx, MM[addr + (word_idx * BYTES_PER_WORD) + byte_idx]);
                end
            end
            // $display("\n");
        end
    end

endmodule