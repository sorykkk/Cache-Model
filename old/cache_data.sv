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
*       Memory alignment:    Big-Endian
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
    output reg [BLK_WIDTH-1:0]   mem_wr_blk,   // data from cache to memory

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

    // start of actual FSM

    // state parameters
    localparam IDLE       = 3'b000;
    localparam RD_HIT     = 3'b001;
    localparam RD_MISS    = 3'b010;
    localparam WR_HIT     = 3'b011;
    localparam WR_MISS    = 3'b100;
    localparam EVICT   = 3'b101;

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

            EVICT : begin
                    if(wr_m)           next = WR_MISS;
                    if(rd_m)           next = RD_MISS;
            end

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
