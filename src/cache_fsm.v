`include "macros.v"

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
    output reg [PA_WIDTH-1:0]    mem_wr_addr,
    output reg [BLK_WIDTH]       mem_wr_blk,  

    output reg                   hit
    output reg [WRD_WIDTH-1:0]   word_out,
    output reg [BYTE-1:0]        byte_out,
);

    // state parameters
    localparam IDLE       = 3'b000;
    localparam RD_HIT     = 3'b001;
    localparam RD_MISS    = 3'b010;
    localparam WR_HIT     = 3'b011;
    localparam WR_MISS    = 3'b100;
    localparam RD_EVICT   = 3'b101;
    localparam WR_EVICT   = 3'b110;

    integer i;

    assign hit = ((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                ||(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG]))
                ||(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                ||(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));

    // state registers
    reg[2:0] state, next;

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
                else if(rd_en && ~hit) next = RD_EVICT;
                else if(wr_en && ~hit) next = WR_EVICT;
            end

            WR_EVICT :                 next = WR_MISS;
            RD_EVICT :                 next = RD_MISS;

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
            end

            RD_HIT: begin 
                for(i = 0; i < NWAYS; i = i+1) 
                begin 
                    //i_th way
                    if(valid[i][addr[`INDEX]] && (tag[i][addr[`INDEX]] == addr[`TAG])) 
                    begin
                        word_out = data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                        byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                        // update age registers
                        for(j = 0; j < NWAYS; j = j+1)
                            if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]))
                                lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 1;
                        lru[i][addr[`INDEX]] <= 2'b00;
                        
                        disable  
                    end
                end  
            end

            WR_HIT : begin 
                // write-back
                for(i = 0; i < NWAYS; i = i+1) 
                begin 
                    // i_th way
                    if(valid[i][addr[`INDEX]] && (tag[i][addr[`INDEX]] == addr[`TAG])) 
                    begin
                        // for store instr there is no output/byte word
                        word_out = {WRD_WIDTH{1'bz}};
                        byte_out = {BYTE{1'bz}};
                        // mark as dirty block
                        dirty[i][addr[`INDEX]] <= 1'b1;
                        // overwrite data info from cache's block
                        data[i][addr[`INDEX]][(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH] <= data_wr;

                        // update age registers
                        for(j = 0; j < NWAYS; j = j+1)
                            if((i!=j) && (lru[j][addr[`INDEX]] <= lru[i][addr[`INDEX]]))
                                lru[j][addr[`INDEX]] <= lru[j][addr[`INDEX]] + 1;
                        lru[i][addr[`INDEX]] <= 2'b00;
                        
                        disable  
                    end
                end
            end

            RD_EVICT : begin 
                for (i = 0; i < NWAYS; i = i + 1) 
                begin 
                    if (~valid[i][addr[`INDEX]]) 
                    begin 
                        data[i][addr[`INDEX]] <= mem_rd_blk;
                        tag[i][addr[`INDEX]] <= addr[`TAG];
                        dirty[i][addr[`INDEX]] <= 1'b0;
                        valid[i][addr[`INDEX]] <= 1'b1;
                        disable;
                    end

                    else if((lru[i][addr[`INDEX]] == 2'b11) && (dirty[i][addr[`INDEX]] == 1'b1)) 
                    begin 
                        mem_wr_addr <= addr;
                        mem_wr_en <= 1'b1;
                        mem_wr_blk <= data[addr[`INDEX]];
                        disable;
                    end
                end
            end

            WR_EVICT : begin 

                for (i = 0; i < NWAYS; i = i + 1) 
                begin 
                    if (~valid[i][addr[`INDEX]]) 
                    begin 
                        data[i][addr[`INDEX]] <= mem_rd_blk;
                        tag[i][addr[`INDEX]] <= addr[`TAG];
                        dirty[i][addr[`INDEX]] <= 1'b0;
                        valid[i][addr[`INDEX]] <= 1'b1;
                        disable;
                    end
                end

            end

            //aici e pizda

            //AICI TREB DE SCHIMBAT TOT
            RD_MISS: begin 

                for (i = 0; i < NWAYS; i = i + 1) 
                begin 
                    if (~valid[i][addr[`INDEX]]) 
                    begin 
                        word_out = mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                        byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                        data[i][addr[`INDEX]] <= mem_rd_blk;
                        tag[i][addr[`INDEX]] <= addr[`TAG];
                        dirty[i][addr[`INDEX]] <= 1'b0;
                        valid[i][addr[`INDEX]] <= 1'b1;
                        disable;
                    end
                end


                // for(i = 0; i < NWAYS; i = i + 1) 
                // begin 
                //     if (lru[i][addr[`INDEX]] == 2'b11) 
                //     begin 
                //         word_out = mem_rd_blk[(addr[`BOFFSET]*WRD_WIDTH)+:WRD_WIDTH];
                //         byte_out = word_out[(addr[`WOFFSET]*BYTE) +: BYTE];

                //         data[i][addr[`INDEX]] <= mem_rd_blk;
                //         tag[i][addr[`INDEX]] <= addr[`TAG];
                //         dirty[i][addr[`INDEX]] <= 1'b0;
                //         valid[i][addr[`INDEX]] <= 1'b1;
                //         disable;
                //     end
                // end
            end

            WR_MISS : begin 

                for (i = 0; i < NWAYS; i = i + 1) 
                begin 
                    if (~valid[i][addr[`INDEX]]) 
                    begin 
                        data[i][addr[`INDEX]] <= mem_rd_blk;
                        tag[i][addr[`INDEX]] <= addr[`TAG];
                        dirty[i][addr[`INDEX]] <= 1'b0;
                        valid[i][addr[`INDEX]] <= 1'b1;
                        disable;
                    end
                end


                for(i = 0; i < NWAYS; i = i+1)
                begin 
                    if(lru[i][addr[`INDEX]] == 2'b11)
                    begin 
                        word_out <= {WRD_WIDTH{1'bz}};
                        byte_out <= {BYTE{1'bz}};

                        data[i][addr[`INDEX]] <= mem_rd_blk;
                        tag[i][addr[`INDEX]] <= addr[`TAG];
                        dirty[i][addr[`INDEX]] <= 1'b1;
                        valid[i][addr[`INDEX]] <= 1'b1;
                        disable;
                    end
                end
            end
        endcase
    end

endmodule