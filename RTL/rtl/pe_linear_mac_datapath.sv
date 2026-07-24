`timescale 1ns/1ps

module pe_linear_mac_datapath #(
   parameter  pDATA_WIDTH         = 8

  ,parameter  pIN_FEATURE         = 14*14*32
  ,parameter  pOUT_FEATURE        = 128

  ,parameter  pCHANNEL            = 32
  ,parameter  pOUTPUT_PARALLEL    = 4

  ,parameter  pBLOCK_RAM_NUM      = 16
  ,parameter  pKERNEL_NUM         = 4000
  ,parameter  pBIAS_NUM           = 32

  ,parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 4000_0000

  // activation type (relu, sigmoid)
  ,parameter  pACTIVATION         = "sigmoid"

  ,localparam pOUTPUT_WIDTH       = pACTIVATION == "softmax" ? 32*pOUT_FEATURE : pDATA_WIDTH*pOUT_FEATURE
)(
   input  logic                                             clk
  ,input  logic                                             rst
  ,input  logic                                             clr

  ,input  logic                                             load_weight
  ,input  logic [31:0]                                      weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]                    weight_data

  ,input  logic [$clog2(pKERNEL_NUM)-1:0]                   kernel_addr
  ,input  logic [$clog2(pOUT_FEATURE/pOUTPUT_PARALLEL)-1:0] out_feature

  ,input  logic                                             dsp_en
  ,input  logic                                             mac_en
  ,input  logic                                             adder_en
  ,input  logic                                             dequant_en
  ,input  logic                                             bias_en
  ,input  logic                                             act_en
  ,input  logic                                             quant_en

  ,input  logic [pDATA_WIDTH*pCHANNEL-1:0]                  data_in
  ,output logic [pOUTPUT_WIDTH-1:0]                         data_out
);

  localparam pBIAS_BASE_ADDR = pWEIGHT_BASE_ADDR + pKERNEL_NUM;
  localparam pSCALE_ADDR = pBIAS_BASE_ADDR + ((pBIAS_NUM + 1) / 2);

  // weights
  logic signed [pCHANNEL*pOUTPUT_PARALLEL-1:0][pDATA_WIDTH-1:0] kernel_data;
  logic signed [pBIAS_BASE_ADDR+((pOUT_FEATURE + 1) / 2)-1:pBIAS_BASE_ADDR][1:0][31:0] bias_data_r;
  logic signed [pOUT_FEATURE-1:0][31:0] bias_data;
  logic signed [63:0] dequant_scale_r;

  // mac buffer
  logic signed [31:0] adder_out [0:pOUTPUT_PARALLEL-1];
  logic signed [31:0] mac_buffer_r [0:pOUT_FEATURE-1];
  logic signed [31:0] dequant_out [0:pOUT_FEATURE-1];
  logic signed [31:0] bias_out_r [0:pOUT_FEATURE-1];
  logic signed [31:0] act_out [0:pOUT_FEATURE-1];
  logic signed [7:0] quant_out [0:pOUT_FEATURE-1];

  weight_ram #(
     .pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
    ,.pKERNEL_NUM         ( pKERNEL_NUM         )
    ,.pBLOCK_RAM_NUM      ( pBLOCK_RAM_NUM      )
  ) u_weight (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.wr_en       ( load_weight )
    ,.weight_addr ( weight_addr )
    ,.weight_data ( weight_data )
    ,.kernel_addr ( kernel_addr )
    ,.kernel_data ( kernel_data )
  );

  always_ff @(posedge clk) begin
    if (load_weight)
      bias_data_r[weight_addr] <= weight_data;
  end

  assign bias_data = bias_data_r;

  always_ff @(posedge clk) begin
    if (load_weight && weight_addr == pSCALE_ADDR)
      dequant_scale_r <= weight_data;
  end

  genvar in_feature_idx;
  genvar out_feature_idx;
  genvar ratio;

  generate
    for (out_feature_idx = 0; out_feature_idx < pOUTPUT_PARALLEL; out_feature_idx = out_feature_idx+1) begin
      logic signed [pCHANNEL-1:0][31:0] mac_out;
     

      for (in_feature_idx = 0; in_feature_idx < pCHANNEL; in_feature_idx = in_feature_idx+1) begin
        logic [7:0] data_a;
        assign data_a = data_in[in_feature_idx*pDATA_WIDTH +: pDATA_WIDTH];
        dsp_single_mult u_dsp (
           .clk     ( clk                                                   )
          ,.rst     ( rst || clr                                            )
          ,.en      ( dsp_en                                                )
          ,.a       ( data_in[in_feature_idx*pDATA_WIDTH +: pDATA_WIDTH]    )
          ,.b       ( kernel_data[out_feature_idx*pCHANNEL+in_feature_idx]  )
          ,.c       ( mac_out[in_feature_idx]                               )
        );
      end // for in_feature_idx

      adder_tree #(
         .pDATA_WIDTH ( 32        )
        ,.pINPUT_NUM  ( pCHANNEL  )
      ) u_adder_tree (
         .clk       ( clk                         )
        ,.rst       ( rst || clr                  )
        ,.en        ( adder_en                    )
        ,.data_in   ( mac_out                     )
        ,.data_out  ( adder_out[out_feature_idx]  )
      );
    end // out_feature_idx

    for (ratio = 0; ratio <= pOUT_FEATURE/pOUTPUT_PARALLEL; ratio = ratio+1) begin
      for (out_feature_idx = 0; out_feature_idx < pOUTPUT_PARALLEL; out_feature_idx = out_feature_idx+1) begin
        always_ff @(posedge clk) begin
          if (rst || clr)
            mac_buffer_r[ratio*pOUTPUT_PARALLEL + out_feature_idx] <= 'b0;
          else if (mac_en && ratio == out_feature)
            mac_buffer_r[ratio*pOUTPUT_PARALLEL + out_feature_idx] <= mac_buffer_r[ratio*pOUTPUT_PARALLEL + out_feature_idx] + adder_out[out_feature_idx];
        end // always mac_buffer_r
      end // for out_feature_idx
    end // for ratio

    for (out_feature_idx = 0; out_feature_idx < pOUT_FEATURE; out_feature_idx = out_feature_idx+1) begin
      dequantize u_dequantize (
         .clk       ( clk                           )
        ,.rst       ( rst                           )
        ,.en        ( dequant_en                    )
        ,.scale     ( dequant_scale_r[31:0]         )
        ,.data_in   ( mac_buffer_r[out_feature_idx] )
        ,.data_out  ( dequant_out[out_feature_idx]  )
      );  // dequantize

      always_ff @(posedge clk) begin
        if (rst)
          bias_out_r[out_feature_idx] <= 'b0;
        else if (bias_en)
          bias_out_r[out_feature_idx] <= dequant_out[out_feature_idx] + bias_data[out_feature_idx];
      end // bias

      if (pACTIVATION == "sigmoid")
        sigmoid #(
           .pDATA_WIDTH ( 32  )
          ,.pFRAC_NUM   ( 16  )
        ) u_sigmoid (
           .clk       ( clk                         )
          ,.rst       ( rst                         )
          ,.en        ( act_en                      )
          ,.data_in   ( bias_out_r[out_feature_idx] )
          ,.data_out  ( act_out[out_feature_idx]    )
        );  // sigmoid
      else if (pACTIVATION == "relu")
        relu #(
           .pDATA_WIDTH ( 32  )
        ) u_relu (
           .clk       ( clk                         )
          ,.rst       ( rst                         )
          ,.en        ( act_en                      )
          ,.data_in   ( bias_out_r[out_feature_idx] )
          ,.data_out  ( act_out[out_feature_idx]    )
        );  // relu
      else if (pACTIVATION != "softmax")
        assign act_out[out_feature_idx] = bias_out_r[out_feature_idx];

      if (pACTIVATION == "softmax") begin
        assign data_out[out_feature_idx*32 +: 32] = bias_out_r[out_feature_idx];
      end
      else begin
        quantize u_quantize (
           .clk       ( clk                         )
          ,.rst       ( rst                         )
          ,.en        ( quant_en                    )
          ,.data_in   ( act_out[out_feature_idx]    )
          ,.data_out  ( quant_out[out_feature_idx]  )
        );  // quantize
        assign data_out[out_feature_idx*pDATA_WIDTH +: pDATA_WIDTH] = quant_out[out_feature_idx];
      end
    end // out_feature_idx

  endgenerate

endmodule
