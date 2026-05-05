`ifndef CNN_SEQUENCE_ITEM
`define CNN_SEQUENCE_ITEM

class cnn_sequence_item #(
  parameter pWEIGHT_DATA_WIDTH = 64,
  parameter pDATA_WIDTH = 32
) extends uvm_sequence_item;
  	
  rand	bit		                         en;
  rand	bit                            load_weight;
  rand	bit  [pWEIGHT_DATA_WIDTH-1:0]  weight_data;
  rand	bit  [31:0]                    weight_addr;
  rand  bit  [pDATA_WIDTH-1:0]         data_in;
  rand  bit  [31:0]                    data_out;
  rand  bit                            valid;
  rand  bit                            done;

  
  `uvm_object_param_utils_begin(cnn_sequence_item#(pWEIGHT_DATA_WIDTH, pDATA_WIDTH))
  	`uvm_field_int(en, UVM_ALL_ON)
  	`uvm_field_int(load_weight, UVM_ALL_ON)
  	`uvm_field_int(weight_data, UVM_ALL_ON)
  	`uvm_field_int(weight_addr, UVM_ALL_ON)
    `uvm_field_int(data_in, UVM_ALL_ON)
  	`uvm_field_int(data_out, UVM_ALL_ON)
  	`uvm_field_int(valid, UVM_ALL_ON)
    `uvm_field_int(done, UVM_ALL_ON)
  `uvm_object_utils_end
  	
  function new (input string name = "cnn_sequence_item");
    super.new(name);	
  endfunction
  
endclass

`endif
