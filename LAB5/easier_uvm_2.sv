// Filename: easier_uvm_2.sv

//----------------------------------------------------------------------
//  Copyright (c) 2011 by Doulos Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//----------------------------------------------------------------------

// Version 1, 16-May-2011  - An extension of easier_uvm.sv

/*
Second UVM example to demonstrate further features beyond easier_uvm.sv

Configuration of an agent and a sequence using config databas
  uvm_config_db
  
The factory
  set_type_override
  set_inst_override

User-defined transaction behavior
  do_copy
  do_compare
  convert2string
  
Nested and layered sequences
  p_sequencer
  uvm_seq_item_pull_port
  
Passing request and response between sequencer and driver
  set_id_info
  get_response

Overriding sequence behavior
  pre_do
  mid_do
  post_do
  
Messaging and verbosity
  `uvm_info
  `uvm_error
*/

`include "uvm_macros.svh"

interface dut_if();

  // Example interface: put your pins and modports here

  logic clock, reset;
  logic cmd;
  logic [7:0] addr;
  logic [7:0] data;

endinterface: dut_if


module dut(dut_if _if);

  // Example DUT: instantiate your Design Under Test here
  
  import uvm_pkg::*;
  
  always @(posedge _if.clock)
  begin
    `uvm_info("ja", $sformatf("DUT received cmd=%b, addr=%d, data=%d",
                               _if.cmd, _if.addr, _if.data), UVM_NONE);
  end
  
  always @(negedge _if.cmd) // Read
      _if.data = $urandom_range(0, 255);
  
endmodule: dut


