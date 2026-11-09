class instr_monitor extends uvm_monitor;
  `uvm_component_utils(instr_monitor)

  virtual instr_mem_if vif;
  uvm_analysis_port #(transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ...
  endfunction

  function void build_phase(uvm_phase phase);
    //Get vif from resource db
  endfunction

  task run_phase(uvm_phase phase);
    transaction tr;
    //wait for reset
    forever begin
      tr = new();
      ...
      ap.write(tr);
    end
  endtask
endclass


class instr_coverage extends uvm_subscriber #(transaction);
  `uvm_component_utils(instr_coverage)

  uvm_analysis_imp #(instruction, instr_coverage) imp;

  covergroup instr_fields_cg;
    coverpoint tr.opcode {
      bins add = {0};
      ...
    }
    coverpoint tr.reg_c;
  endgroup

  covergroup instr_order_cg;
  endgroup

  covergroup instr_gap_cg;
  endgroup

  ...

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void write(transaction tr);
    ...
    //Create a queue
    //Call sample of various cgs
    instr_fields_cg.sample();
    ...
  endfunction
endclass

class instr_env extends uvm_env;
  `uvm_component_utils(instr_env)

  instr_monitor mon;
  instr_coverage cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ...
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    mon.ap.connect(cov.imp);
  endfunction
endclass

class my_test extends uvm_test;

    my_env env;

    `uvm_component_utils(my_test)

    function new (string name = "my_test", uvm_component parent = null);
      super.new (name, parent);
    endfunction

    function void build_phase (uvm_phase phase);
         super.build_phase (phase);
         env  = my_env::type_id::create ("my_env", this);
      endfunction
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //DUT instance
  //Interface

  //Resource db population

  initial begin
    //Code from the instr generator part:
    gen = new();
    gen.generate_machine_code();
    gen.display_all();
    //Note you will merge the codes from the instr generator and the coverage collector properly. I'm just showing something basic.

    //Copy memory from gen to the instr mem
    //OR: Call $readmemh on that file you wrote using $writememh
    //Deassert reset
    run_test("my_test");
  end
endmodule
