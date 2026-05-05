`timescale 1ns/1ps

module cnn_buffer #(
   parameter  pDATA_WIDTH   = 8
  ,parameter  pINPUT_WIDTH  = 640
  
  ,parameter  pKERNEL_SIZE  = 3
  ,parameter  pPADDING      = 1
)(
   input  logic                                             clk
  ,input  logic                                             rst
  ,input  logic                                             en
  ,input  logic [pDATA_WIDTH-1:0]                           data_in
  ,output logic [pDATA_WIDTH*pKERNEL_SIZE*pKERNEL_SIZE-1:0] data_out
);   

  localparam pBUFFER_WIDTH = pINPUT_WIDTH + 2*pPADDING - pKERNEL_SIZE;
   
  logic [pKERNEL_SIZE-1:0][pDATA_WIDTH-1:0] receptive_field_r [0:pKERNEL_SIZE-1];
  logic [pDATA_WIDTH-1:0] buffer_out [1:pKERNEL_SIZE-1];
    
  genvar line_idx;
  genvar reg_idx;
  
  generate
    // line buffers
    for (line_idx = 0; line_idx < pKERNEL_SIZE; line_idx = line_idx+1) begin
      if (line_idx > 0) begin
        line_buffer #(
           .pBUFFER_WIDTH ( pBUFFER_WIDTH )
          ,.pDATA_WIDTH   ( pDATA_WIDTH   )
        ) u_line_buffer (
           .clk       ( clk                                           )
          ,.rst       ( rst                                           )
          ,.en        ( en                                            )
          ,.data_in   ( receptive_field_r[line_idx-1][pKERNEL_SIZE-1] )
          ,.data_out  ( buffer_out[line_idx]                          )
        );
      end
      
      // receptive field
      for (reg_idx = 0; reg_idx <pKERNEL_SIZE ; reg_idx = reg_idx+1) begin
        logic [pDATA_WIDTH-1:0] receptive_field_in;
          
        assign receptive_field_in = reg_idx ? receptive_field_r[line_idx][reg_idx-1] : 
                                    line_idx ? buffer_out[line_idx] : data_in;          
        
        always_ff @(posedge clk) begin
          if (rst)
            receptive_field_r[line_idx][reg_idx] <= 'b0;
          else if (en)
            receptive_field_r[line_idx][reg_idx] <= receptive_field_in;
        end
      end  
    end
          
    //  buffer out
    for (line_idx = 0; line_idx < pKERNEL_SIZE; line_idx = line_idx+1) begin
      assign data_out[line_idx*pDATA_WIDTH*pKERNEL_SIZE +: pDATA_WIDTH*pKERNEL_SIZE] = receptive_field_r[line_idx];
    end
  endgenerate
    
endmodule
