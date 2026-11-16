// Filename: easier_uvm.sv

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

// Version 2, 08-Mar-2011  - Updated to UVM 1.0 (from UVM-EA)
// Version 3, 03-May-2011  - Updated to UVM 1.1

/*
UVM example that follows the "Easier UVM" coding guidelines

Demonstrates new features of UVM 1.0 (similar to OVM 2.1.1, but the UVM variants are shown here) 

Objection mechanism:
   raise_objection
   drop_objection
   set_drain_time

Callbacks:
   uvm_callback
   uvm_callbacks #(T, CB)
   `uvm_register_cb
   `uvm_do_callbacks
   uvm_callbacks #(T, CB)::add
   
Report catcher:
   uvm_report_catcher
   uvm_report_cb::add
   
Setting virtual interface using config database
   uvm_config_db
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
  
endmodule: dut


package my_seq_library;

  // A sequence library is just a package containing a set of standalone sequences 
  // which you can start on any sequencer

  import uvm_pkg::*;

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
    
    // A full-blown transaction class will overload do_copy and do_compare methods,
    // but they are unnecessary for this simple example
    /*
    function void do_copy(uvm_object rhs);
      my_transaction rhs_;
      super.do_copy(rhs);  // Must start with super.do_copy
      $cast(rhs_, rhs);
      cmd  = rhs_.cmd;
      addr = rhs_.addr;
      data = rhs_.data;
    endfunction: do_copy
    
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
      // Use the comparer to store miscompare information and permit customization 
      my_transaction rhs_;
      bit status = 1;

      status &= super.do_compare(rhs, comparer);  // Must start with super.do_compare
      $cast(rhs_, rhs);

      // Call compare_field, compare_field_int, compare_field_real, compare_object, compare_string
      status &= comparer.compare_field("cmd",  cmd,  rhs_.cmd,  $bits(cmd));
      status &= comparer.compare_field("addr", addr, rhs_.addr, $bits(addr));
      status &= comparer.compare_field("data", data, rhs_.data, $bits(data));
  
      return(status);
    endfunction: do_compare
    */
  endclass: my_transaction


  class read_modify_write extends uvm_sequence #(my_transaction);
  
    `uvm_object_utils(read_modify_write)
    
    function new (string name = "");
      super.new(name);
    endfunction: new
    
    task body;
      my_transaction tx;
      int a;
      int d;

      tx = my_transaction::type_id::create("tx");
      start_item(tx);
      assert( tx.randomize() with { cmd == 0; } );
      finish_item(tx);

      a = tx.addr;      
      d = tx.data;
      ++d;

      tx = my_transaction::type_id::create("tx");
      start_item(tx);
      assert( tx.randomize() with { cmd == 1; addr == a; data == d; } );
      finish_item(tx);
    endtask: body
   
    task pre_body;
      //starting_phase.raise_objection(this); // Still not working in UVM 1.1
      uvm_test_done.raise_objection(this);
    endtask: pre_body

    task post_body;
      //starting_phase.drop_objection(this); // Still not working in UVM 1.1
      uvm_test_done.drop_objection(this);
    endtask: post_body

  endclass: read_modify_write
  

  class seq_of_commands extends uvm_sequence #(my_transaction);
  
    `uvm_object_utils(seq_of_commands)
    `uvm_declare_p_sequencer(uvm_sequencer #(my_transaction))
    
    rand int n;
    
    constraint how_many { n inside {[4:6]}; }
    
    function new (string name = "");
      super.new(name);
    endfunction: new
    

    task body;
      repeat(n)
      begin
        read_modify_write seq;
        seq = read_modify_write::type_id::create("seq");
        seq.start(p_sequencer, this); 
        //`uvm_do(seq)                 // Alternative using macros
      end
    endtask: body
   
    task pre_body;
      uvm_test_done.raise_objection(this);
    endtask: pre_body

    task post_body;
      uvm_test_done.drop_objection(this);
    endtask: post_body

  endclass: seq_of_commands
  
endpackage: my_seq_library


