`timescale 1ns/1ps

module linear_controller #(
   parameter  pIN_FEATURE       = 14*14*32
  ,parameter  pOUT_FEATURE      = 128
  
  ,parameter  pCHANNEL          = 32
  ,parameter  pOUTPUT_PARALLEL  = 4
)(
   input  logic             clk
  ,input  logic             rst
  ,input  logic             en
  ,input  logic             data_valid
  ,input  logic             pe_ready
  ,output logic             rd_en
  ,output logic             pe_en
  ,output logic             done
);

  localparam pSTATE_WIDTH       = 2;
  localparam pSTATE_IDLE        = 2'b00;
  localparam pSTATE_COMPUTATION = 2'b01;
  
  logic [pSTATE_WIDTH-1:0] next_state;
  logic [pSTATE_WIDTH-1:0] curr_state_r;

  logic [$clog2(pIN_FEATURE/pCHANNEL)-1:0] cntr_r;
  logic [$clog2(pOUT_FEATURE/pOUTPUT_PARALLEL)-1:0] out_feature_r;

  // counter
  always_ff @(posedge clk) begin
    if (rst)
      cntr_r <= 'b0;
    else if (cntr_r == pIN_FEATURE/pCHANNEL-1 && out_feature_r == pOUT_FEATURE/pOUTPUT_PARALLEL-1)
      cntr_r <= 'b0;
    else if (out_feature_r == pOUT_FEATURE/pOUTPUT_PARALLEL-1)
      cntr_r <= cntr_r + 1'b1;
  end
  
  // out feature
  always_ff @(posedge clk) begin
    if (rst)
      out_feature_r <= 'b0;
    else if (curr_state_r == pSTATE_COMPUTATION)
      out_feature_r <= out_feature_r + 1'b1;
    else if (curr_state_r == pSTATE_IDLE)
      out_feature_r <= 'b0; 
  end
  
  // next state 
  always_comb begin
    case (curr_state_r)
      pSTATE_IDLE         : next_state = data_valid ? pSTATE_COMPUTATION : pSTATE_IDLE;
      pSTATE_COMPUTATION  : next_state = out_feature_r == pOUT_FEATURE/pOUTPUT_PARALLEL-1 ? pSTATE_IDLE : pSTATE_COMPUTATION;
    endcase
  end
  
  // current state
  always_ff @(posedge clk) begin
    if (rst)
      curr_state_r <= pSTATE_IDLE;
    else
      curr_state_r <= next_state;
  end
  
  assign rd_en = en && out_feature_r == 'b0 && curr_state_r == pSTATE_IDLE && !data_valid;
  assign pe_en = curr_state_r == pSTATE_COMPUTATION;
  assign done = cntr_r == pIN_FEATURE/pCHANNEL-1 && out_feature_r == pOUT_FEATURE/pOUTPUT_PARALLEL-1;

endmodule
