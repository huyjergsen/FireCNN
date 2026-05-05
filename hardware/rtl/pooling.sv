`timescale 1ns/1ps

module pooling #(
   parameter  pDATA_WIDTH    = 8
  
  ,parameter  pINPUT_WIDTH  = 28
  ,parameter  pINPUT_HEIGHT = 28
  
  ,parameter  pCHANNEL      = 32
  
  ,parameter  pKERNEL_SIZE  = 2
  ,parameter  pPADDING      = 0
  ,parameter  pSTRIDE       = 1
   
  ,parameter  pPOOLING_TYPE = "max"
)(
   input  logic                             clk
  ,input  logic                             rst
  ,input  logic                             en
  ,input  logic                             top_valid
  ,input  logic                             data_valid
  ,input  logic [pDATA_WIDTH*pCHANNEL-1:0]  data_in
  ,output logic [pDATA_WIDTH*pCHANNEL-1:0]  data_out
  ,output logic                             rd_en
  ,output logic                             valid
  ,output logic                             done
);

  localparam pWINDOW_SIZE = pKERNEL_SIZE * pKERNEL_SIZE;
  
  logic [pDATA_WIDTH*pCHANNEL-1:0] buffer_in;
  logic [pDATA_WIDTH*pCHANNEL*pWINDOW_SIZE-1:0] buffer_out;
  logic is_padding;
  logic padding_valid;
  logic buffer_en;
  logic pe_en;
  logic pe_ready;
  logic [15:0] count_valid;
   
  assign buffer_in = is_padding ? 'b0 : data_in;
  
  always_ff @(posedge clk) begin
    if (rst) begin
      padding_valid <= 'b0;
      count_valid   <= 'b0;
    end
    else if(top_valid)
      count_valid   <= 'b0;
    else begin
      padding_valid <= is_padding;
      if(valid) count_valid <= count_valid + 1;
    end
  end
  
  cnn_controller #(
     .pINPUT_WIDTH  ( pINPUT_WIDTH  )
    ,.pINPUT_HEIGHT ( pINPUT_HEIGHT )
    ,.pKERNEL_SIZE  ( pKERNEL_SIZE  )
    ,.pPADDING      ( pPADDING      )
    ,.pSTRIDE       ( pSTRIDE       )
  ) u_controller (
     .clk         ( clk                         )
    ,.rst         ( rst                         )
    ,.en          ( en                          )
    ,.rd_en       ( rd_en                       )
    ,.data_valid  ( data_valid || padding_valid )
    ,.is_padding  ( is_padding                  )
    ,.buffer_en   ( buffer_en                   )
    ,.pe_en       ( pe_en                       )
    ,.pe_ready    ( pe_ready                    )
    ,.done        ( done                        )
  );
      
  cnn_buffer #(
     .pINPUT_WIDTH  ( pINPUT_WIDTH          )
    ,.pDATA_WIDTH   ( pDATA_WIDTH*pCHANNEL  )
    ,.pKERNEL_SIZE  ( pKERNEL_SIZE          )
    ,.pPADDING      ( pPADDING              )
  ) u_buffer (
     .clk       ( clk         )
    ,.rst       ( rst         )
    ,.en        ( buffer_en   )
    ,.data_in   ( buffer_in   )
    ,.data_out  ( buffer_out  )
  );
  
  pe_pooling #(
     .pDATA_WIDTH   ( pDATA_WIDTH   )
    ,.pCHANNEL      ( pCHANNEL      )
    ,.pKERNEL_SIZE  ( pKERNEL_SIZE  )
    ,.pPOOLING_TYPE ( pPOOLING_TYPE )
  ) u_pe (
     .clk       ( clk                 )
    ,.rst       ( rst                 )
    ,.en        ( pe_en && data_valid )
    ,.data_in   ( buffer_out          )
    ,.data_out  ( data_out            )
    ,.pe_ready  ( pe_ready            )
    ,.valid     ( valid               )    
  );

endmodule
