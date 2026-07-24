`timescale 1ns/1ps

module pe_pooling #(
   parameter  pDATA_WIDTH   = 8
   
  ,parameter  pCHANNEL      = 1
  ,parameter  pKERNEL_SIZE  = 3
  
  ,parameter  pPOOLING_TYPE = "max"
)(
   input  logic                                                       clk
  ,input  logic                                                       rst
  ,input  logic                                                       en
  ,input  logic [pDATA_WIDTH*pCHANNEL*pKERNEL_SIZE*pKERNEL_SIZE-1:0]  data_in
  ,output logic [pDATA_WIDTH*pCHANNEL-1:0]                            data_out
  ,output logic                                                       pe_ready
  ,output logic                                                       valid
);
  
  localparam pPOOLING_STAGE_NUM = $clog2(pKERNEL_SIZE*pKERNEL_SIZE) + 1;
  
  logic datapath_en;
  logic [pPOOLING_STAGE_NUM-1:0] valid_r;
    
  genvar stage_idx;
  genvar channel_idx;
  genvar pixel_idx;
  
  always_ff @(posedge clk) begin
    if (rst)
      datapath_en <= 'b0;
    else
      datapath_en <= en;
  end
  
  generate
    for (stage_idx = 0; stage_idx < pPOOLING_STAGE_NUM; stage_idx = stage_idx+1) begin
      logic valid_in;
      
      assign valid_in = stage_idx ? valid_r[stage_idx-1] : datapath_en;
    
      always_ff @(posedge clk) begin
        if (rst)
          valid_r[stage_idx] <= 'b0;
        else
          valid_r[stage_idx] <= valid_in;
      end
    end   
  
    for (channel_idx = 0; channel_idx < pCHANNEL; channel_idx = channel_idx+1) begin
      logic [pKERNEL_SIZE*pKERNEL_SIZE-1:0][pDATA_WIDTH-1:0] receptive_field;
      
      for (pixel_idx = 0; pixel_idx < pKERNEL_SIZE*pKERNEL_SIZE; pixel_idx = pixel_idx+1) begin
        assign receptive_field[pixel_idx] = data_in[pixel_idx*pDATA_WIDTH*pCHANNEL+channel_idx*pDATA_WIDTH +: pDATA_WIDTH];
      end
    
      pe_pooling_datapath #(
         .pDATA_WIDTH   ( pDATA_WIDTH               )
        ,.pWINDOW_SIZE  ( pKERNEL_SIZE*pKERNEL_SIZE )
      ) u_pe_datapath (
         .clk       ( clk                                               )
        ,.rst       ( rst                                               )
        ,.en        ( datapath_en                                       )
        ,.data_in   ( receptive_field                                   )
        ,.data_out  ( data_out[channel_idx*pDATA_WIDTH +: pDATA_WIDTH]  )
      );
    end
  endgenerate
  
  assign pe_ready = 'b1;
  assign valid = valid_r[pPOOLING_STAGE_NUM-1];
  
endmodule
