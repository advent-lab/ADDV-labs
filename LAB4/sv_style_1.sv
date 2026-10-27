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
//Interface
////////////////////
interface dut_if(input clk);

    logic [7:0] a;
    logic [7:0] b;
    logic [7:0] c;

endinterface

//////////////////////
//Scoreboard
////////////////////
class scoreboard;

    virtual dut_if dut_vif;
    int a,b,c;
    int expected_result;

    function new(virtual dut_if dut_vif);
        this.dut_vif = dut_vif;
    endfunction

    task run();
        forever begin
            @(posedge dut_vif.clk); 
            a = dut_vif.a;
            b = dut_vif.b;
            expected_result = a + b; //+ sign is basically the golden model

            @(negedge dut_vif.clk);
            c = dut_vif.c;
            if (expected_result != c) 
                $error("Failed. Time = %0t, Expected = %0d, Observed = %0d", $time, expected_result, c);
            else 
                $display("Passed. Time = %0t, Expected = %0d, Observed = %0d", $time, expected_result, c);
        end
    endtask

endclass

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

    dut_if dut_if_inst(clk);

    ripple_carry_adder_8bit dut_inst(.clk(clk), .a(dut_if_inst.a), .b(dut_if_inst.b), .c(dut_if_inst.c));

    assign dut_if_inst.a = a;
    assign dut_if_inst.b = b;

    //Create testbench components
    scoreboard sb; //declaration, not instantiation
    
    initial begin
        sb = new(dut_if_inst); //construction
        sb.run();
    end

    //Stimulus
    initial begin
        #10;
        @(negedge clk);
        a = 15;
        b = 25;
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