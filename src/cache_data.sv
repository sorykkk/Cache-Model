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
    input  wire [BLK_WIDTH-1:0]  mem_rd_blk,
    output reg  [PA_WIDTH-1:0]   mem_addr,
    output reg                   mem_rd_en,
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
    integer i, j, k;
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

    always @* begin 
        $display("ADDR: %b(%d)ten (%h)hex SET: %d",addr, addr,addr, addr[`INDEX]);
        for(i = 0; i < NWAYS; i = i+1)
        begin 
            $display("(block idx: %d)(BO: %d) (WO: %d) valid = %b lru = %b dirty = %b",i, addr[`BOFFSET], addr[`WOFFSET], valid[i][addr[`INDEX]], lru[i][addr[`INDEX]], dirty[i][addr[`INDEX]]);
        end
        $display("==================\n");
    end

    // trigger signals based on next state
    integer expected;
    always @(posedge clk, negedge rst_n) 
    begin 
        case(next)
            IDLE: begin 
                hit <= ((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                      ||(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG]))
                      ||(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                      ||(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));

                {wr_m, rd_m, mem_wr_en, mem_rd_en, rdy} <= 5'b00000;

                word_out <= {WRD_WIDTH{1'bz}};
                byte_out <= {WRD_WIDTH{1'bz}};
            end

            RD_HIT: begin 
                rdy <= 1'b1;
                begin : rd_hit_loop
                    for(i = 0; i < NWAYS; i = i+1)
                    begin 
                        if(valid[i][addr[`INDEX]] && (tag[i][addr[`INDEX]] == addr[`TAG])) 
                        begin
                            word_out <= data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                            byte_out <= data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+(addr[`WOFFSET]*BYTE) +: BYTE];
                            
                            //expected  = i;
                            $display("RD LRU i VAL = %b", lru[i][addr[`INDEX]]);
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

                            $display("WR LRU i VAL = %b", lru[i][addr[`INDEX]]);
                            for(j = 0; j < NWAYS; j = j+1)
                                if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]) && valid[j][addr[`INDEX]])
                                    lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 1;
                            lru[i][addr[`INDEX]] <= 2'b00;

                            disable wr_hit_loop;
                        end
                    end
                end
            end

            EVICT : begin 
                mem_addr <= addr;
                mem_rd_en <= 1'b1;

                begin : evict_loop 
                    for(i = 0; i < NWAYS; i=i+1)
                    begin 
                        if(valid[i][addr[`INDEX]]  && (dirty[i][addr[`INDEX]] == 1'b1) && (lru[i][addr[`INDEX]] == 2'b11)) //&& (lru[i][addr[`INDEX]] == 2'b11)
                        begin 
                            $display("HAPPY EVICTING!");
                            mem_wr_en <= 1'b1;
                            mem_wr_blk <= data[i][addr[`INDEX]];
                            
                            disable evict_loop;
                        end
                    end
                end
            end

            RD_MISS: begin 
                rdy <= 1'b1;
                mem_wr_en <= 1'b0;
                word_out <= mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                byte_out <= mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+(addr[`WOFFSET]*BYTE) +: BYTE];

                begin : rd_miss_loop
                    for(i = 0; i < NWAYS; i = i+1)
                    begin 
                        if(~valid[i][addr[`INDEX]] || (dirty[i][addr[`INDEX]] == 1'b1))
                        begin
                            data[i][addr[`INDEX]] <= mem_rd_blk;
                            tag[i][addr[`INDEX]] <= addr[`TAG];
                            dirty[i][addr[`INDEX]] <= 1'b0;
                            valid[i][addr[`INDEX]] <= 1'b1;

                            // update age registers
                            for(j = 0; j < NWAYS; j = j+1)
                                if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]) && valid[j][addr[`INDEX]])
                                    lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 2'b01;
                            lru[i][addr[`INDEX]] <= 2'b00;

                            disable rd_miss_loop;
                        end
                    end
                end
            end

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
