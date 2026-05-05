`ifndef CNN_AGENT
`define CNN_AGENT

class cnn_agent extends uvm_agent;
  `uvm_component_utils(cnn_agent);
  
  cnn_sequencer seqr;
  cnn_driver drv;
  cnn_monitor mon;
  
  function new (string name = "cnn_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase (uvm_phase phase);
    super.build_phase(phase);
    
    if (get_is_active()) begin
      seqr = cnn_sequencer::type_id::create("cnn_sequencer", this);
      drv = cnn_driver::type_id::create("cnn_driver", this);
    end
    
    mon = cnn_monitor::type_id::create("cnn_monitor", this);
  endfunction
  
  virtual function void connect_phase (uvm_phase phase);
  	if (get_is_active())
      drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
  
endclass

`endif
