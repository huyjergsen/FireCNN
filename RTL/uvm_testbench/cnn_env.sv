`ifndef CNN_ENV
`define CNN_ENV

class cnn_env extends uvm_env;
  `uvm_component_utils(cnn_env);
  
  cnn_agent agent;
  cnn_scoreboard scb;
  
  function new (string name = "cnn_env", uvm_component parent = null);
    super.new(name, parent);
    agent = cnn_agent::type_id::create("cnn_agent", this);
    scb = cnn_scoreboard #(32, 16)::type_id::create("cnn_scoreboard", this);
  endfunction
  
  virtual function void build_phase (uvm_phase phase);
    super.build_phase(phase);
  endfunction
  
  virtual function void connect_phase (uvm_phase phase);
    agent.mon.item_collected_port.connect(scb.item_collected_export);
  endfunction
endclass

`define CNN_ENV
