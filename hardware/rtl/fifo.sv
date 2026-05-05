`timescale 1ns/1ps

module fifo #(
   parameter  pDATA_WIDTH = 8
  ,parameter  pDEPTH      = 1024
)(
   input  logic                   clk
  ,input  logic                   rst
  ,input  logic                   wr_en
  ,input  logic                   rd_en
  ,input  logic [pDATA_WIDTH-1:0] wr_data
  ,input  logic                   rst_count
  
  ,output logic [pDATA_WIDTH-1:0] rd_data
  ,output logic                   full
  ,output logic                   empty
  ,output logic                   valid
);

  localparam pADDR_WIDTH = $clog2(pDEPTH);
  
  // For debug, unsynthesisable
  
  logic [pDATA_WIDTH-1:0] debug_data_reg [pDEPTH];
  logic [pDATA_WIDTH-1:0] debug_data;
  logic [14:0] debug_data_num;
  
  (* ram_style = "block" *)
  logic [pDATA_WIDTH-1:0] mem_r [0:pDEPTH-1];
  logic [pADDR_WIDTH:0] counter_r;
  logic [pADDR_WIDTH-1:0] wr_ptr_r;
  logic [pADDR_WIDTH-1:0] rd_ptr_r;
  logic [15:0] count_fifo_data; 
  logic [15:0] count_wr; 
  
  logic rst_count_r;
  always @(posedge clk) begin
    rst_count_r <= rst_count;
  end
  
  
  always_ff @(posedge clk) begin
    if (rst) begin
      rd_data <= 'b0;
      count_fifo_data <= 'b0;
    end
    else begin
      if (wr_en && !full)
        mem_r[wr_ptr_r] <= wr_data;
      if (rd_en)
        rd_data <= mem_r[rd_ptr_r];
    end    
  end
  
  always_ff @(posedge clk) begin
    if (rst)
      valid <= 'b0;
    else
      valid <= rd_en;
  end
  
  // counter used for empty and full signal
  always_ff @(posedge clk) begin
    if (rst) begin
      counter_r <= 'b0;
    end
    else
      if ((wr_en && !full) && (rd_en && !empty)) begin
        counter_r <= counter_r;
      end
      else if (wr_en && !full)
      begin
        counter_r <= counter_r + 1'b1;
      end
      else if (rd_en && !empty)
        counter_r <= counter_r -  1'b1;
      else
        counter_r <= counter_r;
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      count_wr <= 0;
    end
    else
      if (wr_en)
      count_wr <= count_wr + 1;;
  end
  
  // read write pointer use for write and read data
  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr_r <= 'b0;
      rd_ptr_r <= 'b0;
    end else begin
      if (wr_en && !full)
        wr_ptr_r <= wr_ptr_r + 1'b1;
      else
        wr_ptr_r <= wr_ptr_r;
         
      if (rd_en && !empty)
        rd_ptr_r <= rd_ptr_r + 1'b1;
      else
        rd_ptr_r <= rd_ptr_r;
    end
  end

  always_ff @(posedge clk) begin
    if(rst_count == 1 && rst_count_r == 0) count_fifo_data <= 0;
    else begin
        if(wr_en == 1) count_fifo_data <= count_fifo_data + 1;
    end
  end

  assign full = counter_r == pDEPTH;
  assign empty = counter_r == 0;
  
endmodule
