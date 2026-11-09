class serialalu_transaction extends uvm_sequence_item;
	rand bit[1:0] ina;
	rand bit[1:0] inb;
	bit[2:0] out;

	function new(string name = "");
		super.new(name);
	endfunction: new

	`uvm_object_utils_begin(serialalu_transaction)
		`uvm_field_int(ina, UVM_ALL_ON)
		`uvm_field_int(inb, UVM_ALL_ON)
		`uvm_field_int(out, UVM_ALL_ON)
	`uvm_object_utils_end
endclass: serialalu_transaction

class serialalu_sequence extends uvm_sequence#(serialalu_transaction);
	`uvm_object_utils(serialalu_sequence)

	function new(string name = "");
		super.new(name);
	endfunction: new

	task body();
		serialalu_transaction sa_tx;
		
		repeat(15) begin
		sa_tx = serialalu_transaction::type_id::create(.name("sa_tx"), .contxt(get_full_name()));

		start_item(sa_tx);
		assert(sa_tx.randomize());
		//`uvm_info("sa_sequence", sa_tx.sprint(), UVM_LOW);
		finish_item(sa_tx);
		end
	endtask: body
endclass: serialalu_sequence

typedef uvm_sequencer#(serialalu_transaction) serialalu_sequencer;
