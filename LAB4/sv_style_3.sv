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
/////////////////////
interface dut_if(input clk);

    logic [7:0] a;
    logic [7:0] b;
    logic [7:0] c;

endinterface

//////////////////////
//Transaction
/////////////////////
class transaction;
    
    bit [7:0] a;
    bit [7:0] b;
    bit [7:0] c;

    function new();
    endfunction

endclass

//////////////////////
//Monitor
/////////////////////
class monitor;

    virtual dut_if dut_vif;
    transaction txn;
    transaction txn_queue[$];

    function new(virtual dut_if dut_vif);
        this.dut_vif = dut_vif;
    endfunction

    task run();
        forever begin
            @(posedge dut_vif.clk);
            txn = new();
            txn.a = dut_vif.a;
            txn.b = dut_vif.b;
            //$display("Time = %0t, a = %0d, b = %0d", $time, txn.a, txn.b);

            @(negedge dut_vif.clk);
            txn.c = dut_vif.c;
            //$display("Time = %0t, c = %0d", $time, txn.c);
            txn_queue.push_back(txn);
        end
    endtask

    task get_transaction(ref transaction txn);
        wait (txn_queue.size() > 0);
        txn = txn_queue.pop_front();
    endtask

endclass

//////////////////////
//Scoreboard
/////////////////////
class scoreboard;

    transaction txn;
    int expected_result;
    monitor mon;

    function new(monitor mon);
        this.mon = mon;
    endfunction 

    task run();
        forever begin
            txn = new();
            mon.get_transaction(txn);
            //reference model
            expected_result = txn.a + txn.b;
            if (expected_result != txn.c) 
                $error("Failed. Time = %0t, Expected = %0d, Observed = %0d", $time, expected_result, txn.c);
            else 
                $display("Passed. Time = %0t, Expected = %0d, Observed = %0d", $time, expected_result, txn.c);
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
    monitor mon;
    scoreboard sb;
    
    initial begin
        mon = new(dut_if_inst);
        sb = new(mon);
        fork  //Both infinite loops
            mon.run(); 
            sb.run();
        join
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