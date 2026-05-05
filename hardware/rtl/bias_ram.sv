`timescale 1ns/1ps

module bias_ram #(
   parameter  pWEIGHT_DATA_WIDTH  = 64
  ,parameter  pWEIGHT_BASE_ADDR   = 4000_0000
  
  ,parameter  pBIAS_NUM           = 32
  ,parameter  pBLOCK_RAM_NUM      = 32
)(
   input  logic                                         clk
  ,input  logic                                         rst
  ,input  logic                                         wr_en
  ,input  logic [31:0]                                  weight_addr
  ,input  logic [pWEIGHT_DATA_WIDTH-1:0]                weight_data
  ,input  logic [$clog2(pBIAS_NUM)-1:0]                 bias_addr
  ,output logic [pWEIGHT_DATA_WIDTH*pBLOCK_RAM_NUM-1:0] bias_data
);
  
  (* ram_style = "block" *)
  logic [pWEIGHT_DATA_WIDTH-1:0] bias_r [0:pBLOCK_RAM_NUM-1][0:pBIAS_NUM-1];
  logic [$clog2(pBLOCK_RAM_NUM)-1:0] ram_idx;
  logic cs;
  
  assign cs = weight_addr >= pWEIGHT_BASE_ADDR;
    
  always_ff @(posedge clk) begin
    if (rst || ram_idx == pBLOCK_RAM_NUM-1)
      ram_idx <= 'b0;
    else if (wr_en && cs)
      ram_idx <= ram_idx + 1'b1;
  end
  
  genvar idx;

  generate
    for (idx = 0; idx < pBLOCK_RAM_NUM; idx = idx+1) begin
      always_ff @(posedge clk) begin
        if (wr_en && idx == ram_idx)
          bias_r[idx][weight_addr - pWEIGHT_BASE_ADDR] <= weight_data;
        else
          bias_data[idx*pWEIGHT_DATA_WIDTH +: pWEIGHT_DATA_WIDTH] <= bias_r[idx][bias_addr];
      end
    end
  endgenerate

endmodule
