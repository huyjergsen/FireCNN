`timescale 1ns/1ps

module linear #(
   parameter  pDATA_WIDTH         = 8 

  ,parameter  pIN_FEATURE         = 128
  ,parameter  pOUT_FEATURE        = 10
  
  ,parameter  pCHANNEL            = 32
  ,parameter  pOUTPUT_PARALLEL    = 1
    
  // kernel ram
  ,parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 0
  
  ,parameter  pACTIVATION         = "sigmoid"
  
  ,localparam pOUTPUT_WIDTH       = pACTIVATION == "softmax" ? 32*pOUT_FEATURE : pDATA_WIDTH*pOUT_FEATURE
)(
   input  logic                             clk
  ,input  logic                             rst
  ,input  logic                             en
  ,input  logic                             load_weight
  ,input  logic [31:0]                      weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]    weight_data
  ,input  logic                             data_valid
  ,input  logic [pDATA_WIDTH*pCHANNEL-1:0]  data_in
  ,output logic [pOUTPUT_WIDTH-1:0]         data_out
  ,output logic                             rd_en
  ,output logic                             valid
  ,output logic                             done
);
  
  logic pe_en;
  logic pe_ready;
  
  linear_controller #(
     .pIN_FEATURE       ( pIN_FEATURE       )
    ,.pOUT_FEATURE      ( pOUT_FEATURE      )
    ,.pCHANNEL          ( pCHANNEL          )
    ,.pOUTPUT_PARALLEL  ( pOUTPUT_PARALLEL  )
  ) u_controller (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.en          ( en          )
    ,.data_valid  ( data_valid  )
    ,.pe_ready    ( pe_ready    )
    ,.rd_en       ( rd_en       )
    ,.pe_en       ( pe_en       )
    ,.done        ( done        )
  );
  
  pe_linear_mac #(
     .pDATA_WIDTH         ( pDATA_WIDTH         )
    ,.pIN_FEATURE         ( pIN_FEATURE         )
    ,.pOUT_FEATURE        ( pOUT_FEATURE        )
    ,.pCHANNEL            ( pCHANNEL            )
    ,.pOUTPUT_PARALLEL    ( pOUTPUT_PARALLEL    )
    ,.pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( pACTIVATION         )
  ) u_pe (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.en          ( pe_en       )
    ,.done        ( done        )
    ,.load_weight ( load_weight )
    ,.weight_addr ( weight_addr )
    ,.weight_data ( weight_data )
    ,.data_in     ( data_in     )
    ,.data_out    ( data_out    )
    ,.pe_ready    ( pe_ready    )
    ,.valid       ( valid       )
  );

endmodule
