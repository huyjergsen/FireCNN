`timescale 1ns/1ps

module pe_conv_mac_buffer_out #(
   parameter  pDATA_WIDTH       = 8
   
  ,parameter  pOUT_CHANNEL      = 32
  ,parameter  pOUTPUT_PARALLEL  = 32
)(
   input  logic                                             clk
  ,input  logic                                             rst
  ,input  logic                                             wr_en
  ,input  logic [$clog2(pOUT_CHANNEL/pOUTPUT_PARALLEL)-1:0] buffer_idx
  ,input  logic [pDATA_WIDTH*pOUTPUT_PARALLEL-1:0]          data_in
  ,output logic [pDATA_WIDTH*pOUT_CHANNEL-1:0]              data_out
);

  logic [pOUT_CHANNEL/pOUTPUT_PARALLEL-1:0][pDATA_WIDTH*pOUTPUT_PARALLEL-1:0] buffer_r;

  always_ff @(posedge clk) begin
    if (rst)
      buffer_r <= 'b0;
    else if (wr_en)
      buffer_r[buffer_idx] <= data_in;
  end
  
  assign data_out = buffer_r;

endmodule
