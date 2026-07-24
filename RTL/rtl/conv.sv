`timescale 1ns/1ps

module conv #(
   parameter  pDATA_WIDTH         = 8
   
  ,parameter  pINPUT_WIDTH        = 28
  ,parameter  pINPUT_HEIGHT       = 28
  
  ,parameter  pIN_CHANNEL         = 1
  ,parameter  pOUT_CHANNEL        = 32
  
  ,parameter  pKERNEL_SIZE        = 3
  ,parameter  pPADDING            = 1
  ,parameter  pSTRIDE             = 1
  
  ,parameter  pOUTPUT_PARALLEL    = 32
  
  // kernel ram
  ,parameter  pKERNEL_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 0
  
  // activation type (sigmoid, relu)
  ,parameter  pACTIVATION   = "sigmoid"
)(
   input  logic                                 clk
  ,input  logic                                 rst
  ,input  logic                                 top_valid
  ,input  logic                                 en
  ,input  logic                                 load_weight
  ,input  logic [31:0]                          weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]        weight_data
  ,input  logic                                 data_valid
  ,input  logic [pDATA_WIDTH*pIN_CHANNEL-1:0]   data_in
  ,output logic [pDATA_WIDTH*pOUT_CHANNEL-1:0]  data_out
  ,output logic                                 rd_en
  ,output logic                                 valid
  ,output logic                                 done
);

  localparam pWINDOW_SIZE = pKERNEL_SIZE * pKERNEL_SIZE;
  
  logic [pDATA_WIDTH*pIN_CHANNEL-1:0] buffer_in;
  logic [pDATA_WIDTH*pIN_CHANNEL*pWINDOW_SIZE-1:0] buffer_out;
  logic is_padding;
  logic padding_valid;
  logic buffer_en;
  logic pe_en;
  logic pe_ready;
  logic [14:0] count_valid;
  
  logic pe_pading;
   
  assign buffer_in = padding_valid ? 'b0 : data_in;
  
  always_ff @(posedge clk) begin
    if (rst) 
      padding_valid <= 'b0;
    else
      padding_valid <= is_padding;
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
    ,.pe_padding  ( pe_padding                  )
    ,.done        ( done                        )
  );
      
  cnn_buffer #(
     .pINPUT_WIDTH  ( pINPUT_WIDTH            )
    ,.pDATA_WIDTH   ( pDATA_WIDTH*pIN_CHANNEL )
    ,.pKERNEL_SIZE  ( pKERNEL_SIZE            )
    ,.pPADDING      ( pPADDING                )
  ) u_buffer (
     .clk       ( clk         )
    ,.rst       ( rst         )
    ,.en        ( buffer_en   )
    ,.data_in   ( buffer_in   )
    ,.data_out  ( buffer_out  )
  );

  pe_conv_mac #(
     .pDATA_WIDTH         ( pDATA_WIDTH         )
    ,.pIN_CHANNEL         ( pIN_CHANNEL         )
    ,.pOUT_CHANNEL        ( pOUT_CHANNEL        )
    ,.pKERNEL_SIZE        ( pKERNEL_SIZE        )
    ,.pOUTPUT_PARALLEL    ( pOUTPUT_PARALLEL    )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
    ,.pKERNEL_DATA_WIDTH  ( pKERNEL_DATA_WIDTH  )
    ,.pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
    ,.pACTIVATION         ( pACTIVATION         )
  ) u_pe (
     .clk           ( clk                 )
    ,.rst           ( rst                 )
    ,.conv_en       ( en || pe_padding    )
    ,.en            ( pe_en               )
    ,.buffer_in_en  ( buffer_en && pe_en  )
    ,.load_weight   ( load_weight         )
    ,.weight_addr   ( weight_addr         )
    ,.weight_data   ( weight_data         )
    ,.data_in       ( buffer_out          )
    ,.data_out      ( data_out            )
    //,.padding_slot  (                     )
    ,.pe_ready      ( pe_ready            )
    ,.valid         ( valid               )
  );   
  
  always_ff @(posedge clk) begin
    if (rst || top_valid) 
      count_valid <= 'b0;
    else if(valid)
      count_valid <= count_valid + 1;
  end
        
endmodule
