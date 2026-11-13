`include "serialalu_pkg.sv"
`include "serialalu.v"
`include "serialalu_if.sv"

module serialalu_tb_top;
	import uvm_pkg::*;

	//Interface declaration
	serialalu_if vif();

	//Connects the Interface to the DUT
	serialalu dut(vif.sig_clock,
			vif.sig_en_i,
			vif.sig_ina,
			vif.sig_inb,
			vif.sig_en_o,
			vif.sig_out);

	initial begin
		//Registers the Interface in the configuration block so that other
		//blocks can use it
		uvm_resource_db#(virtual serialalu_if)::set
			(.scope("ifs"), .name("serialalu_if"), .val(vif));
		uvm_config_db#(int)::set(null, "*", "recording_detail", UVM_FULL);

		//Executes the test
		run_test();
	end

	//Variable initialization
	initial begin
		vif.sig_clock <= 1'b1;
	end

	//Clock generation
	always
		#5 vif.sig_clock = ~vif.sig_clock;

	initial begin
		$fsdbDumpfile("novas.fsdb");
		$fsdbDumpvars(0, serialalu_tb_top);
	end

endmodule
