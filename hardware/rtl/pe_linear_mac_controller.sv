`timescale 1ns/1ps

module pe_linear_mac_controller #(   
   parameter  pIN_FEATURE         = 14*14*32
  ,parameter  pOUT_FEATURE        = 128
  
  ,parameter  pCHANNEL            = 32
  ,parameter  pOUTPUT_PARALLEL    = 4
  
  ,parameter  pKERNEL_NUM         = 6272

  // activation type (relu, sigmoid)
  ,parameter  pACTIVATION         = "sigmoid"
)(
   input  logic                                             clk
  ,input  logic                                             rst
  ,input  logic                                             en
  ,input  logic                                             done
  ,output logic [$clog2(pKERNEL_NUM)-1:0]                   kernel_addr
  ,output logic [$clog2(pOUT_FEATURE/pOUTPUT_PARALLEL)-1:0] out_feature
  ,output logic                                             pe_ready
  ,output logic                                             pe_clr
  ,output logic                                             dsp_en
  ,output logic                                             adder_en
  ,output logic                                             mac_en
  ,output logic                                             dequant_en
  ,output logic                                             bias_en
  ,output logic                                             act_en
  ,output logic                                             quant_en
  ,output logic                                             buffer_en
  ,output logic                                             valid
);
   
  localparam pMULT_PIPE_STAGE_NUM     = 3;
  localparam pADDER_PIPE_STAGE_NUM    = $clog2(pCHANNEL) + 1;
  localparam pDEQUANT_PIPE_STAGE_NUM  = 1;
  localparam pBIAS_PIPE_STAGE_NUM     = 1;
  localparam pQUANT_PIPE_STAGE_NUM    = 1;

  localparam pSIGMOID_PIPE_STAGE_NUM  = 1;
  localparam pRELU_PIPE_STAGE_NUM     = 1;

  localparam pACT_PIPE_STAGE_NUM =  pACTIVATION == "sigmoid"  ? pSIGMOID_PIPE_STAGE_NUM :
                                    pACTIVATION == "relu"     ? pRELU_PIPE_STAGE_NUM    : 'b0;
  localparam pMAC_PIPE_STAGE_NUM = pMULT_PIPE_STAGE_NUM + pADDER_PIPE_STAGE_NUM;
  localparam pPIPE_STAGE_NUM = pMAC_PIPE_STAGE_NUM + pDEQUANT_PIPE_STAGE_NUM + pBIAS_PIPE_STAGE_NUM + pACT_PIPE_STAGE_NUM + pQUANT_PIPE_STAGE_NUM + 2;
  
  localparam pADDER_STAGE_NUM   = pMULT_PIPE_STAGE_NUM; 
  localparam pDEQUAN_STAGE_NUM  = pADDER_STAGE_NUM + pADDER_PIPE_STAGE_NUM + 1;
  localparam pBIAS_STAGE_NUM    = pDEQUAN_STAGE_NUM + pDEQUANT_PIPE_STAGE_NUM;
  localparam pACT_STAGE_NUM     = pBIAS_STAGE_NUM + pBIAS_PIPE_STAGE_NUM;
  localparam pQUANT_STAGE_NUM   = pACT_STAGE_NUM + pACT_PIPE_STAGE_NUM;
  localparam pBUFFER_STAGE_NUM  = pQUANT_STAGE_NUM + pQUANT_PIPE_STAGE_NUM;
  localparam pVALID_STAGE_NUM   = pBUFFER_STAGE_NUM + 1; 

  logic [pMAC_PIPE_STAGE_NUM-1:0] mac_valid_r;
  logic [pPIPE_STAGE_NUM-1:0] valid_r;
  
  genvar reg_idx;
  
  generate
    for (reg_idx = 0; reg_idx < pMAC_PIPE_STAGE_NUM; reg_idx = reg_idx+1) begin
      logic valid_in;
      
      assign valid_in = reg_idx ? mac_valid_r[reg_idx-1] : en; 
        
      always_ff @(posedge clk) begin
        if (rst)
          mac_valid_r[reg_idx] <= 'b0;
        else
          mac_valid_r[reg_idx] <= valid_in;
      end   
    end
    
    for (reg_idx = 0; reg_idx < pPIPE_STAGE_NUM; reg_idx = reg_idx+1) begin
      logic valid_in;
      
      assign valid_in = reg_idx ? valid_r[reg_idx-1] : done; 
        
      always_ff @(posedge clk) begin
        if (rst)
          valid_r[reg_idx] <= 'b0;
        else
          valid_r[reg_idx] <= valid_in;
      end   
    end
  endgenerate
  
  always_ff @(posedge clk) begin
    if (rst)
      kernel_addr <= 'b0;
    else if (en)
      if (kernel_addr == pKERNEL_NUM-1)
        kernel_addr <= 'b0;
      else
        kernel_addr <= kernel_addr + 1'b1;
  end
  
  always_ff @(posedge clk) begin
    if (rst)
      out_feature <= 'b0;
    else if (mac_en)
      if (out_feature == pOUT_FEATURE/pOUTPUT_PARALLEL-1)
        out_feature <= 'b0;
      else
        out_feature <= out_feature + 1'b1;
  end
  
  assign pe_busy  = (out_feature == 0 && en) || out_feature != 0;
  assign pe_ready = !pe_busy;
  
  assign dsp_en   = en || mac_valid_r[0];
  assign adder_en = mac_valid_r[pADDER_STAGE_NUM-1];
  assign mac_en   = mac_valid_r[pMAC_PIPE_STAGE_NUM-1];
  
  assign dequant_en = valid_r[pDEQUAN_STAGE_NUM-1];
  assign bias_en    = valid_r[pBIAS_STAGE_NUM-1];
  
  if (pACTIVATION == "softmax") begin
    assign act_en     = 0;
    assign quant_en   = 0;
    assign buffer_en  = 0;
    assign valid      = valid_r[pACT_STAGE_NUM-1];
    assign pe_clr     = valid_r[pACT_STAGE_NUM-1];
  end
  else begin
    assign act_en     = valid_r[pACT_STAGE_NUM-1];
    assign quant_en   = valid_r[pQUANT_STAGE_NUM-1];
    assign buffer_en  = valid_r[pBUFFER_STAGE_NUM-1];
    assign valid      = valid_r[pVALID_STAGE_NUM-1];
    assign pe_clr     = valid_r[pVALID_STAGE_NUM-1];
  end
    
endmodule
