`timescale 1ns/1ps

(* use_dsp = "yes" *)
module dsp_single_mult (
   input  logic                 clk
  ,input  logic                 rst
  ,input  logic                 en
  ,input  logic         [7:0]   a
  ,input  logic signed  [7:0]   b
  ,output logic signed  [31:0]  c
);
  logic signed [15:0] a_ext;
  logic signed [15:0] b_ext;
  
  logic valid;
  
  always_ff @(posedge clk) begin
    if (rst) begin
      a_ext <= 'b0;
      b_ext <= 'b0;
      valid <= 'b0;
    end
    else if (en) begin
      a_ext <= {8'b0, a};
      b_ext <= {{8{b[7]}}, b};
      valid <= en;
    end
  end
  
//  assign a_ext = {8'b0, a};
//  assign b_ext = {{8{b[7]}}, b};
  
  always_ff @(posedge clk) begin
    if (rst) begin
      c <= 'b0;
    end
    else if (valid)
      c <= a_ext * b_ext;
  end

endmodule
