`include "macros.v"

module control_unit #(
    parameter BYTE      = `BYTE,
    parameter SIZE      = `SIZE,
    parameter NWAYS     = `NWAYS,
    parameter NSETS     = `NSETS,
    parameter BLK_SIZE  = `BLK_SIZE,
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
    input  wire                  rd_en, wr_en, hit,

    input  wire                  valid [0:NWAYS-1][0:NSETS-1],
    input  wire                  dirty [0:NWAYS-1][0:NSETS-1],
    input  wire [1:0]            lru   [0:NWAYS-1][0:NSETS-1],
    input  wire [TAG_WIDTH-1:0]  tag   [0:NWAYS-1][0:NSETS-1],
    input  wire [BLOCK_SIZE-1:0] data  [0:NWAYS-1][0:NSETS-1],

    input  wire [MEM_WIDTH-1:0]  mem_rd_data,

    output wire [WRD_WIDTH-1:0]  word_out,
    output wire [BYTE-1:0]       byte_out
);

    // state parameters
    localparam IDLE    = 3'b000;
    localparam RD_HIT  = 3'b001;
    localparam RD_MISS = 3'b010;
    localparam WR_HIT  = 3'b011;
    localparam WR_MISS = 3'b100;
    localparam EVICT   = 3'b101;

    // state registers
    reg[2:0] state, next;

    //change states
    always @(posedge clk) begin 
        if(!rst_n) state <= IDLE;
        else       state <= next;
    end

    // set next state
    always @(posedge clk) begin 
        next <= IDLE;
        case(state)
            IDLE: begin   
                if(~rd_en && ~wr_en) next <= IDLE;
                if(rd_en && hit)     next <= RD_HIT;
                if(rd_en && ~hit)    next <= RD_MISS;
                if(wr_en && ~hit)    next <= WR_MISS;
                if(wr_en && hit)     next <= WR_HIT;
            end

            WR_MISS,
            RD_MISS:                 next <= EVICT;

            WR_HIT,
            RD_HIT:                  next <= IDLE;

            EVICT:                   next <= IDLE;

        endcase
    end

    // trigger signals based on next state
    always begin 

        case(next)
            IDLE: begin 

                    mem_wr_en <= 0;
                    hit = ((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                         ||(valid[1][addr[`INDEX]] && (tag[1][addr[`INDEX]] == addr[`TAG]))
                         ||(valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                         ||(valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));
            
            end

            RD_HIT: begin 

                integer i;
                for(i = 0; i < NWAYS; i = i+1) begin 
                    //i_th way
                    if(valid[i][addr[`INDEX]] && (tag[i][addr[`INDEX]] == addr[`TAG])) begin
                        word_out = data[i][addr[`INDEX]][addr[`BOFFSET]]
                        byte_out = word_out[`WOFFSET];
                    end
                end
                
            end

            RD_MISS: begin 
                
                if(~valid[0][addr[`INDEX]]) begin 
                    
                end

            end

            WR_HIT : begin 

            end

            WR_MISS : begin 

            end

        endcase

    end



endmodule