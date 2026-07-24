`timescale 1ns/1ps

module cnn_controller #(
   parameter  pINPUT_WIDTH  = 28
  ,parameter  pINPUT_HEIGHT = 28

  ,parameter  pKERNEL_SIZE  = 3
  ,parameter  pPADDING      = 1
  ,parameter  pSTRIDE       = 1
)(
   input  logic             clk
  ,input  logic             rst
  ,input  logic             en
  ,input  logic             data_valid
  ,input  logic             pe_ready
  ,output logic             rd_en
  ,output logic             is_padding
  ,output logic             buffer_en
  ,output logic             pe_en
  ,output logic             pe_padding
  ,output logic             done
);

  localparam pOUTPUT_WIDTH = pINPUT_WIDTH + 2*pPADDING - pKERNEL_SIZE + pSTRIDE;

  localparam pSTATE_WIDTH       = 2;
  localparam pSTATE_IDLE        = 2'b00;
  localparam pSTATE_COMPUTATION = 2'b01;

  logic [pSTATE_WIDTH-1:0] next_state;
  logic [pSTATE_WIDTH-1:0] curr_state_r;

  logic [$clog2(pINPUT_WIDTH):0] pe_cntr_r;
  logic computation;

  logic conv_en;
  logic row_en;

  logic [$clog2(pINPUT_WIDTH+2*pPADDING)-1:0] col_cntr_r;
  logic [$clog2(pINPUT_HEIGHT+2*pPADDING)-1:0] row_cntr_r;

  assign conv_en = (en || is_padding) && pe_ready ;
  
  assign pe_padding = (pe_cntr_r >= pOUTPUT_WIDTH-2) || (row_cntr_r >= pINPUT_HEIGHT + 2*pPADDING - 1);

  // column counter
  always_ff @(posedge clk) begin
    if (rst)
      col_cntr_r <= 'b0;
    else if (conv_en)
      if (col_cntr_r == pINPUT_WIDTH+2*pPADDING-1)
        col_cntr_r <= 'b0;
      else
        col_cntr_r <= col_cntr_r + 1'b1;
  end

  // row counter
  assign row_en = col_cntr_r == pINPUT_WIDTH+2*pPADDING-1 && pe_ready && conv_en;

  always_ff @(posedge clk) begin
    if (rst)
      row_cntr_r <= 'b0;
    else if (row_en)
      if (row_cntr_r == pINPUT_HEIGHT+2*pPADDING-1)
        row_cntr_r <= 'b0;
      else
        row_cntr_r <= row_cntr_r + 1'b1;
  end

              if (pPADDING == 0) begin
                // pe counter
                always_ff @(posedge clk) begin
                  if (rst || (row_cntr_r == 0 && col_cntr_r == 0))
                    pe_cntr_r <= 'b0;
                  else if (conv_en)
                    if (pe_cntr_r == pOUTPUT_WIDTH-1)
                      pe_cntr_r <= 'b0;
                    else if (computation)
                      pe_cntr_r <= pe_cntr_r + 1'b1;
                end
            
                // pe enable
                always_comb begin
                  case (curr_state_r)
                    pSTATE_IDLE         : next_state = (col_cntr_r == pKERNEL_SIZE-1 && row_cntr_r == pKERNEL_SIZE-1) && pe_ready ? pSTATE_COMPUTATION : pSTATE_IDLE;
                    pSTATE_COMPUTATION  : next_state = (col_cntr_r == pKERNEL_SIZE-2 && row_cntr_r == pKERNEL_SIZE-2) && pe_ready ? pSTATE_IDLE : pSTATE_COMPUTATION;
                  endcase
                end
            
                // current state
                always_ff @(posedge clk) begin
                  if (rst || (row_cntr_r == 0 && col_cntr_r == 0))
                    curr_state_r <= pSTATE_IDLE;
                  else if (conv_en)
                    curr_state_r <= next_state;
                end
              end
  else begin
    // pe counter
    always_ff @(posedge clk) begin
      if (rst)
        pe_cntr_r <= 'b0;
      else if (curr_state_r == pSTATE_IDLE)
        pe_cntr_r <= 'b0;
      else if (curr_state_r == pSTATE_COMPUTATION && pe_ready)
        pe_cntr_r <= pe_cntr_r + 1'b1;
    end

    // pe enable
    always_comb begin
      case (curr_state_r)
        pSTATE_IDLE         : next_state = (col_cntr_r == pKERNEL_SIZE-1 && pKERNEL_SIZE-1 <= row_cntr_r) && pe_ready ? pSTATE_COMPUTATION : pSTATE_IDLE;
        pSTATE_COMPUTATION  : next_state = (pe_cntr_r == pOUTPUT_WIDTH-1) && pe_ready ? pSTATE_IDLE : pSTATE_COMPUTATION;
        default             : next_state = curr_state_r;
      endcase
    end

    // current state
    always_ff @(posedge clk) begin
      if (rst)
        curr_state_r <= pSTATE_IDLE;
      //else if (conv_en)
      else
        curr_state_r <= next_state;
    end
  end

  assign computation = (curr_state_r == pSTATE_COMPUTATION) ? 1'b1 : 1'b0;

  // STRIDE
  if (pSTRIDE == 1) begin
    assign pe_en = computation;
  end
  else begin  // stride > 1
    logic [$clog2(pSTRIDE)-1:0] stride_col_cntr_r;
    logic [$clog2(pSTRIDE)-1:0] stride_row_cntr_r;
    logic stride_en;

    assign stride_en = pPADDING ? computation && conv_en : computation;

    always @(posedge clk) begin
      if (rst)
        stride_col_cntr_r <= 'b0;
      else if (computation && conv_en)
        if (stride_col_cntr_r == pSTRIDE-1)
          stride_col_cntr_r <= 'b0;
        else
          stride_col_cntr_r <= stride_col_cntr_r + 1'b1;
    end

    always @(posedge clk) begin
      if (rst)
        stride_row_cntr_r <= 'b0;
      else if (pe_cntr_r == pOUTPUT_WIDTH-1 && conv_en)
        if (stride_row_cntr_r == pSTRIDE-1)
          stride_row_cntr_r <= 'b0;
        else
          stride_row_cntr_r <= stride_row_cntr_r + 1'b1;
    end

    assign pe_en = computation && (stride_col_cntr_r == 0) && (stride_row_cntr_r == 0);
  end

  // PADDING
  if (pPADDING == 0)
    assign is_padding = 'b0;
  else
    assign is_padding = pe_ready && ( col_cntr_r <= pPADDING-1 || pINPUT_WIDTH+pPADDING-1 < col_cntr_r ||
                                      row_cntr_r <= pPADDING-1 || pINPUT_WIDTH+pPADDING-1 < row_cntr_r);

  assign rd_en = conv_en && !is_padding;

  always_ff @(posedge clk) begin
    if (rst)
      buffer_en <= 'b0;
    else
      buffer_en <= rd_en || is_padding;
  end

  //assign done = (col_cntr_r  == pINPUT_WIDTH+pPADDING*2-1) && (row_cntr_r == pINPUT_HEIGHT+pPADDING*2-1) && conv_en;
  assign done = (pe_cntr_r == pINPUT_WIDTH) && (row_cntr_r == 0);
  
  always @(posedge clk) begin
    if(done) begin
        col_cntr_r <= 0;
    end
  end


endmodule