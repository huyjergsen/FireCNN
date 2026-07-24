`timescale 1ns/1ps

module pe_conv_mac_buffer_in #(
   parameter  pDATA_WIDTH       = 8
  ,parameter  pKERNEL_SIZE      = 3
  
  ,parameter  pINPUT_CHANNEL    = 1
  ,parameter  pINPUT_PARALLEL   = 1
)(
   input  logic                                                             clk
  ,input  logic                                                             rst
  ,input  logic                                                             en
  ,input  logic [$clog2(pKERNEL_SIZE*pKERNEL_SIZE)-1:0]                     pixel
  ,input  logic [pDATA_WIDTH*pINPUT_CHANNEL*pKERNEL_SIZE*pKERNEL_SIZE-1:0]  data_in
  ,output logic [pDATA_WIDTH*pINPUT_PARALLEL-1:0]                           data_out
  ,output logic                                                             valid
);

  logic available_read;
  logic [$clog2(pKERNEL_SIZE*pKERNEL_SIZE)-1:0] pixel_be;
  
  always @(posedge clk) begin
    if(rst) pixel_be <= 'b0;
    else pixel_be <= pixel;
  end
  
  assign compelete_one_data = (pixel_be == 8)  &&  (pixel == 0);
  
  always @(posedge clk) begin
    if(rst) available_read <= 0;
    else begin
        if(en == 1) available_read <= 1;
        else if(compelete_one_data == 1) available_read <= 0;
    end
  end

  logic [pDATA_WIDTH-1:0] receptive_field_r [0:pKERNEL_SIZE*pKERNEL_SIZE-1];
  
  genvar pixel_idx;
  
  generate
    for (pixel_idx = 0; pixel_idx < pKERNEL_SIZE*pKERNEL_SIZE; pixel_idx = pixel_idx+1) begin
      always_ff @(posedge clk) begin
        if (rst)
          receptive_field_r[pixel_idx] <= 'b0;
        else
          receptive_field_r[pixel_idx] <= data_in[(pKERNEL_SIZE*pKERNEL_SIZE-pixel_idx)*pDATA_WIDTH-1 -: pDATA_WIDTH];
      end
    end
  endgenerate
  
  always_ff @(posedge clk) begin
    if (rst)
      data_out <= 'b0;
    else if (available_read)
      data_out <= receptive_field_r[pixel];
    else
      data_out <= 'b0;
  end

  always_ff @(posedge clk) begin
    if (rst)
      valid <= 'b0;
    else
      valid <= en;
  end
  
endmodule
