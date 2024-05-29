`include "macros.v"
//treb de definit aici operatiile pe memorie
//Un aray de byte-uri
module mem #(
    parameter DEPTH    = (1<<20),   // 1MB
    parameter WIDTH    = `BYTE,
    parameter PA_WIDTH = `PA_WIDTH,
    parameter INIT     = 0          // if 1, resets all the memory
)
(
    input  wire                clk,

    input  wire [PA_WIDTH-1:0] addr,

    input  wire                rd_en,
    input  wire                wr_en,

    input  wire [WIDTH-1:0]    wr_data,
    output wire [WIDTH-1:0]    rd_data
);

    reg [WIDTH-1:0] MM [0:DEPTH-1];
    // aici putem sa le hardcodam, sau sa facem ca ram

    integer i;
    initial begin 
        if(INIT)
            for(i = 0; i < DEPTH; i = i+1)
                MM[i] = {WIDTH{1'b0}};
    end

    // read from Main Memory
    always @(posedge clk)
        if(rd_en)
            rd_data <= MM[addr];

    // write to main Memory
    always @(posedge clk)
        if(wr_en)
            MM[addr] <= wr_data;

endmodule