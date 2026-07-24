`ifndef CNN_TTEST
`define CNN_TEST
`include "cnn_interface.sv"
`include "cnn_interface.sv"

module cnn_top #(  parameter pWEIGHT_DATA_WIDTH = 64, pDATA_WIDTH = 32);
    
    parameter cycle = 10;
    bit clk;
    bit reset;

    initial begin
        clk = 0;
        forever #(cycle/2) clk =~ clk;
    end

    initial begin
        reset = 1;
        #(cycle*5) reset = 0;
    end

    
    
    

`endif
