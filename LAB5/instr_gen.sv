
//Add -ntb_opts uvm to the VCS command line

class instruction extends uvm_instruction;
  rand bit [] reg_a, reg_b, reg_c;
  rand bit [] opcode;
  rand bit [] mem_addr;
  ...

  constraint unique_regs {
  }

  constraint valid_opcode {
  }

  constraint illegal_opcode {
  }
  
  ...

  function void print_me();
  endfunction
endclass

class instruction_generator;
  instruction instr_list[];
  bit [31:0] machine_code_list[];

  function void generate_individual();
      ...
      assert(instr_list[i].randomize());
      ...
  endfunction

  function instruction generate_pairs();
    ...
    txn1.randomize() with { reg_a = 1; };
    txn2.randomize() with { reg_a = 1; };
  endfunction

  function void insert_gaps();
  endfunction

  function void generate_sequence();
  endfunction

  function void generate_machine_code();
  ...
  $writememh (...);
  ..
  endfunction

  function void display_all();
  endfunction
endclass

module testbench;
  instruction_generator gen;

  initial begin
    gen = new();
    gen.generate_machine_code();
    gen.display_all();

    //Copy memory from gen to the instr mem
    //OR: Call $readmemh on that file you wrote using $writememh
    //Deassert reset
  end
endmodule

