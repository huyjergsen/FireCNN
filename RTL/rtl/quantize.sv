`timescale 1ns/1ps

module quantize (
   input  logic                 clk
  ,input  logic                 rst
  ,input  logic                 en
  ,input  logic signed  [31:0]  data_in
  ,output logic         [7:0]   data_out
);
      
  always_ff @(posedge clk) begin
    if (rst)
      data_out <= 'b0;
    else if (en)
      data_out <= data_in[16] ? 8'd255 : data_in[15:8];
  end
  
endmodule
