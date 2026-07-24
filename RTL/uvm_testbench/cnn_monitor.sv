`ifndef CNN_MONITOR 
`define CNN_MONITOR

class cnn_monitor extends uvm_monitor;
  `uvm_component_utils(cnn_monitor);
  
  virtual cnn_interface vif;
  cnn_sequence_item trans_collected;
  uvm_analysis_port #(cnn_sequence_item) item_collected_port;
  
  function new (input string name = "cnn_monitor", uvm_component parent = null);
    super.new(name, parent);
    trans_collected = cnn_sequence_item #(32)::type_id::create();
    item_collected_port = new("item_collected_port", this);
  endfunction
  
  virtual function void build_phase (input uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db #(virtual cnn_interface)::get(this, "", "vif", vif))
      `uvm_fatal("CFG_ERROR", "Driver DUT interface not set");
  endfunction
  
  virtual task run_phase (input uvm_phase phase);
    forever begin
      @(posedge vif.clk);
        trans_collected.en = vif.master.en;
        trans_collected.load_weight = vif.master.load_weight;
        trans_collected.weight_data = vif.master.weight_data;
        trans_collected.weight_addr = vif.master.weight_addr;
        trans_collected.data_in     = vif.master.data_in;
        trans_collected.data_out    = vif.master.data_out;
        trans_collected.valid       = vif.master.valid;
        trans_collected.done        = vif.master.done;
        item_collected_port.write(trans_collected);
        

      end
  endtask
  
endclass

`endif
