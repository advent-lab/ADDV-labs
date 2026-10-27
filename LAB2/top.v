////////////////////////////////////////////////////////////////////////////
// ========================================================================
// This file has the following module implementations:
// 1. top
// 2. mips
// 3. dmem
// 4. imem
// =========================================================================
////////////////////////////////////////////////////////////////////////////
// Top Module 
//  - This module connects the MIPS processor to instruction and data memory
////////////////////////////////////////////////////////////////////////////
module top (
    input clk, reset,
    output [31:0] writedata, dataadr,
    output memwrite
);
    wire [31:0] pc, instr, readdata;

    // instantiate processor and memories
    mips mips (clk, reset, pc, instr, memwrite, dataadr, writedata, readdata);
    imem imem (pc[7:2], instr);
    dmem dmem (clk, memwrite, dataadr, writedata, readdata);
endmodule


//////////////////////////////////////////////////////////////////////
// Single-cycle MIPS Processor Module
//////////////////////////////////////////////////////////////////////
module mips (
    input           clk, reset,
    output  [31:0]  pc,
    input   [31:0]  instr,
    output          memwrite,
    output  [31:0]  aluout, writedata,
    input   [31:0]  readdata
);

    wire memtoreg, branch, alusrc, regdst, regwrite, jump;
    wire [2:0] alucontrol;

    controller c(instr[31:26], instr[5:0], zero, memtoreg, memwrite, pcsrc, alusrc, regdst, regwrite, jump, alucontrol);

    datapath dp(clk, reset, memtoreg, pcsrc, alusrc, regdst, regwrite, jump,alucontrol, zero, pc, instr, aluout, writedata, readdata);
endmodule


//////////////////////////////////////////////////////////////////////
// Data Memory Module
//////////////////////////////////////////////////////////////////////
module dmem (
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);
    reg [31:0] RAM[63:0];

    assign rd = RAM[a[31:2]]; // word aligned
    
    always @ (posedge clk)
        if (we)
            RAM[a[31:2]] <= wd;
endmodule


//////////////////////////////////////////////////////////////////////
// Instruction Memory Module
// - Note that it uses $readmemh to load imem from memfile.dat
// - This has a capacity of 64 words, If the memfile.dat has fewer than 64 words,
//   you will get a warning that some addresses are not initialized or the file has not enough words
//   you can ignre this warning
//////////////////////////////////////////////////////////////////////
module imem (
    input [5:0] a,
    output [31:0] rd
);
    reg [31:0] RAM[63:0];
    
    initial begin
        $readmemh("memfile.dat",RAM);
    end
    assign rd = RAM[a]; // word aligned
endmodule