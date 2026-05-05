`timescale 1ns/1ps

module line_buffer #(
   parameter  pDATA_WIDTH   = 8
  ,parameter  pBUFFER_WIDTH = 640
)(
   input  logic                   clk
  ,input  logic                   rst
  ,input  logic                   en
  ,input  logic [pDATA_WIDTH-1:0] data_in
  ,output logic [pDATA_WIDTH-1:0] data_out
);
 
  logic [pDATA_WIDTH-1:0] buffer_r [0:pBUFFER_WIDTH-1];
  
  genvar reg_idx;
  
  generate
    for (reg_idx = 0; reg_idx < pBUFFER_WIDTH; reg_idx = reg_idx+1) begin
      logic [pDATA_WIDTH-1:0] buffer_in;
      
      assign buffer_in = reg_idx ? buffer_r[reg_idx-1] : data_in;
      
      always_ff @(posedge clk) begin
        if (rst)
          buffer_r[reg_idx] <= 'b0;
        else if (en)
          buffer_r[reg_idx] <= buffer_in;
        end
    end
  endgenerate
    
  assign data_out = buffer_r[pBUFFER_WIDTH-1];
   
endmodule
