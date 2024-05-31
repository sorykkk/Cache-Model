/*
* Author:            Sorin Besleaga
* Last modification: 30.05.24
* Status:            finished
*/

`include "macros.sv"
//treb de definit aici operatiile pe memorie
//Un aray de byte-uri

module mem #(
    parameter DEPTH     = (1<<15),   // 32KB
    parameter WIDTH     = BYTE,
    parameter INIT      = 0,         // if 1, resets all the memory
    parameter SEED      = 1,
    parameter NSEED_BLK = 512
)
(
    input  wire                 clk,

    input  wire [PA_WIDTH-1:0]  addr,

    input  wire                 rd_en,
    input  wire                 wr_en,

    input  wire [BLK_WIDTH-1:0] wr_data,
    output reg  [BLK_WIDTH-1:0] rd_data
);

    reg [WIDTH-1:0] MM [0:DEPTH-1];
    integer i, j;

    initial begin 
        if(INIT)
        begin
            for(i = 0; i < DEPTH; i = i+1)
                MM[i] = {WIDTH{1'b0}};
        end
        
        if(SEED) 
        begin 
            for(i = 0; i < (BLK_WIDTH/BYTE)*NSEED_BLK; i = i+32'h40)
            begin 
                for (j = 0; j < (BLK_WIDTH/BYTE); j = j + 1) begin
                    MM[i+j] = {8'h0f + (i-j*i), 8'hf0 - (i*j+j)};
                    
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
                    
                    //It assures that when it is read and write enables at the same time, it will provide at rd_data the value that come in wr_data
                    if(rd_en)
                        rd_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH] = wr_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH];
                    // $display("(addr: %d)(index_addr: %d) %h",addr,addr + (word_idx * BYTES_PER_WORD) + byte_idx, MM[addr + (word_idx * BYTES_PER_WORD) + byte_idx]);
                end
            end
            // $display("\n");
        end
    end

endmodule