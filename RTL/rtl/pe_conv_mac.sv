`timescale 1ns/1ps

module pe_conv_mac #(
   parameter  pDATA_WIDTH         = 8
   
  ,parameter  pIN_CHANNEL         = 1
  ,parameter  pOUT_CHANNEL        = 32
  
  ,parameter  pKERNEL_SIZE        = 3
  
  ,parameter  pOUTPUT_PARALLEL    = 32
  
  ,parameter  pKERNEL_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 4000_0000
  
  // activation type (relu, sigmoid)
  ,parameter  pACTIVATION         = "sigmoid"
)(
   input  logic                                                         clk
  ,input  logic                                                         rst
  
  ,input  logic                                                         load_weight
  ,input  logic [31:0]                                                  weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]                                weight_data
  
  ,input  logic                                                         buffer_in_en
  ,input  logic                                                         conv_en
  ,input  logic                                                         en
  ,input  logic [pDATA_WIDTH*pIN_CHANNEL*pKERNEL_SIZE*pKERNEL_SIZE-1:0] data_in
  ,output logic [pDATA_WIDTH*pOUT_CHANNEL-1:0]                          data_out
  
  //,output logic                                                         padding_slot
  ,output logic                                                         pe_ready
  ,output logic                                                         valid
);

  localparam pDSP_NUM = pIN_CHANNEL * pOUTPUT_PARALLEL;
  localparam pULTRA_RAM_NUM = pDSP_NUM / (pKERNEL_DATA_WIDTH/pDATA_WIDTH);
  localparam pBLOCK_RAM_NUM = pOUTPUT_PARALLEL/2;

  localparam pKERNEL_NUM = pIN_CHANNEL*pOUT_CHANNEL*pKERNEL_SIZE*pKERNEL_SIZE*pDATA_WIDTH/pKERNEL_DATA_WIDTH/pULTRA_RAM_NUM;
  localparam pBIAS_NUM = pOUT_CHANNEL == pOUTPUT_PARALLEL ? pOUT_CHANNEL/2 : pOUT_CHANNEL/pOUTPUT_PARALLEL;
  
  //(* ram_style = "distributed" *)
  logic [$clog2(pOUT_CHANNEL/pOUTPUT_PARALLEL)-1:0] buffer_idx;
  logic [$clog2(pKERNEL_NUM)-1:0] kernel_addr;
  logic [$clog2(pBIAS_NUM)-1:0] bias_addr;
  logic [$clog2(pKERNEL_SIZE*pKERNEL_SIZE)-1:0] pixel;
  logic [pDATA_WIDTH*pIN_CHANNEL-1:0] buffer_out;
  logic [pDATA_WIDTH*pIN_CHANNEL-1:0] datapath_in;
  logic [pDATA_WIDTH*pOUTPUT_PARALLEL-1:0] datapath_out;
  
  logic datapath_en;
  logic buffer_valid;
  logic pe_clr;
  logic datapath_buffer_en;
  logic adder_en;
  logic dequant_en;
  logic bias_en;
  logic act_en;
  logic quant_en;
  logic buffer_en;
  
  assign datapath_in = (datapath_buffer_en)  ? 'b0 : buffer_out;

  always_ff @(posedge clk) begin
    if (rst)
      datapath_en <= 'b0;
    else
      datapath_en <= en;    
  end

  pe_conv_mac_controller #(
     .pIN_CHANNEL       ( pIN_CHANNEL       )
    ,.pOUT_CHANNEL      ( pOUT_CHANNEL      )
    ,.pKERNEL_SIZE      ( pKERNEL_SIZE      )
    ,.pOUTPUT_PARALLEL  ( pOUTPUT_PARALLEL  )
    ,.pKERNEL_NUM       ( pKERNEL_NUM       )
    ,.pBIAS_NUM         ( pBIAS_NUM         )
    ,.pACTIVATION       ( pACTIVATION       )
  ) u_pe_controller (
     .clk                 ( clk                 )
    ,.rst                 ( rst                 )
    ,.en                  ( en                  )
    ,.conv_en             ( conv_en             )
    ,.buffer_valid        ( buffer_valid        )
    ,.buffer_idx          ( buffer_idx          )
    ,.pixel               ( pixel               )
    ,.kernel_addr         ( kernel_addr         )
    ,.bias_addr           ( bias_addr           )
    ,.pe_ready            ( pe_ready            )
    ,.pe_clr              ( pe_clr              )
    ,.datapath_buffer_en  ( datapath_buffer_en  )
    ,.adder_en            ( adder_en            )
    ,.dequant_en          ( dequant_en          )
    ,.bias_en             ( bias_en             )
    ,.act_en              ( act_en              )
    ,.quant_en            ( quant_en            )
    ,.buffer_en           ( buffer_en           )
    ,.valid               ( valid               )
  );

  pe_conv_mac_buffer_in #(
     .pDATA_WIDTH   ( pDATA_WIDTH*pIN_CHANNEL )
    ,.pKERNEL_SIZE  ( pKERNEL_SIZE            )
  ) u_pe_buffer_in (
     .clk         ( clk           )
    ,.rst         ( rst           )
    ,.en          ( buffer_in_en  )
    ,.pixel       ( pixel         )
    ,.data_in     ( data_in       )
    ,.data_out    ( buffer_out    )    
    ,.valid       ( buffer_valid  )
  );
  
  pe_conv_mac_datapath #(
     .pDATA_WIDTH         ( pDATA_WIDTH         )
    ,.pIN_CHANNEL         ( pIN_CHANNEL         )
    ,.pOUT_CHANNEL        ( pOUT_CHANNEL        )
    ,.pULTRA_RAM_NUM      ( pULTRA_RAM_NUM      )
    ,.pBLOCK_RAM_NUM      ( pBLOCK_RAM_NUM      )
    ,.pKERNEL_NUM         ( pKERNEL_NUM         )
    ,.pBIAS_NUM           ( pBIAS_NUM           )
    ,.pOUTPUT_PARALLEL    ( pOUTPUT_PARALLEL    )
    ,.pKERNEL_DATA_WIDTH  ( pKERNEL_DATA_WIDTH  )
    ,.pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( pACTIVATION         )
  ) u_pe_datapath (
     .clk         ( clk           )
    ,.rst         ( rst           )
    ,.clr         ( pe_clr        )
    ,.load_weight ( load_weight   )
    ,.weight_addr ( weight_addr   )
    ,.weight_data ( weight_data   )
    ,.kernel_addr ( kernel_addr   )
    ,.bias_addr   ( bias_addr     )
    ,.en          ( datapath_en   )
    ,.adder_en    ( adder_en      )
    ,.dequant_en  ( dequant_en    )
    ,.bias_en     ( bias_en       )
    ,.act_en      ( act_en        )
    ,.quant_en    ( quant_en      )
    ,.data_in     ( datapath_in   )
    ,.data_out    ( datapath_out  )
  );
  
  pe_conv_mac_buffer_out #(
     .pDATA_WIDTH       ( pDATA_WIDTH       )
    ,.pOUT_CHANNEL      ( pOUT_CHANNEL      )
    ,.pOUTPUT_PARALLEL  ( pOUTPUT_PARALLEL  )
  ) u_pe_buffer_out (
     .clk         ( clk           )
    ,.rst         ( rst           )
    ,.wr_en       ( buffer_en     )
    ,.buffer_idx  ( buffer_idx    )
    ,.data_in     ( datapath_out  )
    ,.data_out    ( data_out      )
  );
  
endmodule
