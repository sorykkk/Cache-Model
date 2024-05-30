`include "macros.v"

// Cannot interrupt synthethizably interrupt for loop 
// That's why i am using hard-codded if's for each way

module control_unit #(
    parameter BYTE      = `BYTE,
    parameter SIZE      = `SIZE,
    parameter NWAYS     = `NWAYS,
    parameter NSETS     = `NSETS,
    parameter BLK_WIDTH = `BLK_WIDTH,
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
    input  wire                  rd_en, wr_en,

    input  reg                   valid [0:NWAYS-1][0:NSETS-1],
    input  reg                   dirty [0:NWAYS-1][0:NSETS-1],
    input  reg  [1:0]            lru   [0:NWAYS-1][0:NSETS-1],
    input  reg  [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1],
    input  reg  [BLK_WIDTH-1:0]  data  [0:NWAYS-1][0:NSETS-1],

    input  wire [PA_WIDTH-1:0]   addr,
    input  wire [WRD_WIDTH-1:0]  data_wr,

    input  wire [MEM_WIDTH-1:0]  mem_rd_blk,

    output wire                  mem_wr_en,
    output wire                  mem_rd_en,
    output reg [PA_WIDTH-1:0]    mem_addr,
    output reg [BLK_WIDTH]       mem_wr_blk,  

    output reg                   hit
    output reg [WRD_WIDTH-1:0]   word_out,
    output reg [BYTE-1:0]        byte_out
);

    // state parameters
    localparam IDLE       = 3'b000;
    localparam RD_HIT     = 3'b001;
    localparam RD_MISS    = 3'b010;
    localparam WR_HIT     = 3'b011;
    localparam WR_MISS    = 3'b100;
    localparam EVICT   = 3'b101;

    integer i;

    assign hit = ((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                ||(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG]))
                ||(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                ||(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));

    // state registers
    reg[2:0] state, next;
    reg rd_m, wr_m;

    //change states
    always @(posedge clk, negedge rst_n) begin 
        if(!rst_n) state <= IDLE;
        else       state <= next;
    end

    // set next state
    always @(*) begin 
        next = state;
        case(state)
            IDLE : begin   
                if(~rd_en && ~wr_en)   next = IDLE;
                else if(rd_en && hit)  next = RD_HIT;
                else if(wr_en && hit)  next = WR_HIT;
                else if(rd_en && ~hit) 
                begin 
                                       next = EVICT;
                                       rd_m = 1'b1;
                                       wr_m = 1'b0;
                end
                else if(wr_en && ~hit)
                begin 
                                       next = EVICT;
                                       rd_m = 1'b0;
                                       wr_m = 1'b1;
                end
            end

            EVICT : if(wr_m)           next = WR_MISS;
                    if(rd_m)           next = RD_MISS;

            RD_MISS, 
            WR_MISS :                  next = IDLE;
        endcase
    end

    // trigger signals based on next state
    always @(posedge clk, negedge rst_n) 
    begin 
        case(next)
            IDLE: begin 
                mem_wr_en <= 1'b0;
                mem_rd_en <= 1'b0;
                word_out <= {WRD_WIDTH{1'bz}};
                byte_out <= {WRD_WIDTH{1'bz}};
                wr_m <= 1'b0;
                rd_m <= 1'b0;
            end

            RD_HIT: begin 
                if(valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = data[0][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                    byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                    // update age registers
                    if(lru[1][addr[`INDEX]] <= lru[0][addr[`INDEX]]) lru[1][addr[`INDEX]] <= lru[1][addr[`INDEX]] + 1;
                    if(lru[2][addr[`INDEX]] <= lru[0][addr[`INDEX]]) lru[2][addr[`INDEX]] <= lru[2][addr[`INDEX]] + 1;
                    if(lru[3][addr[`INDEX]] <= lru[0][addr[`INDEX]]) lru[3][addr[`INDEX]] <= lru[3][addr[`INDEX]] + 1;
                    lru[0][addr[`INDEX]] = 2'b00;
                end

                else if(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = data[1][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                    byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                    // update age registers
                    if(lru[0][addr[`INDEX]] <= lru[1][addr[`INDEX]]) lru[0][addr[`INDEX]] <= lru[0][addr[`INDEX]] + 1;
                    if(lru[2][addr[`INDEX]] <= lru[1][addr[`INDEX]]) lru[2][addr[`INDEX]] <= lru[2][addr[`INDEX]] + 1;
                    if(lru[3][addr[`INDEX]] <= lru[1][addr[`INDEX]]) lru[3][addr[`INDEX]] <= lru[3][addr[`INDEX]] + 1;
                    lru[1][addr[`INDEX]] = 2'b00;
                end

                else if(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = data[2][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                    byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                    // update age registers
                    if(lru[1][addr[`INDEX]] <= lru[2][addr[`INDEX]]) lru[1][addr[`INDEX]] <= lru[1][addr[`INDEX]] + 1;
                    if(lru[0][addr[`INDEX]] <= lru[2][addr[`INDEX]]) lru[0][addr[`INDEX]] <= lru[0][addr[`INDEX]] + 1;
                    if(lru[3][addr[`INDEX]] <= lru[2][addr[`INDEX]]) lru[3][addr[`INDEX]] <= lru[3][addr[`INDEX]] + 1;
                    lru[2][addr[`INDEX]] = 2'b00;
                end

                else if(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = data[3][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                    byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                    // update age registers
                    if(lru[1][addr[`INDEX]] <= lru[3][addr[`INDEX]]) lru[1][addr[`INDEX]] <= lru[1][addr[`INDEX]] + 1;
                    if(lru[2][addr[`INDEX]] <= lru[3][addr[`INDEX]]) lru[2][addr[`INDEX]] <= lru[2][addr[`INDEX]] + 1;
                    if(lru[0][addr[`INDEX]] <= lru[3][addr[`INDEX]]) lru[0][addr[`INDEX]] <= lru[0][addr[`INDEX]] + 1;
                    lru[3][addr[`INDEX]] = 2'b00;
                end
            end

            WR_HIT : begin 
                 // i_th way
                if(valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG])) 
                begin
                    // for store instr there is no output/byte word
                    word_out = {WRD_WIDTH{1'bz}};
                    byte_out = {BYTE{1'bz}};
                    // mark as dirty block
                    dirty[0][addr[`INDEX]] <= 1'b1;
                    // overwrite data info from cache's block
                    data[0][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH] <= data_wr;

                    // update age registers
                    if(lru[1][addr[`INDEX]] <= lru[0][addr[`INDEX]]) lru[1][addr[`INDEX]] <= lru[1][addr[`INDEX]] + 1;
                    if(lru[2][addr[`INDEX]] <= lru[0][addr[`INDEX]]) lru[2][addr[`INDEX]] <= lru[2][addr[`INDEX]] + 1;
                    if(lru[3][addr[`INDEX]] <= lru[0][addr[`INDEX]]) lru[3][addr[`INDEX]] <= lru[3][addr[`INDEX]] + 1;
                    lru[0][addr[`INDEX]] = 2'b00;
                end

                else if(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = {WRD_WIDTH{1'bz}};
                    byte_out = {BYTE{1'bz}};
                    dirty[1][addr[`INDEX]] <= 1'b1;
                    data[1][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH] <= data_wr;

                    // update age registers
                    if(lru[0][addr[`INDEX]] <= lru[1][addr[`INDEX]]) lru[0][addr[`INDEX]] <= lru[0][addr[`INDEX]] + 1;
                    if(lru[2][addr[`INDEX]] <= lru[1][addr[`INDEX]]) lru[2][addr[`INDEX]] <= lru[2][addr[`INDEX]] + 1;
                    if(lru[3][addr[`INDEX]] <= lru[1][addr[`INDEX]]) lru[3][addr[`INDEX]] <= lru[3][addr[`INDEX]] + 1;
                    lru[1][addr[`INDEX]] = 2'b00;
                end

                else if(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = {WRD_WIDTH{1'bz}};
                    byte_out = {BYTE{1'bz}};
                    dirty[2][addr[`INDEX]] <= 1'b1;
                    data[2][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH] <= data_wr;

                    // update age registers
                    if(lru[1][addr[`INDEX]] <= lru[2][addr[`INDEX]]) lru[1][addr[`INDEX]] <= lru[1][addr[`INDEX]] + 1;
                    if(lru[0][addr[`INDEX]] <= lru[2][addr[`INDEX]]) lru[0][addr[`INDEX]] <= lru[0][addr[`INDEX]] + 1;
                    if(lru[3][addr[`INDEX]] <= lru[2][addr[`INDEX]]) lru[3][addr[`INDEX]] <= lru[3][addr[`INDEX]] + 1;
                    lru[2][addr[`INDEX]] = 2'b00;
                end

                else if(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])) 
                begin
                    word_out = {WRD_WIDTH{1'bz}};
                    byte_out = {BYTE{1'bz}};
                    dirty[3][addr[`INDEX]] <= 1'b1;
                    data[3][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH] <= data_wr;

                    // update age registers
                    if(lru[1][addr[`INDEX]] <= lru[3][addr[`INDEX]]) lru[1][addr[`INDEX]] <= lru[1][addr[`INDEX]] + 1;
                    if(lru[2][addr[`INDEX]] <= lru[3][addr[`INDEX]]) lru[2][addr[`INDEX]] <= lru[2][addr[`INDEX]] + 1;
                    if(lru[0][addr[`INDEX]] <= lru[3][addr[`INDEX]]) lru[0][addr[`INDEX]] <= lru[0][addr[`INDEX]] + 1;
                    lru[3][addr[`INDEX]] = 2'b00;
                end
            end

            EVICT : begin 
                mem_rd_en <= 1'b1;
                
                // write-back 
                if(valid[0][addr[`INDEX]] && (lru[0][addr[`INDEX]] == 2'b11) && (dirty[0][addr[`INDEX]] == 1'b1)) 
                begin 
                    mem_addr <= addr;
                    mem_wr_en <= 1'b1;
                    mem_wr_blk <= data[0][addr[`INDEX]];
                end

                else if(valid[1][addr[`INDEX]] && (lru[1][addr[`INDEX]] == 2'b11) && (dirty[1][addr[`INDEX]] == 1'b1)) 
                begin 
                    mem_addr <= addr;
                    mem_wr_en <= 1'b1;
                    mem_wr_blk <= data[1][addr[`INDEX]];
                end

                else if(valid[2][addr[`INDEX]] && (lru[2][addr[`INDEX]] == 2'b11) && (dirty[2][addr[`INDEX]] == 1'b1)) 
                begin 
                    mem_addr <= addr;
                    mem_wr_en <= 1'b1;
                    mem_wr_blk <= data[2][addr[`INDEX]];
                end

                else if(valid[3][addr[`INDEX]] && (lru[3][addr[`INDEX]] == 2'b11) && (dirty[3][addr[`INDEX]] == 1'b1)) 
                begin 
                    mem_addr <= addr;
                    mem_wr_en <= 1'b1;
                    mem_wr_blk <= data[3][addr[`INDEX]];
                end
            end

            RD_MISS: begin 
                word_out = mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                if(~valid[0][addr[`INDEX]] || (lru[0][addr[`INDEX]] == 2'b11))
                begin
                    data[0][addr[`INDEX]] <= mem_rd_blk;
                    tag[0][addr[`INDEX]] <= addr[`TAG];
                    dirty[0][addr[`INDEX]] <= 1'b0;
                    valid[0][addr[`INDEX]] <= 1'b1;
                end
                
                else if(~valid[1][addr[`INDEX]] || (lru[1][addr[`INDEX]] == 2'b11))
                begin
                    data[1][addr[`INDEX]] <= mem_rd_blk;
                    tag[1][addr[`INDEX]] <= addr[`TAG];
                    dirty[1][addr[`INDEX]] <= 1'b0;
                    valid[1][addr[`INDEX]] <= 1'b1;
                end

                else if(~valid[2][addr[`INDEX]] || (lru[2][addr[`INDEX]] == 2'b11))
                begin
                    data[2][addr[`INDEX]] <= mem_rd_blk;
                    tag[2][addr[`INDEX]] <= addr[`TAG];
                    dirty[2][addr[`INDEX]] <= 1'b0;
                    valid[2][addr[`INDEX]] <= 1'b1;
                end

                else if(~valid[3][addr[`INDEX]] || (lru[3][addr[`INDEX]] == 2'b11))
                begin
                    data[3][addr[`INDEX]] <= mem_rd_blk;
                    tag[3][addr[`INDEX]] <= addr[`TAG];
                    dirty[3][addr[`INDEX]] <= 1'b0;
                    valid[3][addr[`INDEX]] <= 1'b1;
                end
            end

            WR_MISS : begin 
                word_out = {WRD_WIDTH{1'bz}};
                byte_out = {BYTE{1'bz}};

                if(~valid[0][addr[`INDEX]] || (lru[0][addr[`INDEX]] == 2'b11))
                begin
                    data[0][addr[`INDEX]] <= data_wr;
                    tag[0][addr[`INDEX]] <= addr[`TAG];
                    dirty[0][addr[`INDEX]] <= 1'b1;
                    valid[0][addr[`INDEX]] <= 1'b1;
                end

                else if(~valid[1][addr[`INDEX]] || (lru[1][addr[`INDEX]] == 2'b11))
                begin
                    data[1][addr[`INDEX]] <= data_wr;
                    tag[1][addr[`INDEX]] <= addr[`TAG];
                    dirty[1][addr[`INDEX]] <= 1'b1;
                    valid[1][addr[`INDEX]] <= 1'b1;
                end

                else if(~valid[2][addr[`INDEX]] || (lru[2][addr[`INDEX]] == 2'b11))
                begin
                    data[2][addr[`INDEX]] <= data_wr;
                    tag[2][addr[`INDEX]] <= addr[`TAG];
                    dirty[2][addr[`INDEX]] <= 1'b1;
                    valid[2][addr[`INDEX]] <= 1'b1;
                end

                else if(~valid[3][addr[`INDEX]] || (lru[3][addr[`INDEX]] == 2'b11))
                begin
                    data[3][addr[`INDEX]] <= data_wr;
                    tag[3][addr[`INDEX]] <= addr[`TAG];
                    dirty[3][addr[`INDEX]] <= 1'b1;
                    valid[3][addr[`INDEX]] <= 1'b1;
                end
            end
        endcase
    end

endmodule