package my_pkg;

  // A sequence library is just a package containing a set of standalone sequences 
  // which you can start on any sequencer

  import uvm_pkg::*;

  class my_top_tx extends uvm_sequence_item;
  
    `uvm_object_utils(my_top_tx)
  
    rand int addr;
  
    constraint c_addr { addr >= 0; addr < 256; }
    
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    function string convert2string;
      return $sformatf("addr=%0d", addr);
    endfunction: convert2string
    
  endclass: my_top_tx


  class my_transaction extends uvm_sequence_item;
  
    `uvm_object_utils(my_transaction)
  
    rand bit cmd;
    rand int addr;
    rand int data;
  
    constraint c_addr { addr >= 0; addr < 256; }
    constraint c_data { data >= 0; data < 256; }
    
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    function string convert2string;
      return $sformatf("cmd=%b, addr=%0d, data=%0d", cmd, addr, data);
    endfunction: convert2string
    
    function void do_copy(uvm_object rhs);
      my_transaction tx;
      super.do_copy(rhs);  // Must start with super.do_copy
      $cast(tx, rhs);
      cmd  = tx.cmd;
      addr = tx.addr;
      data = tx.data;
    endfunction: do_copy
    
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
      // Use the comparer to store miscompare information and permit customization 
      my_transaction tx;
      bit status = 1;

      status &= super.do_compare(rhs, comparer);  // Must start with super.do_compare
      $cast(tx, rhs);

      // Call compare_field, compare_field_int, compare_field_real, compare_object, compare_string
      status &= comparer.compare_field("cmd",  cmd,  tx.cmd,  $bits(cmd));
      status &= comparer.compare_field("addr", addr, tx.addr, $bits(addr));
      status &= comparer.compare_field("data", data, tx.data, $bits(data));
  
      return status;
    endfunction: do_compare

  endclass: my_transaction
 
  
  typedef my_transaction my_req;
  typedef my_transaction my_rsp;

  typedef uvm_sequencer #(my_top_tx) my_top_seqr;

  
  class my_top_seq_config extends uvm_object;
    
    `uvm_object_utils(my_top_seq_config)
    
    rand bit set_count;
    rand int count;
  
    function new (string name = "");
      super.new(name);
    endfunction
    
    function string convert2string;
      return $sformatf("set_count=%b, count=%0d", set_count, count);
    endfunction

  endclass: my_top_seq_config
  
  
  class my_top_seq extends uvm_sequence #(my_top_tx);
  
    `uvm_object_utils(my_top_seq)
    `uvm_declare_p_sequencer(my_top_seqr)
  
    rand int count;
    
    constraint how_many { count inside {[4:10]}; }
    
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    task pre_start;
      my_top_seq_config config_h;
      // Reach out to sequencer to retrieve configuration information
      if ( uvm_config_db #(my_top_seq_config)::get(p_sequencer, "", "config", config_h) )
        if (config_h.set_count)
          count = config_h.count;
    endtask: pre_start

    task body;
      `uvm_info("ja", $sformatf("my_top_seq::body called with count = %d", count), UVM_HIGH);
      
      //starting_phase.raise_objection(this); // Still not working in UVM 1.1
      uvm_test_done.raise_objection(this);

      repeat(count)
      begin
        req = my_top_tx::type_id::create("req");
        start_item(req);
        assert( req.randomize() );
        finish_item(req);
      end

      //starting_phase.drop_objection(this); // Still not working in UVM 1.1
      uvm_test_done.drop_objection(this);
    endtask: body

  endclass: my_top_seq
  
  
  typedef class my_sequencer;
  

  class read_modify_write extends uvm_sequence #(my_req, my_rsp);
  
    `uvm_object_utils(read_modify_write)
    `uvm_declare_p_sequencer(my_sequencer)
    
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    task body;
      my_top_tx tx;
      int d;
      p_sequencer.seq_item_port.get(tx);
      
      // Variables req and rsp are inherited from uvm_sequence
      // Read
      req = my_req::type_id::create("req");
      start_item(req);
      req.cmd  = 0;
      req.addr = tx.addr;
      req.data = 0;
      finish_item(req);
      get_response(rsp);
      `uvm_info("ja", $sformatf("Response = %s", rsp.convert2string()), UVM_NONE)
      
      // Modify
      d = rsp.data;    // Grab modified data from request transaction
      ++d;
  
      // Write    
      start_item(req);
      req.cmd = 1;
      req.addr = tx.addr;
      req.data = d;
      finish_item(req);
      // No response for a write
    endtask: body

    /*   
    task pre_start;
      `uvm_info("ja", "pre_start called", UVM_HIGH)
    endtask: pre_start

    task post_start;
      `uvm_info("ja", "post_start called", UVM_HIGH)
    endtask: post_start

    // pre/post_body are not called when read_modify_write is started with uvm_do
    task pre_body;
      `uvm_info("ja", "pre_body called", UVM_HIGH)
    endtask: pre_body

    task post_body;
      `uvm_info("ja", "post_body called", UVM_HIGH)
    endtask: post_body
    */
  endclass: read_modify_write
  

  class seq_of_commands extends uvm_sequence #(my_req, my_rsp);
  
    `uvm_object_utils(seq_of_commands)
    `uvm_declare_p_sequencer(my_sequencer)
    
    function new (string name = "");
      super.new(name);
    endfunction: new

    task body;
      forever
      begin
        read_modify_write seq;
        seq = read_modify_write::type_id::create("seq");
        seq.start(p_sequencer, this); 
        //`uvm_do(seq)                 // Alternative using macros
      end
    endtask: body
    
    // The following call-backs are called each time the read_modify_write sequence is started
    /*
    task pre_do(bit is_item);
      `uvm_info("ja", "pre_do called", UVM_HIGH)
    endtask
    
    function void mid_do(uvm_sequence_item this_item);
      `uvm_info("ja", "mid_do called", UVM_HIGH)
    endfunction
    
    function void post_do(uvm_sequence_item this_item);
      `uvm_info("ja", "post_do called", UVM_HIGH)
    endfunction
   */
  endclass: seq_of_commands
  

  class my_sequencer extends uvm_sequencer #(my_req, my_rsp);
    `uvm_component_utils(my_sequencer)
    
    uvm_seq_item_pull_port #(my_top_tx) seq_item_port;
  
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seq_item_port = new("seq_item_port", this);
    endfunction

  endclass: my_sequencer


  class my_driver extends uvm_driver #(my_req, my_rsp);
  
    `uvm_component_utils(my_driver)

    virtual dut_if dut_vi;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'( uvm_config_db #(virtual dut_if)::get(this, "", "dut_vi", dut_vi) );
    endfunction
   
    task run_phase(uvm_phase phase);
      @(posedge dut_vi.clock);
      forever
      begin
        seq_item_port.get(req);
        phase.raise_objection(this);
           
        // Wiggle pins of DUT
        dut_vi.cmd  = req.cmd;
        dut_vi.addr = req.addr;
        if (req.cmd == 1) // Write
          dut_vi.data = req.data;
        @(posedge dut_vi.clock);
        if (req.cmd == 0) // Read
        begin
          rsp = my_rsp::type_id::create("rsp");
          rsp.set_id_info(req);
          rsp.data = dut_vi.data;
          seq_item_port.put(rsp);
        end          
        phase.drop_objection(this);
      end
    endtask

  endclass: my_driver


  class my_monitor extends uvm_monitor;
  
    `uvm_component_utils(my_monitor)

    uvm_analysis_port #(my_transaction) aport;
    
    virtual dut_if dut_vi;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      aport = new("aport", this);
      void'( uvm_config_db #(virtual dut_if)::get(this, "", "dut_vi", dut_vi) );
    endfunction
   
    task run_phase(uvm_phase phase);
      forever
      begin
        my_transaction tx;
        
        @(posedge dut_vi.clock);
        tx = my_transaction::type_id::create("tx");
        tx.cmd  = dut_vi.cmd;
        tx.addr = dut_vi.addr;
        tx.data = dut_vi.data;
        
        aport.write(tx);
      end
    endtask

  endclass: my_monitor


  class my_agent extends uvm_agent;

    `uvm_component_utils(my_agent)
    
    uvm_seq_item_pull_port #(my_top_tx) seq_item_port;
    uvm_analysis_port #(my_transaction) aport;
    
    // Configuration parameters
    bit    param1 = 0;
    int    param2 = 0;
    string param3;

    my_sequencer my_sequencer_h;
    my_driver    my_driver_h;
    my_monitor   my_monitor_h;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      begin
        uvm_active_passive_enum flag;
        if ( uvm_config_db #(uvm_active_passive_enum)::get(this, "", "is_active", flag) )
          is_active = flag;
        `uvm_info("ja", $sformatf("Agent is %s", flag ? "ACTIVE" : "PASSIVE"), UVM_HIGH)
      end
      seq_item_port = new("seq_item_port", this);
      aport         = new("aport", this);
      if (is_active)
      begin
        my_sequencer_h = my_sequencer::type_id::create("my_sequencer_h", this);
        my_driver_h    = my_driver   ::type_id::create("my_driver_h"   , this);
      end
      my_monitor_h   = my_monitor  ::type_id::create("my_monitor_h"  , this);
      
    endfunction
    
    function void connect_phase(uvm_phase phase);
      if (is_active)
      begin
        my_sequencer_h.seq_item_port.connect( seq_item_port );
        my_driver_h.   seq_item_port.connect( my_sequencer_h.seq_item_export );
      end
      my_monitor_h.          aport.connect( aport );
    endfunction
    
  endclass: my_agent
  
  
  class my_subscriber extends uvm_subscriber #(my_transaction);
  
    `uvm_component_utils(my_subscriber)
    
    bit cmd;
    int addr;
    int data;
        
    covergroup cover_bus;
      coverpoint cmd;
      coverpoint addr { 
        bins a[16] = {[0:255]};
      }
      coverpoint data {
        bins d[16] = {[0:255]};
      }
    endgroup: cover_bus
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
      cover_bus = new;  
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
    endfunction
    
    function void write(input my_transaction t);
      `uvm_info("ja", $sformatf("Subscriber received tx %s", t.convert2string()), UVM_NONE);
      cmd  = t.cmd;
      addr = t.addr;
      data = t.data;
      cover_bus.sample();
    endfunction: write

  endclass: my_subscriber
  
  
  class my_env extends uvm_env;

    `uvm_component_utils(my_env)
    
    UVM_FILE      file_h;
    my_top_seqr   my_top_seqr_h;
    my_agent      my_agent_h;
    my_subscriber my_subscriber_h;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      my_top_seqr_h   = my_top_seqr  ::type_id::create("my_top_seqr_h", this);
      my_agent_h      = my_agent     ::type_id::create("my_agent_h", this);
      my_subscriber_h = my_subscriber::type_id::create("my_subscriber_h", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      my_agent_h.        aport.connect( my_subscriber_h.analysis_export );
      my_agent_h.seq_item_port.connect( my_top_seqr_h.seq_item_export ); 
    endfunction
    
  endclass: my_env
  
  
  class my_test extends uvm_test;
  
    `uvm_component_utils(my_test)
    
    my_env my_env_h;   

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      my_env_h = my_env::type_id::create("my_env_h", this);
    endfunction
    
    task run_phase(uvm_phase phase);
      seq_of_commands seq;
      seq = seq_of_commands::type_id::create("seq");
      assert( seq.randomize() );
      seq.start( my_env_h.my_agent_h.my_sequencer_h );
      uvm_test_done.set_drain_time( this, 20ns );
    endtask
    
  endclass: my_test
  

  class alt_top_tx extends my_top_tx;
  
    // Extending a transaction by adding a constraint
     `uvm_object_utils(alt_top_tx)
  
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    constraint c_data_lt_addr { addr > 200; }
    
  endclass: alt_top_tx
  
  
  class alt_top_seq extends my_top_seq;
    
    // Extending a sequence by overriding mid/post_do
    `uvm_object_utils(alt_top_seq)
  
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    my_top_tx tx;
    int prev_addr = 0;
    
    function void mid_do(uvm_sequence_item this_item);
      $cast(tx, this_item);
      tx.addr = prev_addr + $urandom_range(1, 7);      
    endfunction
    
    function void post_do(uvm_sequence_item this_item);
      $cast(tx, this_item);
      prev_addr = tx.addr;
    endfunction

  endclass: alt_top_seq
  
  
  class alt_subscriber extends my_subscriber;

    // Extending a component by overriding write
    `uvm_component_utils(alt_subscriber)
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void write(input my_transaction t);
      super.write(t);
      begin
        // Trivial example to show copy() and compare()
        my_transaction expected;
        expected = my_transaction::type_id::create();
        expected.copy(t);
        if ( t.compare(expected))
          `uvm_info("ja", "Match with expected transaction", UVM_HIGH)
        else
          `uvm_error("ja", $sformatf("%s differs from %s", t.convert2string(), 
                                                           expected.convert2string()))
      end
    endfunction: write

  endclass: alt_subscriber
  
  
  class my_test_2 extends uvm_test;
  
    `uvm_component_utils(my_test_2)
    
    my_env my_env_h;   

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      begin
        // Setup the configuration object for a sequencer
        my_top_seq_config config_h = new;
        // Randomize configuration object
        assert( config_h.randomize() );
        // and/or set configuration parameters deterministically
        config_h.set_count = 1;
        config_h.count = 6;
        uvm_config_db #(my_top_seq_config)::set(this, "*", "config", config_h);

        // Configure the active/passive flag of an agent        
        uvm_config_db #(uvm_active_passive_enum)::set(this, "*.*my_agent*", "is_active", UVM_ACTIVE);

        // Setup factory overrides for a transaction, sequence, and component
        my_top_tx::type_id::set_type_override( alt_top_tx::get_type() );

        my_top_seq::type_id::set_type_override( alt_top_seq::get_type() );

        my_subscriber ::type_id::set_inst_override(
                        alt_subscriber::get_type(), "*.my_subscriber_h", this );

        my_env_h = my_env::type_id::create("my_env_h", this);
      end
    endfunction
    
    task run_phase(uvm_phase phase);
      seq_of_commands seq;
      my_top_seq         tseq;
      
      seq  = seq_of_commands::type_id::create("seq");
      assert( seq.randomize() );
      
      tseq = my_top_seq::type_id::create("tseq");
      assert( tseq.randomize() );
      
      uvm_test_done.set_drain_time( this, 20ns );
      fork
        seq.start( my_env_h.my_agent_h.my_sequencer_h );
        tseq.start( my_env_h.my_top_seqr_h );
      join_none
    endtask
    
  endclass: my_test_2
  
endpackage: my_pkg


module top;

  import uvm_pkg::*;
  import my_pkg::*;
  
  dut_if dut_if1 ();
  
  dut    dut1 ( ._if(dut_if1) );

  // Clock and reset generator
  initial
  begin
    dut_if1.clock = 0;
    forever #5 dut_if1.clock = ~dut_if1.clock;
  end

  initial
  begin
    dut_if1.reset = 1;
    repeat(3) @(negedge dut_if1.clock);
    dut_if1.reset = 0;
  end

  initial
  begin: blk
    uvm_config_db #(virtual dut_if)::set(null, "*", "dut_vi", dut_if1);

    uvm_top.enable_print_topology = 1;
    uvm_top.finish_on_completion  = 1;
    
    run_test();
  end

endmodule: top
