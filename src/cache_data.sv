/*
* Author:            Sorin Besleaga
* Last modification: 31.05.24
* Status:            finished
*/

/*
* Specs:
*       Associativity level: 4   way
*       Cache data size:     32  KiB
*       Block size:          64  B/block
*       Number of sets:      128 sets
*       Word size:           4   B/word
*       Words per block:     16  words/block
*       Memory alignment:    Little-Endian (bytes in words and words in blocks are stored in little-endian)
                                            LSB bits are stored at top of Main Memory, and so in cache blocks
*/

`include "macros.sv"

module cache_data
(
    input  wire                  clk, rst_n,
    
    input  wire [PA_WIDTH-1:0]   addr,         // addr from CPU
    input  wire [WRD_WIDTH-1:0]  data_wr,      // data from CPU (store instruction) / data to write 
    
    input  wire                  rd_en,        // 1 if load instr
    input  wire                  wr_en,        // 1 if store instr
    
    //memory control outputs
    input  wire [BLK_WIDTH-1:0]  mem_rd_blk,   // memory from MM to cache
    output reg  [PA_WIDTH-1:0]   mem_addr,     // memory address to MM to retrieve block
    output reg                   mem_rd_en,    // memory read enable to ask for mem_rd_blk
    output reg                   mem_wr_en,    // 1 if writing to memory
    output reg [BLK_WIDTH-1:0]   mem_wr_blk,   // data from cache to memory

    //cache outputs
    output reg                   hit,          // 1 if hit, 0 if miss
    output reg  [WRD_WIDTH-1:0]  word_out,     // data from cache to CPU
    output reg  [BYTE-1:0]       byte_out,     // byte that is extracted from word

    output reg                   rdy           // says when it is ready to get new address
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
    localparam EVICT      = 3'b101;
         
    // internal state registers
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
                if((~rd_en && ~wr_en)||
                    (rd_en && wr_en))  next = IDLE;
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

            RD_HIT,
            WR_HIT,
            RD_MISS, 
            WR_MISS :                  next = IDLE;              
        endcase
    end

    // used for debugging a lot
    always @* begin 
        $display("ADDR: %b(%d)ten (%h)hex SET: %d",addr, addr,addr, addr[`INDEX]);
        for(i = 0; i < NWAYS; i = i+1)
        begin 
            $display("(block idx: %d)(BO: %d) (WO: %d) valid = %b lru = %b dirty = %b",i, addr[`BOFFSET], addr[`WOFFSET], valid[i][addr[`INDEX]], lru[i][addr[`INDEX]], dirty[i][addr[`INDEX]]);
        end
        $display("==================\n");
    end

    // trigger signals based on next state
    always @(posedge clk, negedge rst_n) 
    begin 
        case(next)
            IDLE: begin 
                // define hit signal
                hit <= ((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                      ||(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG]))
                      ||(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                      ||(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));

                // reset all states 
                {wr_m, rd_m, mem_wr_en, mem_rd_en, rdy} <= 5'b00000;

                word_out <= {WRD_WIDTH{1'bz}};
                byte_out <= {WRD_WIDTH{1'bz}};
            end

            // when it is read hit, it just extract word and byte, and update LRU
            RD_HIT: begin 
                rdy <= 1'b1;
                begin : rd_hit_loop
                    for(i = 0; i < NWAYS; i = i+1)
                    begin 
                        if(valid[i][addr[`INDEX]] && (tag[i][addr[`INDEX]] == addr[`TAG])) 
                        begin
                            word_out <= data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                            byte_out <= data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+(addr[`WOFFSET]*BYTE) +: BYTE];
                            
                            // update age registers
                            for(j = 0; j < NWAYS; j = j+1)
                                if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]) && valid[j][addr[`INDEX]])
                                    lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 2'b01;
                            lru[i][addr[`INDEX]] <= 2'b00;

                            disable rd_hit_loop;
                        end
                    end
                end
            end

            // when it is write hit, it sets dirty bit for block, write new data and update LRU
            WR_HIT : begin 
                 // i_th way
                rdy <= 1'b1;
                begin : wr_hit_loop
                    for(i = 0; i < NWAYS; i = i+1)
                    begin 
                        if(valid[i][addr[`INDEX]] && (tag[i][addr[`INDEX]] == addr[`TAG])) 
                        begin
                            // for store instr there is no output/byte word
                            word_out = {WRD_WIDTH{1'bz}};
                            byte_out = {BYTE{1'bz}};
                            // mark as dirty block
                            dirty[i][addr[`INDEX]] <= 1'b1;
                            // overwrite data info from cache's block
                            data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH] <= data_wr;

                            for(j = 0; j < NWAYS; j = j+1)
                                if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]) && valid[j][addr[`INDEX]])
                                    lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 2'b01;
                            lru[i][addr[`INDEX]] <= 2'b00;

                            disable wr_hit_loop;
                        end
                    end
                end
            end

            // when it is miss it should identify the block to evict, then evicts it if 
            // it is valid, is dirty or is the oldest and update LRU
            EVICT : begin 
                mem_addr <= addr;
                mem_rd_en <= 1'b1;

                begin : evict_loop 
                    for(i = 0; i < NWAYS; i=i+1)
                    begin 
                        //in case the evicted block is not the oldest one
                        if(valid[i][addr[`INDEX]] && (dirty[i][addr[`INDEX]] == 1'b1 || lru[i][addr[`INDEX]] == 2'b11))
                        begin 
                            mem_wr_en <= 1'b1;
                            mem_wr_blk <= data[i][addr[`INDEX]];

                            // Update LRU counters
                            for (j = 0; j < NWAYS; j = j + 1)
                                if (i != j && valid[j][addr[`INDEX]])
                                    if (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]] || (lru[i][addr[`INDEX]] == 2'b00 && valid[i][addr[`INDEX] == 1'b0]))
                                        lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 2'b01;
                            lru[i][addr[`INDEX]] <= 2'b00;
                            
                            disable evict_loop;
                        end
                    end
                end
            end

            // after evict, we extract new word and byte from the memory
            RD_MISS: begin 
                rdy <= 1'b1;
                mem_wr_en <= 1'b0;
                word_out <= mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                byte_out <= mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+(addr[`WOFFSET]*BYTE) +: BYTE];

                begin  : rd_miss_loop
                    // if there are invalid blocks then they have priority when inserting missed block
                    for(i = 0; i < NWAYS; i = i+1)
                    begin 
                        if(~valid[i][addr[`INDEX]] || (dirty[i][addr[`INDEX]] == 1'b1))
                        begin
                            data[i][addr[`INDEX]] <= mem_rd_blk;
                            tag[i][addr[`INDEX]] <= addr[`TAG];
                            dirty[i][addr[`INDEX]] <= 1'b0;
                            valid[i][addr[`INDEX]] <= 1'b1;

                            // Update LRU counters
                            for (j = 0; j < NWAYS; j = j + 1)
                                if (i != j && valid[j][addr[`INDEX]])
                                    if (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]] || lru[i][addr[`INDEX]] == 2'b00)
                                        lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 2'b01;
                            lru[i][addr[`INDEX]] <= 2'b00;

                            disable rd_miss_loop;
                        end
                    end
                end
            end

            // after evict, if there was write miss initially 
            // if the block dirty it will write-back to MM or if invalid
            WR_MISS : begin 
                rdy <= 1'b1;
                mem_rd_en <= 1'b0;
                word_out = {WRD_WIDTH{1'bz}};
                byte_out = {BYTE{1'bz}};

                begin : wr_miss_loop
                    for(i = 0; i < NWAYS; i = i+1)
                    begin 
                        if(~valid[i][addr[`INDEX]] || (dirty[i][addr[`INDEX]] == 1'b1))
                        begin
                            data[i][addr[`INDEX]] <= data_wr;
                            tag[i][addr[`INDEX]] <= addr[`TAG];
                            dirty[i][addr[`INDEX]] <= 1'b1;
                            valid[i][addr[`INDEX]] <= 1'b1;

                            // update age registers
                            for(j = 0; j < NWAYS; j = j+1)
                                if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]) && valid[j][addr[`INDEX]])
                                    lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 2'b01;
                            lru[i][addr[`INDEX]] <= 2'b00;

                            disable wr_miss_loop;
                        end
                    end
                end
            end
        endcase
    end

endmodule
