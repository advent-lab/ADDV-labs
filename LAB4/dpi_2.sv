// Import the C function using DPI
import "DPI-C" function int add(int a, int b);

`timescale 1ns/1ns

//////////////////////
//DUT
/////////////////////
module half_adder (
    input  logic a,
    input  logic b,
    output logic sum,
    output logic carry
);
    assign sum   = a ^ b;
    assign carry = a & b;
endmodule


module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module ripple_carry_adder_8bit (
    input clk,
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] c    
);

    logic [8:0] carry;
	logic [7:0] sum;	

    // No carry-in for bit 0
    assign carry[0] = 1'b0;

    half_adder HA0 (
        .a     (a[0]),
        .b     (b[0]),
        .sum   (sum[0]),
        .carry (carry[1])
    );

    // Bits 1 through 7
    generate
        for (genvar i = 1; i < 8; i++) begin : gen_adders
            full_adder FA (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate
   

    always_ff @(posedge clk) begin
        c <= sum;
    end

endmodule

//////////////////////
//Checker
/////////////////////
module checker(input clk, input logic [7:0] a, input logic [7:0] b, input logic[7:0] c);
        integer expected_result;
        always begin
            @(posedge clk);
            expected_result = add(a, b);
            $display("Result from C function: %0d", expected_result);
            @(negedge clk);
            if (expected_result != c) $error("Failed");
            else $display("Pass");
        end

endmodule

//////////////////////
//Testbench
/////////////////////
module testbench;

    logic [7:0] a;
    logic [7:0] b;
    logic [7:0] c;
    integer result;

    logic clk = 0;

    always begin
        #10 clk = ~clk;
    end

    ripple_carry_adder_8bit dut_inst(.clk(clk), .a(a), .b(b), .c(c));
    checker checker_inst(.clk(clk), .a(a), .b(b), .c(c));

    initial begin
        #10;
        @(negedge clk);
        a = 15;
        b = 25;
        #10;
        @(negedge clk);
        #10;
        #10;
        @(negedge clk);
        a = 10;
        b = 13;
        @(negedge clk);
        #10;
        $finish;
    end

endmodule



//vcs -sverilog dpi_class_example.sv dpi_add.c -o dpi_class_sim