`timescale 1ns/1ps

module pe_conv_mac_datapath #(
   parameter  pDATA_WIDTH         = 8
   
  ,parameter  pIN_CHANNEL         = 1
  ,parameter  pOUT_CHANNEL        = 32
  
  ,parameter  pULTRA_RAM_NUM      = 4
  ,parameter  pBLOCK_RAM_NUM      = 4
  ,parameter  pKERNEL_NUM         = 1024
  ,parameter  pBIAS_NUM           = 32
  
  ,parameter  pOUTPUT_PARALLEL    = 32
  
  // weights
  ,parameter  pKERNEL_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 4000_0000

  // activation type (relu, sigmoid)
  ,parameter  pACTIVATION         = "relu"
)(
   input  logic                                     clk
  ,input  logic                                     rst
  ,input  logic                                     clr
  
  ,input  logic                                     load_weight
  ,input  logic [31:0]                              weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]            weight_data
  
  ,input  logic [$clog2(pKERNEL_NUM)-1:0]           kernel_addr
  ,input  logic [$clog2(pBIAS_NUM)-1:0]             bias_addr
  
  ,input  logic                                     en
  ,input  logic                                     adder_en
  ,input  logic                                     dequant_en
  ,input  logic                                     bias_en
  ,input  logic                                     act_en
  ,input  logic                                     quant_en
  
  ,input  logic [pDATA_WIDTH*pIN_CHANNEL-1:0]       data_in
  ,output logic [pDATA_WIDTH*pOUTPUT_PARALLEL-1:0]  data_out
);
  
  localparam pBIAS_BASE_ADDR = pWEIGHT_BASE_ADDR + pKERNEL_NUM;
  localparam pSCALE_ADDR = pBIAS_BASE_ADDR + pBIAS_NUM;

  // weights
  logic signed [pIN_CHANNEL*pOUTPUT_PARALLEL-1:0][pDATA_WIDTH-1:0] kernel_data;
  logic signed [pOUTPUT_PARALLEL-1:0][31:0] bias_data;
  logic signed [63:0] dequant_scale_r;
  logic signed [pIN_CHANNEL-1:0][31:0] mac_out [0:pOUTPUT_PARALLEL-1];
  
  //(* ram_style = "distributed" *)
  logic signed [31:0] adder_out [0:pOUTPUT_PARALLEL-1];
  logic signed [31:0] dequant_out [0:pOUTPUT_PARALLEL-1];
  logic signed [31:0] bias_out [0:pOUTPUT_PARALLEL-1];
  logic signed [31:0] act_out [0:pOUTPUT_PARALLEL-1];
  logic signed [7:0] quant_out [0:pOUTPUT_PARALLEL-1];   

  kernel_ram #(
     .pWEIGHT_DATA_WIDTH  ( pKERNEL_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
    ,.pKERNEL_NUM         ( pKERNEL_NUM         )
    ,.pULTRA_RAM_NUM      ( pULTRA_RAM_NUM      )
  ) u_kernel (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.wr_en       ( load_weight )
    ,.weight_addr ( weight_addr )
    ,.weight_data ( weight_data )
    ,.kernel_addr ( kernel_addr )
    ,.kernel_data ( kernel_data )
  );
  
  always_ff @(posedge clk) begin
    if (load_weight && weight_addr == pSCALE_ADDR)
      dequant_scale_r <= weight_data;
  end
  
  genvar in_channel_idx;
  genvar out_channel_idx;
 
  generate
    if (pOUT_CHANNEL/pOUTPUT_PARALLEL == 1) begin
      logic signed [pBIAS_BASE_ADDR+pOUT_CHANNEL/2-1:pBIAS_BASE_ADDR][1:0][31:0] bias_data_r;
      
      always_ff @(posedge clk) begin
        if (load_weight)
          bias_data_r[weight_addr] <= weight_data;
      end
      
      assign bias_data = bias_data_r;
    end
    else begin
      bias_ram #(
         .pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
        ,.pWEIGHT_BASE_ADDR   ( pBIAS_BASE_ADDR     )
        ,.pBIAS_NUM           ( pBIAS_NUM           )
        ,.pBLOCK_RAM_NUM      ( pBLOCK_RAM_NUM      )
      ) u_bias (
         .clk         ( clk         )
        ,.rst         ( rst         )
        ,.wr_en       ( load_weight )
        ,.weight_addr ( weight_addr )
        ,.weight_data ( weight_data )
        ,.bias_addr   ( bias_addr   )
        ,.bias_data   ( bias_data   )
      );
    end
    
    for (out_channel_idx = 0; out_channel_idx < pOUTPUT_PARALLEL; out_channel_idx = out_channel_idx+1) begin
      if (out_channel_idx % 2 == 0) begin      
        for (in_channel_idx = 0; in_channel_idx < pIN_CHANNEL; in_channel_idx = in_channel_idx+1) begin  
          logic signed [15:0] dsp_out [0:1];
          logic mac_en;
        
          dsp_dual_mult u_dsp (
             .clk       ( clk                                                         )
            ,.rst       ( rst                                                         )
            ,.en        ( en                                                          )
            ,.a         ( kernel_data[pIN_CHANNEL*out_channel_idx+in_channel_idx]     )
            ,.b         ( kernel_data[pIN_CHANNEL*(out_channel_idx+1)+in_channel_idx] )
            ,.c         ( data_in[pDATA_WIDTH*in_channel_idx +: pDATA_WIDTH]          )
            ,.ac        ( dsp_out[0]                                                  )
            ,.bc        ( dsp_out[1]                                                  )
            ,.valid_out ( mac_en                                                      )
          );
          
          always_ff @(posedge clk) begin
            if (rst || clr) begin
              mac_out[out_channel_idx][in_channel_idx] <= 'b0;
              mac_out[out_channel_idx+1][in_channel_idx] <= 'b0;
            end
            else if (mac_en) begin
              mac_out[out_channel_idx][in_channel_idx] <= mac_out[out_channel_idx][in_channel_idx] + {{16{dsp_out[0][15]}}, dsp_out[0]};
              mac_out[out_channel_idx+1][in_channel_idx] <= mac_out[out_channel_idx+1][in_channel_idx] + {{16{dsp_out[1][15]}}, dsp_out[1]};
            end
          end // always        
        end // for in_channel_idx
      end // if out_channel_idx % 2 == 0
    
      adder_tree #(
         .pDATA_WIDTH ( 32          )
        ,.pINPUT_NUM  ( pIN_CHANNEL ) 
      ) u_adder_tree (
         .clk       ( clk                         )
        ,.rst       ( rst                         )
        ,.en        ( adder_en                    )
        ,.data_in   ( mac_out[out_channel_idx]    )
        ,.data_out  ( adder_out[out_channel_idx]  )
      );
    
      dequantize u_dequantize (
         .clk       ( clk                           )
        ,.rst       ( rst                           )
        ,.en        ( dequant_en                    )
        ,.scale     ( dequant_scale_r[31:0]         )
        ,.data_in   ( adder_out[out_channel_idx]    )
        ,.data_out  ( dequant_out[out_channel_idx]  )
      );
  
      always_ff @(posedge clk) begin
        if (rst)
          bias_out[out_channel_idx] <= 'b0;
        else if (bias_en)
            bias_out[out_channel_idx] <= dequant_out[out_channel_idx] + bias_data[out_channel_idx];
      end
      
      if (pACTIVATION == "sigmoid")
        sigmoid #(
           .pDATA_WIDTH ( 32  )
          ,.pFRAC_NUM   ( 16  )
        ) u_sigmoid (
           .clk       ( clk                       )
          ,.rst       ( rst                       )
          ,.en        ( act_en                    )
          ,.data_in   ( bias_out[out_channel_idx] )
          ,.data_out  ( act_out[out_channel_idx]  )
        );
      else if (pACTIVATION == "relu")
        relu #(
           .pDATA_WIDTH ( 32  )
        ) u_relu (
           .clk       ( clk                       )
          ,.rst       ( rst                       )
          ,.en        ( act_en                    )
          ,.data_in   ( bias_out[out_channel_idx] )
          ,.data_out  ( act_out[out_channel_idx]  )
        );
      else
        always_ff @(posedge clk) begin
          if (rst)
            act_out[out_channel_idx] <= 'b0;
          else
            act_out[out_channel_idx] <= bias_out[out_channel_idx];
        end
    
      quantize u_quantize (
         .clk       ( clk                         )
        ,.rst       ( rst                         )
        ,.en        ( quant_en                    )
        ,.data_in   ( act_out[out_channel_idx]    )
        ,.data_out  ( quant_out[out_channel_idx]  )
      );
      
      assign data_out[out_channel_idx*pDATA_WIDTH +: pDATA_WIDTH] = quant_out[out_channel_idx];
    end // for out_channel_idx
  endgenerate
    
endmodule