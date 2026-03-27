module eth_swt_2x2(
    input clk,
    input reset,
    input [31:0] inDataA,
    input inSopA,
    input inEopA,
    input [31:0] inDataB,
    input inSopB,
    input inEopB,
    output [31:0] outDataA,
    output outSopA,
    output outEopA,
    output [31:0] outDataB,
    output outSopB,
    output outEopB,
    output portAStall,
    output portBStall
);

assign outDataA = inDataA;
assign outSopA  = inSopA;
assign outEopA  = inEopA;
assign outDataB = inDataB;
assign outSopB  = inSopB;
assign outEopB  = inEopB;
assign portAStall = 1'b0;
assign portBStall = 1'b0;

endmodule