`timescale 1ns/1ps

module max_tree #(
   parameter  pDATA_WIDTH     = 32
  ,parameter  pINPUT_NUM      = 32
  
  ,parameter  pMAX_INDEX      = 0
)( 
   input  logic                               clk
  ,input  logic                               rst
  ,input  logic                               en
  ,input  logic [pDATA_WIDTH*pINPUT_NUM-1:0]  data_in
  ,output logic [pDATA_WIDTH-1:0]             data_out
  ,output logic                               valid
);

  localparam pSTAGE_NUM = $clog2(pINPUT_NUM) + 1;
  localparam pMAX_OUT_WIDTH = pMAX_INDEX ? $clog2(pINPUT_NUM)+pDATA_WIDTH : pDATA_WIDTH;
  
  logic [pMAX_OUT_WIDTH-1:0] max_out_r [0:pSTAGE_NUM-1][0:pINPUT_NUM-1];
  
  logic [pSTAGE_NUM-1:0] valid_r;

  genvar stage_idx;
  genvar reg_idx;
  
  generate
    for (stage_idx = 0; stage_idx < pSTAGE_NUM; stage_idx = stage_idx+1) begin : stage_loop
      localparam SHIFT_AMT = (stage_idx == 0) ? 0 : (stage_idx - 1);
      localparam pPRE_STAGE_REG_NUM = (stage_idx == 0) ? (pINPUT_NUM * 2) : 
                                      ((pINPUT_NUM + (1 << SHIFT_AMT) - 1) >> SHIFT_AMT);    
      localparam pCURR_STAGE_REG_NUM = ((pINPUT_NUM + (1 << stage_idx) - 1) >> stage_idx);
      
      logic valid_in;
      if (stage_idx == 0) begin : gen_val0
        assign valid_in = en;
      end else begin : gen_val_n
        assign valid_in = valid_r[stage_idx-1];
      end
    
      always_ff @(posedge clk) begin
        if (rst)
          valid_r[stage_idx] <= 'b0;
        else
          valid_r[stage_idx] <= valid_in;
      end       
                  
      for (reg_idx = 0; reg_idx < pCURR_STAGE_REG_NUM; reg_idx = reg_idx+1) begin : reg_loop
        logic [pMAX_OUT_WIDTH-1:0] max_in;
        logic [$clog2(pINPUT_NUM)-1:0] idx; 
        
        assign idx = reg_idx;
        if (stage_idx == 0) begin : gen_st0
          assign max_in = {idx, data_in[reg_idx*pDATA_WIDTH +: pDATA_WIDTH]};
        end else begin : gen_st_n
          if (reg_idx*2 == pPRE_STAGE_REG_NUM-1) begin : gen_odd
            assign max_in = max_out_r[stage_idx-1][reg_idx*2];
          end else begin : gen_even
            logic signed [pDATA_WIDTH-1:0] a;
            logic signed [pDATA_WIDTH-1:0] b;
            
            assign a = max_out_r[stage_idx-1][reg_idx*2][pDATA_WIDTH-1:0];
            assign b = max_out_r[stage_idx-1][reg_idx*2+1][pDATA_WIDTH-1:0];
            
            assign max_in = a > b ? max_out_r[stage_idx-1][reg_idx*2] : max_out_r[stage_idx-1][reg_idx*2+1];
          end
        end
          
        always_ff @(posedge clk) begin
          if (rst)
            max_out_r[stage_idx][reg_idx] <= 'b0;
          else if (valid_r[stage_idx])
            max_out_r[stage_idx][reg_idx] <= max_in;
        end
      end
    end
  endgenerate
  
  if (pMAX_INDEX)
    assign data_out = {0, max_out_r[pSTAGE_NUM-1][0][pMAX_OUT_WIDTH-1:pDATA_WIDTH]};
  else
    assign data_out = max_out_r[pSTAGE_NUM-1][0];
  
  always_ff @(posedge clk) begin
    valid <= valid_r[pSTAGE_NUM-1];
  end    

endmodule