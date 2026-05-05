`timescale 1ns/1ps

module pe_conv_mac_controller #(   
   parameter  pIN_CHANNEL       = 1
  ,parameter  pOUT_CHANNEL      = 32
  ,parameter  pKERNEL_SIZE      = 3
  
  ,parameter  pOUTPUT_PARALLEL  = 32
    
  ,parameter  pKERNEL_NUM       = 1024
  ,parameter  pBIAS_NUM         = 32
  
  // activation type (relu, sigmoid)
  ,parameter  pACTIVATION         = "sigmoid"
)(
   input  logic                                             clk
  ,input  logic                                             rst
  ,input  logic                                             en
  ,input  logic                                             conv_en
  ,input  logic                                             buffer_valid
  ,output logic [$clog2(pKERNEL_SIZE*pKERNEL_SIZE)-1:0]     pixel
  ,output logic [$clog2(pKERNEL_NUM)-1:0]                   kernel_addr
  ,output logic [$clog2(pBIAS_NUM)-1:0]                     bias_addr
  ,output logic [$clog2(pOUT_CHANNEL/pOUTPUT_PARALLEL)-1:0] buffer_idx
  ,output logic                                             pe_ready
  ,output logic                                             pe_clr
  ,output logic                                             datapath_buffer_en
  ,output logic                                             adder_en
  ,output logic                                             dequant_en
  ,output logic                                             bias_en
  ,output logic                                             act_en
  ,output logic                                             quant_en
  ,output logic                                             buffer_en
  ,output logic                                             valid
);

  localparam pPE_CLR_STAGE_NUM        = 1; 
  localparam pMAC_PIPE_STAGE_NUM      = 7;
  localparam pDEQUANT_PIPE_STAGE_NUM  = 1;
  localparam pBIAS_PIPE_STAGE_NUM     = 1;
  localparam pQUANT_PIPE_STAGE_NUM    = 1;
  localparam pSIGMOID_PIPE_STAGE_NUM  = 1;
  localparam pRELU_PIPE_STAGE_NUM     = 1;
  
  localparam pADDER_PIPE_STAGE_NUM = $clog2(pIN_CHANNEL) + 1;
  localparam pACT_PIPE_STAGE_NUM =  pACTIVATION == "sigmoid"  ? pSIGMOID_PIPE_STAGE_NUM :
                                    pACTIVATION == "relu"     ? pRELU_PIPE_STAGE_NUM    : 'b0;
  localparam pPIPE_STAGE_NUM = pMAC_PIPE_STAGE_NUM + pADDER_PIPE_STAGE_NUM + pDEQUANT_PIPE_STAGE_NUM +
                               pBIAS_PIPE_STAGE_NUM + pACT_PIPE_STAGE_NUM + pQUANT_PIPE_STAGE_NUM + 1;
  
  localparam pADDER_STAGE_NUM   = pMAC_PIPE_STAGE_NUM;
  localparam pDEQUAN_STAGE_NUM  = pADDER_STAGE_NUM  + pADDER_PIPE_STAGE_NUM;
  localparam pBIAS_STAGE_NUM    = pDEQUAN_STAGE_NUM + pDEQUANT_PIPE_STAGE_NUM;
  localparam pACT_STAGE_NUM     = pBIAS_STAGE_NUM   + pBIAS_PIPE_STAGE_NUM;
  localparam pQUANT_STAGE_NUM   = pACT_STAGE_NUM    + pACT_PIPE_STAGE_NUM;
  localparam pBUFFER_STAGE_NUM  = pQUANT_STAGE_NUM  + pQUANT_PIPE_STAGE_NUM;
  localparam pVALID_STAGE_NUM   = pBUFFER_STAGE_NUM + 1; 

  logic [$clog2(pOUT_CHANNEL/pOUTPUT_PARALLEL):0] out_channel;
  logic [$clog2(pKERNEL_SIZE*pKERNEL_SIZE+pMAC_PIPE_STAGE_NUM)-1:0] cntr_r;
  logic [pPIPE_STAGE_NUM-1:0] valid_r;
  //logic pixel_en;
  logic pe_busy;
  logic my_datapath_buffer_en;
  
  logic valid_0_be;
  logic valid_0_pos;
  
  assign valid_0_pos = !valid_0_be && valid_r[0];
  
  logic valid_en;
  
  always @(posedge clk) begin
    if(rst) begin
        valid_en <= 0;
        valid_0_be <= 0;
    end
    else begin
        valid_0_be <= valid_r[0];
        if(buffer_valid) valid_en <= 1;
        if(valid_r[0]) valid_en <= 0;
    end
  end
  
  genvar reg_idx;
  
  logic my_pe_ready;
  
  assign my_pe_ready = pe_ready && conv_en;
  
  generate
    for (reg_idx = 0; reg_idx < pPIPE_STAGE_NUM; reg_idx = reg_idx+1) begin
      logic valid_in;
      
      assign valid_in = reg_idx ? valid_r[reg_idx-1] : cntr_r == pKERNEL_SIZE*pKERNEL_SIZE-1 && en && valid_en; 
        
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
      cntr_r <= 'b0;
    else if (en || cntr_r != 0)
      if (cntr_r == pKERNEL_SIZE*pKERNEL_SIZE)
        cntr_r <= 'b0;
      else if (!buffer_valid)
        cntr_r <= cntr_r + 1'b1;    
  end
  
//  always_ff @(posedge clk) begin
//    if (rst)
//      pixel_en <= 'b0;
//    else
//      pixel_en <= en;
//  end
  
  always_ff @(posedge clk) begin
    if (rst)
      out_channel <= 'b0;
    else if (cntr_r == pKERNEL_SIZE*pKERNEL_SIZE)
      if (out_channel == pOUT_CHANNEL/pOUTPUT_PARALLEL-1)
        out_channel <= 'b0;
      else
        out_channel <= out_channel + 1'b1;
  end

  always_ff @(posedge clk) begin
    if (rst)
      pixel <= 'b0;
    else if (pixel == pKERNEL_SIZE*pKERNEL_SIZE-1)
      pixel <= 'b0;
    else if (cntr_r == pKERNEL_SIZE*pKERNEL_SIZE || buffer_valid)
      pixel <= pixel;
    else if (en)   
      pixel <= pixel + 1'b1;
  end
  
  always_ff @(posedge clk) begin
    if (rst)
      kernel_addr <= 'b0;
    else if (en)
      if (kernel_addr == pKERNEL_NUM-1)
        kernel_addr <= 'b0;
      else if (cntr_r == pKERNEL_SIZE*pKERNEL_SIZE || buffer_valid)
        kernel_addr <= kernel_addr;
      else
        kernel_addr <= kernel_addr + 1'b1;
  end
  
  always_ff @(posedge clk) begin
    if (rst)
      bias_addr <= 'b0;
    else if (bias_en)
      if (bias_addr == pBIAS_NUM-1)
        bias_addr <= 'b0;
      else   
        bias_addr <= bias_addr + 1'b1;
  end
  
  always_ff @(posedge clk) begin
    if (rst)
      buffer_idx <= 'b0;
    else if (valid_r[pVALID_STAGE_NUM-1])
      if (buffer_idx == pOUT_CHANNEL/pOUTPUT_PARALLEL-1)
        buffer_idx <= 'b0;
      else
        buffer_idx <= buffer_idx + 'b1;
  end
  
  assign pe_busy = ((pixel != 0 && (pixel != pKERNEL_SIZE*pKERNEL_SIZE-1 || out_channel != pOUT_CHANNEL/pOUTPUT_PARALLEL-1)) || pixel == 'b0) && en;
  assign pe_ready = !pe_busy && conv_en;
  
  assign datapath_buffer_en = pixel == 'b0 && cntr_r == 'b0;
  
  assign pe_clr     = valid_r[pADDER_STAGE_NUM-1];
  assign adder_en   = valid_r[pADDER_STAGE_NUM-1];
  assign dequant_en = valid_r[pDEQUAN_STAGE_NUM-1];
  assign bias_en    = valid_r[pBIAS_STAGE_NUM-1];
  assign act_en     = valid_r[pACT_STAGE_NUM-1];
  assign quant_en   = valid_r[pQUANT_STAGE_NUM-1];
  assign buffer_en  = valid_r[pBUFFER_STAGE_NUM-1];
  assign valid      = valid_r[pVALID_STAGE_NUM-1] && buffer_idx == pOUT_CHANNEL/pOUTPUT_PARALLEL-1;
  
endmodule
