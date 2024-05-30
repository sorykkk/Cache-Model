`include "macros.sv"
//treb de definit aici operatiile pe memorie
//Un aray de byte-uri
module mem #(
    parameter DEPTH     = (1<<20),   // 1MB
    parameter WIDTH     = BYTE,
    parameter INIT      = 0          // if 1, resets all the memory
)
(
    input  wire                 clk,

    input  wire [PA_WIDTH-1:0]  addr,

    input  wire                 rd_en,
    input  wire                 wr_en,

    input  reg  [BLK_WIDTH-1:0] wr_data,
    output reg  [BLK_WIDTH-1:0] rd_data
);

    reg [WIDTH-1:0] MM [0:DEPTH-1];
    // aici putem sa le hardcodam, sau sa facem ca ram

    integer i, j;
    initial begin 
        if(INIT)
            for(i = 0; i < DEPTH; i = i+1)
                MM[i] = {WIDTH{1'b0}};
    end

    // Calculate the number of words per block
    localparam WORDS_PER_BLOCK = BLK_WIDTH / WRD_WIDTH;
    localparam BYTES_PER_WORD = WRD_WIDTH / WIDTH;

    integer word_idx, byte_idx;

    // Read from Main Memory
    always @(posedge clk) begin
        if (rd_en) begin
            for (word_idx = 0; word_idx < WORDS_PER_BLOCK; word_idx = word_idx + 1) begin
                for (byte_idx = 0; byte_idx < BYTES_PER_WORD; byte_idx = byte_idx + 1) begin
                    rd_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH] <= MM[addr + (word_idx * BYTES_PER_WORD) + byte_idx];
                end
            end
        end
    end

    // Write to Main Memory
    always @(posedge clk) begin
        if (wr_en) begin
            for (word_idx = 0; word_idx < WORDS_PER_BLOCK; word_idx = word_idx + 1) begin
                for (byte_idx = 0; byte_idx < BYTES_PER_WORD; byte_idx = byte_idx + 1) begin
                    MM[addr + (word_idx * BYTES_PER_WORD) + byte_idx] <= wr_data[(word_idx * WRD_WIDTH) + (byte_idx * WIDTH) +: WIDTH];
                end
            end
        end
    end

endmodule