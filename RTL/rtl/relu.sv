`timescale 1ns/1ps

module relu #(
   parameter pDATA_WIDTH  = 32
)(
   input  logic                           clk
  ,input  logic                           rst
  ,input  logic                           en
  ,input  logic signed  [pDATA_WIDTH-1:0] data_in
  ,output logic signed  [pDATA_WIDTH-1:0] data_out
);

  always_ff @(posedge clk) begin
    if (rst)
      data_out <= 'b0;
    else
      data_out <= data_in[pDATA_WIDTH-1] ? 'b0 : data_in; 
  end

endmodule
