`ifndef CNN_SCOREBOARD
`define CNN_SCOREBOARD

class cnn_scoreboard #(
  parameter pWEIGHT_DATA_WIDTH = 64,
  parameter pDATA_WIDTH = 32
) extends uvm_scoreboard;
  
  `uvm_component_param_utils(cnn_scoreboard#(pWEIGHT_DATA_WIDTH, pDATA_WIDTH));

  uvm_analysis_imp #(cnn_sequence_item, cnn_scoreboard) item_collected_export;
  
  function new (input string name = "cnn_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase (input uvm_phase phase);
    super.build_phase(phase);  
  endfunction
  
endclass

`endif
