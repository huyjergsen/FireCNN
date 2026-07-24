`timescale 1ns/1ps

module adder_tree #(
   parameter  pDATA_WIDTH     = 32
  ,parameter  pINPUT_NUM      = 32
)( 
   input  logic                               clk
  ,input  logic                               rst
  ,input  logic                               en
  ,input  logic [pDATA_WIDTH*pINPUT_NUM-1:0]  data_in
  ,output logic [pDATA_WIDTH-1:0]             data_out
);

  localparam pADDER_STAGE_NUM = $clog2(pINPUT_NUM) + 1;
   
  logic signed [pDATA_WIDTH-1:0] adder_out_r [0:pADDER_STAGE_NUM-1][0:pINPUT_NUM-1];
  logic [pADDER_STAGE_NUM-1:0] valid_r;

  genvar stage_idx;
  genvar reg_idx;
  
  generate
    for (stage_idx = 0; stage_idx < pADDER_STAGE_NUM; stage_idx = stage_idx+1) begin : stage_loop
      localparam SHIFT_AMT = (stage_idx == 0) ? 0 : (stage_idx - 1);
      localparam pPRE_STAGE_REG_NUM = (stage_idx == 0) ? (pINPUT_NUM * 2) : 
                                      ((pINPUT_NUM + (1 << SHIFT_AMT) - 1) >> SHIFT_AMT);    
      localparam pCURR_STAGE_REG_NUM = ((pINPUT_NUM + (1 << stage_idx) - 1) >> stage_idx);
      
      logic valid_in;
      
      if (stage_idx) begin : gen_val_n
        assign valid_in = valid_r[stage_idx-1];
      end else begin : gen_val0
        assign valid_in = en;
      end
    
      always_ff @(posedge clk) begin
        if (rst)
          valid_r[stage_idx] <= 1'b0;
        else if (valid_in)
          valid_r[stage_idx] <= 1'b1;
      end       
                  
      for (reg_idx = 0; reg_idx < pCURR_STAGE_REG_NUM; reg_idx = reg_idx+1) begin : reg_loop
        logic signed [pDATA_WIDTH-1:0] adder_in;
      
        if (stage_idx == 0) begin : gen_st0
          assign adder_in = data_in[reg_idx*pDATA_WIDTH +: pDATA_WIDTH];
        end else begin : gen_st_n
          if (reg_idx*2 == pPRE_STAGE_REG_NUM-1) begin : gen_odd
            assign adder_in = adder_out_r[stage_idx-1][reg_idx*2];
          end else begin : gen_even
            assign adder_in = adder_out_r[stage_idx-1][reg_idx*2] + adder_out_r[stage_idx-1][reg_idx*2+1];
          end
        end
          
        always_ff @(posedge clk) begin
          if (rst)
            adder_out_r[stage_idx][reg_idx] <= 'b0;
          else if (valid_in)
            adder_out_r[stage_idx][reg_idx] <= adder_in;
        end
      end
    end
  endgenerate

  assign data_out = adder_out_r[pADDER_STAGE_NUM-1][0];

endmodule
