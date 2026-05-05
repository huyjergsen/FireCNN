`ifndef CNN_INTERFACE
`define CNN_INTERFACE

interface cnn_interface#(pWEIGHT_DATA_WIDTH = 64, pDATA_WIDTH = 24) (
   input	logic			clk
  ,input	logic			rst
);
  
  logic			                        en;
  logic	                            load_weight;
  logic			[pWEIGHT_DATA_WIDTH-1:0] weight_data;
  logic	    [31:0]                  weight_addr;
  logic     [pDATA_WIDTH-1:0]        data_in;
  logic     [31:0]                  data_out;
  logic                             valid;
  logic                             done;

  
  clocking cb_master_tb @(posedge clk);
    default input #1 output #1;
    output			en;
    output      load_weight;
    output			weight_data;
    output	    weight_addr;
    output      data_in;
    input 	    data_out;
    input 	    valid;
    input	      done;
  endclocking
    
  modport master (
     input		    clk
     ,output			en
     ,output      load_weight
     ,output			weight_data
     ,output	    weight_addr
     ,output      data_in
     ,input 	    data_out
     ,input 	    valid
     ,input	      done
    ,clocking	    cb_master_tb
  );
        
  modport slave (
     input	    clk
     ,input			en
     ,input     load_weight
     ,input			weight_data
     ,input	    weight_addr
     ,input     data_in
     ,output 	  data_out
     ,output 	  valid
     ,output	  done
  );
    
endinterface

`endif 
