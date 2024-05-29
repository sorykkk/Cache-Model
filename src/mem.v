`include "macros.v"
//treb de definit aici operatiile pe memorie
//Un aray de byte-uri
module mem #(
    parameter SIZE = (1<<20); // 1MB
)
(

);

    reg [`BYTE-1:0] MM [:SIZE-1];

endmodule