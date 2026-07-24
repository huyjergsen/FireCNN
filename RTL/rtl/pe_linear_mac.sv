`timescale 1ns/1ps

module pe_linear_mac #(
   parameter  pDATA_WIDTH         = 8 

  ,parameter  pIN_FEATURE         = 14*14*32
  ,parameter  pOUT_FEATURE        = 128
  
  ,parameter  pCHANNEL            = 32
  ,parameter  pOUTPUT_PARALLEL    = 4
  
  ,parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 4000_0000
  
  // activation type (relu, sigmoid)
  ,parameter  pACTIVATION         = "sigmoid"
  
  ,localparam pOUTPUT_WIDTH       = pACTIVATION == "softmax" ? 32*pOUT_FEATURE : pDATA_WIDTH*pOUT_FEATURE
)(
   input  logic                             clk
  ,input  logic                             rst
  ,input  logic                             en
  ,input  logic                             done
  ,input  logic                             load_weight
  ,input  logic [31:0]                      weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]    weight_data
  ,input  logic [pDATA_WIDTH*pCHANNEL-1:0]  data_in
  ,output logic [pOUTPUT_WIDTH-1:0]         data_out
  ,output logic                             pe_ready
  ,output logic                             valid
);

  localparam pDSP_NUM = pCHANNEL * pOUTPUT_PARALLEL;
  localparam pBLOCK_RAM_NUM = pDSP_NUM / (pWEIGHT_DATA_WIDTH/pDATA_WIDTH);

  localparam pKERNEL_NUM = pIN_FEATURE*pOUT_FEATURE / (pBLOCK_RAM_NUM * pWEIGHT_DATA_WIDTH/pDATA_WIDTH);
  localparam pBIAS_NUM = pOUT_FEATURE;
  
  logic [$clog2(pKERNEL_NUM)-1:0] kernel_addr;
  logic [$clog2(pOUT_FEATURE/pOUTPUT_PARALLEL)-1:0] out_feature;
  logic dsp_en;
  logic adder_en;
  logic mac_en;
  logic dequant_en;
  logic bias_en;
  logic act_en;
  logic quant_en;
  logic pe_clr;
  
  pe_linear_mac_controller #(
     .pIN_FEATURE       ( pIN_FEATURE       )
    ,.pOUT_FEATURE      ( pOUT_FEATURE      )
    ,.pCHANNEL          ( pCHANNEL          )
    ,.pOUTPUT_PARALLEL  ( pOUTPUT_PARALLEL  )
    ,.pKERNEL_NUM       ( pKERNEL_NUM       )
    ,.pACTIVATION       ( pACTIVATION       )
  ) u_pe_controller (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.en          ( en          )
    ,.done        ( done        )
    ,.kernel_addr ( kernel_addr )
    ,.out_feature ( out_feature )
    ,.pe_ready    ( pe_ready    )
    ,.pe_clr      ( pe_clr      )
    ,.dsp_en      ( dsp_en      )
    ,.adder_en    ( adder_en    )
    ,.mac_en      ( mac_en      )
    ,.dequant_en  ( dequant_en  )
    ,.bias_en     ( bias_en     )
    ,.act_en      ( act_en      )
    ,.quant_en    ( quant_en    )
    ,.valid       ( valid       )
  );
  
  pe_linear_mac_datapath #(
     .pDATA_WIDTH         ( pDATA_WIDTH         )
    ,.pIN_FEATURE         ( pIN_FEATURE         )
    ,.pOUT_FEATURE        ( pOUT_FEATURE        )
    ,.pCHANNEL            ( pCHANNEL            )
    ,.pOUTPUT_PARALLEL    ( pOUTPUT_PARALLEL    )
    ,.pBLOCK_RAM_NUM      ( pBLOCK_RAM_NUM      )
    ,.pKERNEL_NUM         ( pKERNEL_NUM         )
    ,.pBIAS_NUM           ( pBIAS_NUM           )
    ,.pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( pACTIVATION         )
  ) u_pe_datapath (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.clr         ( pe_clr      )
    ,.load_weight ( load_weight )
    ,.weight_addr ( weight_addr )
    ,.weight_data ( weight_data )
    ,.kernel_addr ( kernel_addr )
    ,.out_feature ( out_feature )
    ,.dsp_en      ( dsp_en      )
    ,.adder_en    ( adder_en    )
    ,.mac_en      ( mac_en      )
    ,.dequant_en  ( dequant_en  )
    ,.bias_en     ( bias_en     )
    ,.act_en      ( act_en      )
    ,.quant_en    ( quant_en    )
    ,.data_in     ( data_in     )
    ,.data_out    ( data_out    )
  );

endmodule
