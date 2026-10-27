//////////////////////////////////////////////////////////////////////
// ===================================================================
// This file has the following module implementations:
// 1. datapath
// 2. regfile
// 3. alu
// 4. adder
// 5. mux2
// 6. sl2
// 7. signext
// 8. flopr
// ===================================================================
//////////////////////////////////////////////////////////////////////
// Datapath module
//////////////////////////////////////////////////////////////////////
module datapath (
    input clk, reset,
    input memtoreg, pcsrc,
    input alusrc, regdst,
    input regwrite, jump,
    input [2:0] alucontrol,
    output zero,
    output [31:0] pc,
    input [31:0] instr,
    output [31:0] aluout, writedata,
    input [31:0] readdata
);

    wire [4:0] writereg;
    wire [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
    wire [31:0] signimm, signimmsh;
    wire [31:0] srca, srcb;
    wire [31:0] result;
    
    // next PC logic
    flopr #(32) pcreg(clk, reset, pcnext, pc);
    adder pcadd1 (pc, 32'b100, pcplus4);
    sl2 immsh(signimm, signimmsh);
    adder pcadd2(pcplus4, signimmsh, pcbranch);
    mux2 #(32) pcbrmux(pcplus4, pcbranch, pcsrc, pcnextbr);
    mux2 #(32) pcmux(pcnextbr, {pcplus4[31:28], instr[25:0], 2'b00}, jump, pcnext);

    // register file logic
    regfile rf(clk, regwrite, instr[25:21], instr[20:16], writereg, result, srca, writedata);
    mux2 #(5) wrmux(instr[20:16], instr[15:11], regdst, writereg);
    mux2 #(32) resmux(aluout, readdata, memtoreg, result);
    signext se(instr[15:0], signimm);
    
    // ALU logic
    mux2 #(32) srcbmux(writedata, signimm, alusrc, srcb);
    alu alu(srca, srcb, alucontrol, aluout, zero);
endmodule


//////////////////////////////////////////////////////////////////////
// Register File Module
//////////////////////////////////////////////////////////////////////
module regfile (
    input clk,
    input we3,
    input [4:0] ra1, ra2, wa3,
    input [31:0] wd3,
    output [31:0] rd1, rd2
);
    
    reg [31:0] rf[31:0];
    // three ported register file
    // read two ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    always @ (posedge clk)
        if (we3) rf[wa3] <= wd3;

    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

//////////////////////////////////////////////////////////////////////
// ALU Module
////////////////////////////////////////////////////////////////////// 
module alu(
    input [31:0] a,          // First operand
    input [31:0] b,          // Second operand
    input [2:0] control,     // ALU control signal
    output reg [31:0] result, // ALU result
    output zero              // Zero flag
);

    // Define ALU operations based on control signal
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;
    
    // Calculate result based on control input
    always @(*) begin
        case(control)
            ALU_AND: result = a & b;                     // AND
            ALU_OR:  result = a | b;                     // OR
            ALU_ADD: result = a + b;                     // ADD
            ALU_SUB: result = a - b;                     // SUB
            ALU_SLT: result = ($signed(a) < $signed(b)); // Set Less Than (signed)
            default: result = 32'bx;                     // Undefined operation
        endcase
    end
    
    // Set zero flag when result is 0
    assign zero = (result == 32'b0);
    
endmodule


//////////////////////////////////////////////////////////////////////
// Adder Module
//////////////////////////////////////////////////////////////////////
module adder (
    input [31:0] a, b,
    output [31:0] y
);
    assign y = a + b;
endmodule


//////////////////////////////////////////////////////////////////////
// 2-to-1 Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux2 # (parameter WIDTH = 8) (
    input [WIDTH-1:0] d0, d1,
    input s,
    output [WIDTH-1:0] y
);
    assign y = s ? d1 : d0;
endmodule


//////////////////////////////////////////////////////////////////////
// Shift Left by 2 Module
//////////////////////////////////////////////////////////////////////
module sl2 (
    input [31:0] a,
    output [31:0] y
);
    // shift left by 2
    assign y = {a[29:0], 2'b00};
endmodule


//////////////////////////////////////////////////////////////////////
// Sign Extension Module
//////////////////////////////////////////////////////////////////////
module signext (
    input [15:0] a,
    output [31:0] y
);
    assign y = {{16{a[15]}}, a};
endmodule


//////////////////////////////////////////////////////////////////////
// Flop Register Module
//////////////////////////////////////////////////////////////////////
module flopr # (parameter WIDTH = 8)(
    input clk, reset,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @ (posedge clk, posedge reset)
        if (reset) q <= 0;
        else q <= d;
endmodule