package my_pkg;

  import uvm_pkg::*;
  import my_seq_library::*;


  typedef uvm_sequencer #(my_transaction) my_sequencer;

  typedef class my_driver;
  typedef class my_cb_interface;
  typedef uvm_callbacks #( my_driver, my_cb_interface ) my_driver_cb_t;

  virtual class my_cb_interface extends uvm_callback;

    virtual task modify( my_driver driver, my_transaction tx );
      `uvm_info( "CB", "from my_cb_interface::modify()" , UVM_NONE);
    endtask

    function new (string name = "");
      super.new(name);
    endfunction: new

  endclass: my_cb_interface


  class my_driver extends uvm_driver #(my_transaction);
  
    `uvm_component_utils(my_driver)

    virtual dut_if dut_vi;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      begin
        void'( uvm_config_db #(virtual dut_if)::get(this, "", "dut_vi", dut_vi) );
      end
    endfunction
   
    task run_phase(uvm_phase phase);
      forever
      begin
        my_transaction tx;
        
        uvm_test_done.raise_objection(this);
        @(posedge dut_vi.clock);
        uvm_test_done.drop_objection(this);

        seq_item_port.get(tx);
        
        // Callback
        call_modify(tx);

        // Wiggle pins of DUT
        dut_vi.cmd  = tx.cmd;
        dut_vi.addr = tx.addr;
        dut_vi.data = tx.data;
      end
    endtask

    `uvm_register_cb(my_driver, my_cb_interface)
    
    task call_modify( my_transaction tx );
     `uvm_do_callbacks( my_driver, my_cb_interface, modify( this, tx ) )
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
      begin
        void'( uvm_config_db #(virtual dut_if)::get(this, "", "dut_vi", dut_vi) );
      end
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
    
    uvm_analysis_port #(my_transaction) aport;

    my_sequencer my_sequencer_h;
    my_driver    my_driver_h;
    my_monitor   my_monitor_h;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      aport = new("aport", this);
      my_sequencer_h = my_sequencer::type_id::create("my_sequencer_h", this);
      my_driver_h    = my_driver   ::type_id::create("my_driver_h"   , this);
      my_monitor_h   = my_monitor  ::type_id::create("my_monitor_h"  , this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      my_driver_h.seq_item_port.connect( my_sequencer_h.seq_item_export );
      my_monitor_h.       aport.connect( aport );
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
    
    function void write(my_transaction t);
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
    my_agent      my_agent_h;
    my_subscriber my_subscriber_h;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      my_agent_h      = my_agent     ::type_id::create("my_agent_h", this);
      my_subscriber_h = my_subscriber::type_id::create("my_subscriber_h", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      my_agent_h.aport.connect( my_subscriber_h.analysis_export );
    endfunction
    
  endclass: my_env
  
  
  class my_cb extends my_cb_interface;

    function new (string name = "");
      super.new(name);
    endfunction: new

    virtual task modify( my_driver driver, my_transaction tx );
      `uvm_info( "CB", "from my_cb::modify()", UVM_NONE);
      // Would modify transaction here
    endtask

  endclass

   
  class my_report_catcher extends uvm_report_catcher; 
  
    function new (string name = "");
      super.new(name);
    endfunction: new

    function action_e catch; 
      // Promote info to warning
      if (get_severity() == UVM_INFO && get_id() == "CB") 
        set_severity(UVM_WARNING); 
      return THROW; 
    endfunction 

  endclass
   

  class my_test extends uvm_test;
  
    `uvm_component_utils(my_test)
    
    my_env my_env_h;   

    my_cb             my_cb_h;
    my_report_catcher catcher_h; 

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      my_env_h = my_env::type_id::create("my_env_h", this);
    endfunction
    
    function void start_of_simulation_phase(uvm_phase phase);
      my_driver d;
      $cast(d, uvm_top.find("*.my_driver_h"));
      my_cb_h = new("my_cb_h");
      my_driver_cb_t::add(d, my_cb_h);
      
      catcher_h = new("catcher_h");
      uvm_report_cb::add(d, catcher_h);
      // Both callbacks and catchers have add() and add_by_name() variants
    endfunction
    
    task run_phase(uvm_phase phase);
      seq_of_commands seq;
      seq = seq_of_commands::type_id::create("seq");
      assert( seq.randomize() );
      seq.start( my_env_h.my_agent_h.my_sequencer_h );
      uvm_test_done.set_drain_time( this, 20ns );
    endtask
    
  endclass: my_test
  
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
    
    run_test("my_test");
  end

endmodule: top

