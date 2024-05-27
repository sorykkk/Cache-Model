module control_unit (

);

    // state parameters
    parameter IDLE    = 3'b000;
    parameter RD_HIT  = 3'b001;
    parameter RD_MISS = 3'b010;
    parameter WR_HIT  = 3'b011;
    parameter WR_MISS = 3'b100;
    parameter EVICT   = 3'b101;

    // state registers
    reg[2:0] state, next;

    //change states
    always @(posedge clk) begin 
        if(!rst_n) state <= IDLE;
        else state <= next;
    end

    //set next state
    always @(posedge clk) begin 
        next <= IDLE;
        case(state)
            IDLE:      begin 
                    
                    if(~rd_en && ~wr_en) next <= IDLE;
                    if(rd_en && hit) next <= RD_HIT;
                    if(rd_en && ~hit)  next <= RD_MISS;
                    if(wr_en && ~hit)  next <= WR_MISS;
                    if(wr_en && hit) next <= WR_HIT;
            end

            WR_MISS,
            RD_MISS: next <= EVICT;

            WR_HIT,
            RD_HIT: next <= IDLE;

            EVICT: next <= IDLE;

        endcase
    end

    //trigger signals based on next state
    always begin 

        case(next)
            IDLE: begin 
                    mem_wr_en <= 0;
                    hit = ((valid[0][addr[`INDEX]] && (tag[0][addr[`INDEX]] == addr[`TAG]))
                         || (valid[1][addr[`INDEX]] && (tag[1][addr][`INDEX] == addr[`TAG]))
                         || (valid[2][addr[`INDEX]] && (tag[2][addr[`INDEX]] == addr[`TAG]))
                         || (valid[3][addr[`INDEX]] && (tag[3][addr[`INDEX]] == addr[`TAG])));
            end

            RD_HIT: begin 
                

            end

        endcase

    end



endmodule