`timescale 1ns/1ps

module sigmoid #(
   parameter pDATA_WIDTH  = 32
  ,parameter pFRAC_NUM    = 16
)(
   input  logic                           clk
  ,input  logic                           rst
  ,input  logic                           en
  ,input  logic signed  [pDATA_WIDTH-1:0] data_in
  ,output logic signed  [pDATA_WIDTH-1:0] data_out
);
  
  localparam pINT_NUM = pDATA_WIDTH - pFRAC_NUM;
  
  // constrain used in sigmoid function                                                                          
  localparam signed [pDATA_WIDTH-1:0] FLOAT_2_375   = {{pDATA_WIDTH-6{1'b0}}, 6'b10_011}  << (pFRAC_NUM-3);
  localparam signed [pDATA_WIDTH-1:0] FLOAT_0_84375 = {{pDATA_WIDTH-7{1'b0}}, 7'b0_11011} << (pFRAC_NUM-5);
  localparam signed [pDATA_WIDTH-1:0] FLOAT_0_625   = {{pDATA_WIDTH-4{1'b0}}, 4'b0_101}   << (pFRAC_NUM-3);
  localparam signed [pDATA_WIDTH-1:0] FLOAT_0_5     = {{pDATA_WIDTH-2{1'b0}}, 2'b0_1}     << (pFRAC_NUM-1);
  
  logic signed [pDATA_WIDTH-1:0] abs;
  logic signed [pDATA_WIDTH-1:0] shift_right_5;
  logic signed [pDATA_WIDTH-1:0] shift_right_3;
  logic signed [pDATA_WIDTH-1:0] shift_right_2;
  logic signed [pDATA_WIDTH-1:0] a;
  logic signed [pDATA_WIDTH-1:0] b;
  logic signed [pDATA_WIDTH-1:0] pos_sigmoid;
  logic signed [pDATA_WIDTH-1:0] neg_sigmoid;
  
  assign abs = data_in[pDATA_WIDTH-1] ? {1'b0, ~data_in[pDATA_WIDTH-2:0]} : data_in;
  
  assign shift_right_5 = {5'b0, abs[pDATA_WIDTH-1:5]};
  assign shift_right_3 = {3'b0, abs[pDATA_WIDTH-1:3]};
  assign shift_right_2 = {2'b0, abs[pDATA_WIDTH-1:2]};

  assign a =  abs >= ('d5 << pFRAC_NUM) ? ('d1 << pFRAC_NUM) :
              abs >= FLOAT_2_375        ? FLOAT_0_84375 :
              abs >= ('d1 << pFRAC_NUM) ? FLOAT_0_625 : FLOAT_0_5;
  assign b =  abs >= ('d5 << pFRAC_NUM) ? 32'd0 :
              abs >= FLOAT_2_375        ? shift_right_5 :
              abs >= ('d1 << pFRAC_NUM) ? shift_right_3 : shift_right_2;
  
  assign pos_sigmoid = a + b;
  assign neg_sigmoid = ('d1 << pFRAC_NUM) - pos_sigmoid;
  
  always_ff @(posedge clk) begin
    if (rst)
      data_out <= 'b0;
    else if (en)
      data_out <= data_in[pDATA_WIDTH-1] ? neg_sigmoid : pos_sigmoid;
  end
    
endmodule

