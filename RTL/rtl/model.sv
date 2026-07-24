`timescale 1ns/1ps

`include "define.sv"

module model #(
  parameter  pINPUT_WIDTH = 128
  ,parameter  pINPUT_HEIGHT = 128
  ,parameter  pINPUT_CHANNEL = 3
  ,parameter  pDATA_WIDTH   = 8
  ,parameter  pOUTPUT_WIDTH   = 32

  // kernel ram
  ,parameter  pWEIGHT_DATA_WIDTH = 64
  ,parameter  pWEIGHT_ADDR_WIDTH = 32
  ,parameter  pWEIGHT_BASE_ADDR = 0000_0000
)(
  input  logic                           clk
  ,input  logic                           rst
  ,(* KEEP = "true" *)input  logic                                     en
  ,(* KEEP = "true" *)input  logic                                     load_weight
  ,(* KEEP = "true" *)input  logic [pWEIGHT_DATA_WIDTH-1          :0]  weight_data
  ,(* KEEP = "true" *)input  logic [pWEIGHT_ADDR_WIDTH-1          :0]  weight_addr
  ,(* KEEP = "true" *)input  logic [pDATA_WIDTH*pINPUT_CHANNEL -1  :0]  data_in
  ,(* KEEP = "true" *)output logic                                     ready
  ,(* KEEP = "true" *)output logic [pOUTPUT_WIDTH-1               :0]  data_out
  ,(* KEEP = "true" *)output logic                                     valid
  ,(* KEEP = "true" *)output logic                                     done
);
initial begin
      $display("==================================================");
      $display("!!! KIEM TRA: MODEL.SV PHIEN BAN FIFO_SAFE (NEW) !!!");
      $display("==================================================");
  end

  // define parameter
  parameter  pINPUT_NUM         = 2;
  parameter  pMAX_INDEX         = 1;
    
  // ------------------------define for c1---------------------------
  parameter c1_f_DATA_WIDTH  =  pDATA_WIDTH*pINPUT_CHANNEL;
  parameter c1_f_DEPTH = 32768;  // pINPUT_WIDTH*pINPUT_HEIGHT + 10000; //16384 + 10000

  parameter c1_DATA_WIDTH        =  pDATA_WIDTH;
  parameter c1_INPUT_WIDTH       =  pINPUT_WIDTH;
  parameter c1_INPUT_HEIGHT      =  pINPUT_HEIGHT;
  parameter c1_IN_CHANNEL        =  pINPUT_CHANNEL;
  parameter c1_OUT_CHANNEL       =  4;
  parameter c1_KERNEL_SIZE       =  3;
  parameter c1_PADDING           =  1;
  parameter c1_STRIDE            =  1;     
  parameter c1_OUTPUT_PARALLEL   =  4;
  parameter c1_KERNEL_DATA_WIDTH =  32;
  parameter c1_WEIGHT_DATA_WIDTH =  pWEIGHT_DATA_WIDTH;
  parameter c1_WEIGHT_BASE_ADDR  =  pWEIGHT_BASE_ADDR;
  parameter c1_ACTIVATION        =  "sigmoid";
  
  // ------------------------define for pool1---------------------------
  parameter pool1_f_DATA_WIDTH  =  pDATA_WIDTH*c1_OUT_CHANNEL;
  parameter pool1_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT;

  //define for pool1
  parameter pool1_DATA_WIDTH    = pDATA_WIDTH;
  parameter pool1_INPUT_WIDTH   = 128; //tinh theo cong thuc
  parameter pool1_INPUT_HEIGHT  = 128; //tinh theo cong thuc
  parameter pool1_CHANNEL       = c1_OUT_CHANNEL;
  parameter pool1_KERNEL_SIZE   = 2;
  parameter pool1_PADDING       = 0;
  parameter pool1_STRIDE        = 2;
  parameter pool1_POOLING_TYPE  = "max" ;
  
  // ------------------------define for conv2---------------------------
  parameter c2_f_DATA_WIDTH  =  pDATA_WIDTH*c1_OUT_CHANNEL;
  parameter c2_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/4; //4096

  parameter c2_DATA_WIDTH        =  pDATA_WIDTH;
  parameter c2_INPUT_WIDTH       =  64;
  parameter c2_INPUT_HEIGHT      =  64;
  parameter c2_IN_CHANNEL        =  c1_OUT_CHANNEL;
  parameter c2_OUT_CHANNEL       =  4;
  parameter c2_KERNEL_SIZE       =  3;
  parameter c2_PADDING           =  1;
  parameter c2_STRIDE            =  1;     
  parameter c2_OUTPUT_PARALLEL   =  4;
  parameter c2_KERNEL_DATA_WIDTH =  64;
  parameter c2_WEIGHT_DATA_WIDTH =  pWEIGHT_DATA_WIDTH;
  parameter c2_WEIGHT_BASE_ADDR  =  32'd0000_0012;
  parameter c2_ACTIVATION        =  "sigmoid";
  
  // ------------------------define for pool2---------------------------
  parameter pool2_f_DATA_WIDTH  =  pDATA_WIDTH*c2_OUT_CHANNEL;
  parameter pool2_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/4;

  parameter pool2_DATA_WIDTH    = pDATA_WIDTH;
  parameter pool2_INPUT_WIDTH   = 64; //tinh theo cong thuc
  parameter pool2_INPUT_HEIGHT  = 64; //tinh theo cong thuc
  parameter pool2_CHANNEL       = c2_OUT_CHANNEL;
  parameter pool2_KERNEL_SIZE   = 2;
  parameter pool2_PADDING       = 0;
  parameter pool2_STRIDE        = 2;
  parameter pool2_POOLING_TYPE  = "max" ;
  
  // ------------------------define for conv3---------------------------
  parameter c3_f_DATA_WIDTH  =  pDATA_WIDTH*c2_OUT_CHANNEL;
  parameter c3_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/16; //1024

  parameter c3_DATA_WIDTH        =  pDATA_WIDTH;
  parameter c3_INPUT_WIDTH       =  32;
  parameter c3_INPUT_HEIGHT      =  32;
  parameter c3_IN_CHANNEL        =  c2_OUT_CHANNEL;
  parameter c3_OUT_CHANNEL       =  8;
  parameter c3_KERNEL_SIZE       =  3;
  parameter c3_PADDING           =  1;
  parameter c3_STRIDE            =  1;     
  parameter c3_OUTPUT_PARALLEL   =  8;
  parameter c3_KERNEL_DATA_WIDTH =  64;
  parameter c3_WEIGHT_DATA_WIDTH =  pWEIGHT_DATA_WIDTH;
  parameter c3_WEIGHT_BASE_ADDR  =  32'd0000_0024;
  parameter c3_ACTIVATION        =  "sigmoid";
  
  // ------------------------define for pool3---------------------------
  parameter pool3_f_DATA_WIDTH  =  pDATA_WIDTH*c3_OUT_CHANNEL;
  parameter pool3_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/16;

  parameter pool3_DATA_WIDTH    = pDATA_WIDTH;
  parameter pool3_INPUT_WIDTH   = 32; //tinh theo cong thuc
  parameter pool3_INPUT_HEIGHT  = 32; //tinh theo cong thuc
  parameter pool3_CHANNEL       = c3_OUT_CHANNEL;
  parameter pool3_KERNEL_SIZE   = 2;
  parameter pool3_PADDING       = 0;
  parameter pool3_STRIDE        = 2;
  parameter pool3_POOLING_TYPE  = "max" ;
  
  // ------------------------define for conv4---------------------------
  parameter c4_f_DATA_WIDTH  =  pDATA_WIDTH*c3_OUT_CHANNEL;
  parameter c4_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/64; //256

  parameter c4_DATA_WIDTH        =  pDATA_WIDTH;
  parameter c4_INPUT_WIDTH       =  16;
  parameter c4_INPUT_HEIGHT      =  16;
  parameter c4_IN_CHANNEL        =  c3_OUT_CHANNEL;
  parameter c4_OUT_CHANNEL       =  8;
  parameter c4_KERNEL_SIZE       =  3;
  parameter c4_PADDING           =  1;
  parameter c4_STRIDE            =  1;     
  parameter c4_OUTPUT_PARALLEL   =  8;
  parameter c4_KERNEL_DATA_WIDTH =  64;
  parameter c4_WEIGHT_DATA_WIDTH =  pWEIGHT_DATA_WIDTH;
  parameter c4_WEIGHT_BASE_ADDR  =  32'd0000_0038;
  parameter c4_ACTIVATION        =  "sigmoid";
  
  // ------------------------define for pool4---------------------------
  parameter pool4_f_DATA_WIDTH  =  pDATA_WIDTH*c4_OUT_CHANNEL;
  parameter pool4_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/64;

  parameter pool4_DATA_WIDTH    = pDATA_WIDTH;
  parameter pool4_INPUT_WIDTH   = 16; //tinh theo cong thuc
  parameter pool4_INPUT_HEIGHT  = 16; //tinh theo cong thuc
  parameter pool4_CHANNEL       = c3_OUT_CHANNEL;
  parameter pool4_KERNEL_SIZE   = 2;
  parameter pool4_PADDING       = 0;
  parameter pool4_STRIDE        = 2;
  parameter pool4_POOLING_TYPE  = "max" ;
  
  // ------------------------define for conv5---------------------------
  parameter c5_f_DATA_WIDTH  =  pDATA_WIDTH*c4_OUT_CHANNEL;
  parameter c5_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/256;

  parameter c5_DATA_WIDTH        =  pDATA_WIDTH;
  parameter c5_INPUT_WIDTH       =  8;
  parameter c5_INPUT_HEIGHT      =  8;
  parameter c5_IN_CHANNEL        =  c4_OUT_CHANNEL;
  parameter c5_OUT_CHANNEL       =  16;
  parameter c5_KERNEL_SIZE       =  3;
  parameter c5_PADDING           =  1;
  parameter c5_STRIDE            =  1;     
  parameter c5_OUTPUT_PARALLEL   =  16;
  parameter c5_KERNEL_DATA_WIDTH =  64;
  parameter c5_WEIGHT_DATA_WIDTH =  pWEIGHT_DATA_WIDTH;
  parameter c5_WEIGHT_BASE_ADDR  =  32'd0000_0052;
  parameter c5_ACTIVATION        =  "sigmoid";
  
  // ------------------------define for pool5---------------------------
  parameter pool5_f_DATA_WIDTH  =  pDATA_WIDTH*c5_OUT_CHANNEL;
  parameter pool5_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/256;

  parameter pool5_DATA_WIDTH    = pDATA_WIDTH;
  parameter pool5_INPUT_WIDTH   = 8; //tinh theo cong thuc
  parameter pool5_INPUT_HEIGHT  = 8; //tinh theo cong thuc
  parameter pool5_CHANNEL       = c5_OUT_CHANNEL;
  parameter pool5_KERNEL_SIZE   = 2;
  parameter pool5_PADDING       = 0;
  parameter pool5_STRIDE        = 2;
  parameter pool5_POOLING_TYPE  = "max" ;
  
  // -----------------------define for fc--------------------------------
  parameter fc_f_DATA_WIDTH  =  pDATA_WIDTH*pool5_CHANNEL;
  parameter fc_f_DEPTH = pINPUT_WIDTH*pINPUT_HEIGHT/1024;

  parameter fc_DATA_WIDTH          =  pDATA_WIDTH;
  parameter fc_IN_FEATURE          =  4*4*pool5_CHANNEL; //tinh theo cong thuc
  parameter fc_OUT_FEATURE         =  2;
  parameter fc_CHANNEL             =  pool5_CHANNEL;
  parameter fc_OUTPUT_PARALLEL     =  1;
  parameter fc_WEIGHT_DATA_WIDTH   =  pWEIGHT_DATA_WIDTH;
  parameter fc_WEIGHT_BASE_ADDR    =  32'd0000_0070;
  parameter fc_ACTIVATION          =  "softmax";

  
  //-------------------for u_fifo_conv1-------------------------
  (* KEEP = "true" *) logic [c1_f_DATA_WIDTH-1:0] fifo_conv1_out;
  (* KEEP = "true" *) logic fifo_conv1_empty;
  (* KEEP = "true" *) logic fifo_conv1_valid;
  (* KEEP = "true" *) logic fifo_conv1_full;
  
  assign ready = ~fifo_conv1_full;

  //for u_conv1
  (* KEEP = "true" *) logic conv1_rd_en;
  (* KEEP = "true" *) logic conv1_valid;
  (* KEEP = "true" *) logic conv1_done;
  (* KEEP = "true" *) logic [pool1_f_DATA_WIDTH-1:0] conv1_out;

  //for u_fifo_pool1
  (* KEEP = "true" *) logic [pool1_f_DATA_WIDTH-1:0] fifo_pool1_out;
  (* KEEP = "true" *) logic fifo_pool1_empty;
  (* KEEP = "true" *) logic fifo_pool1_valid;

  //for u_pool1
  (* KEEP = "true" *) logic pool1_rd_en;
  (* KEEP = "true" *) logic pool1_valid;
  (* KEEP = "true" *) logic pool1_done;
  (* KEEP = "true" *) logic [c2_f_DATA_WIDTH-1:0] pool1_out;

  //-------------------for u_fifo_conv2-------------------------
  (* KEEP = "true" *) logic [c2_f_DATA_WIDTH-1:0] fifo_conv2_out;
  (* KEEP = "true" *) logic fifo_conv2_empty;
  (* KEEP = "true" *) logic fifo_conv2_valid;

  //for u_conv2
  (* KEEP = "true" *) logic conv2_rd_en;
  (* KEEP = "true" *) logic conv2_valid;
  (* KEEP = "true" *) logic conv2_done;
  (* KEEP = "true" *) logic [pool2_f_DATA_WIDTH-1:0] conv2_out;

  //for u_fifo_pool2
  (* KEEP = "true" *) logic [pool2_f_DATA_WIDTH-1:0] fifo_pool2_out;
  (* KEEP = "true" *) logic fifo_pool2_empty;
  (* KEEP = "true" *) logic fifo_pool2_valid;

  //for u_pool2
  (* KEEP = "true" *) logic pool2_rd_en;
  (* KEEP = "true" *) logic pool2_valid;
  (* KEEP = "true" *) logic pool2_done;
  (* KEEP = "true" *) logic [c3_f_DATA_WIDTH-1:0] pool2_out;
  
    //-------------------for u_fifo_conv3-------------------------
  (* KEEP = "true" *) logic [c3_f_DATA_WIDTH-1:0] fifo_conv3_out;
  (* KEEP = "true" *) logic fifo_conv3_empty;
  (* KEEP = "true" *) logic fifo_conv3_valid;

  //for u_conv3
  (* KEEP = "true" *) logic conv3_rd_en;
  (* KEEP = "true" *) logic conv3_valid;
  (* KEEP = "true" *) logic conv3_done;
  (* KEEP = "true" *) logic [pool3_f_DATA_WIDTH-1:0] conv3_out;

  //for u_fifo_pool3
  (* KEEP = "true" *) logic [pool3_f_DATA_WIDTH-1:0] fifo_pool3_out;
  (* KEEP = "true" *) logic fifo_pool3_empty;
  (* KEEP = "true" *) logic fifo_pool3_valid;

  //for u_pool3
  (* KEEP = "true" *) logic pool3_rd_en;
  (* KEEP = "true" *) logic pool3_valid;
  (* KEEP = "true" *) logic pool3_done;
  (* KEEP = "true" *) logic [c4_f_DATA_WIDTH-1:0] pool3_out;
  
      //-------------------for u_fifo_conv4-------------------------
  (* KEEP = "true" *) logic [c4_f_DATA_WIDTH-1:0] fifo_conv4_out;
  (* KEEP = "true" *) logic fifo_conv4_empty;
  (* KEEP = "true" *) logic fifo_conv4_valid;

  //for u_conv4
  (* KEEP = "true" *) logic conv4_rd_en;
  (* KEEP = "true" *) logic conv4_valid;
  (* KEEP = "true" *) logic conv4_done;
  (* KEEP = "true" *) logic [pool4_f_DATA_WIDTH-1:0] conv4_out;

  //for u_fifo_pool4
  (* KEEP = "true" *) logic [pool4_f_DATA_WIDTH-1:0] fifo_pool4_out;
  (* KEEP = "true" *) logic fifo_pool4_empty;
  (* KEEP = "true" *) logic fifo_pool4_valid;

  //for u_pool4
  (* KEEP = "true" *) logic pool4_rd_en;
  (* KEEP = "true" *) logic pool4_valid;
  (* KEEP = "true" *) logic pool4_done;
  (* KEEP = "true" *) logic [c5_f_DATA_WIDTH-1:0] pool4_out;
  
      //-------------------for u_fifo_conv5-------------------------
  (* KEEP = "true" *) logic [c5_f_DATA_WIDTH-1:0] fifo_conv5_out;
  (* KEEP = "true" *) logic fifo_conv5_empty;
  (* KEEP = "true" *) logic fifo_conv5_valid;

  //for u_conv5
  (* KEEP = "true" *) logic conv5_rd_en;
  (* KEEP = "true" *) logic conv5_valid;
  (* KEEP = "true" *) logic conv5_done;
  (* KEEP = "true" *) logic [pool5_f_DATA_WIDTH-1:0] conv5_out;

  //for u_fifo_pool5
  (* KEEP = "true" *) logic [pool5_f_DATA_WIDTH-1:0] fifo_pool5_out;
  (* KEEP = "true" *) logic fifo_pool5_empty;
  (* KEEP = "true" *) logic fifo_pool5_valid;

  //for u_pool5
  (* KEEP = "true" *) logic pool5_rd_en;
  (* KEEP = "true" *) logic pool5_valid;
  (* KEEP = "true" *) logic pool5_done;
  (* KEEP = "true" *) logic [fc_f_DATA_WIDTH-1:0] pool5_out;
  
  //-------------------for fc-------------------------
  (* KEEP = "true" *) logic [fc_f_DATA_WIDTH-1:0] fifo_fc_out;
  (* KEEP = "true" *) logic fifo_fc_empty;
  (* KEEP = "true" *) logic fifo_fc_valid;

  // for u_fc
  (* KEEP = "true" *) logic fc_rd_en;
  (* KEEP = "true" *) logic fc_valid;
  (* KEEP = "true" *) logic fc_done;
  (* KEEP = "true" *) logic [32*fc_OUT_FEATURE -1:0] fc_out;

  
   //---------------------------conv 1---------------------------//
  fifo_safe #(
    .pDATA_WIDTH  ( c1_f_DATA_WIDTH)
    ,.pDEPTH      ( 32768     )
//    ,.pMODE       ( 1              )
  ) u_fifo_conv1 (
    .clk      ( clk               )
    ,.rst     ( rst               )
    //input 
    ,.rst_count(en                )
    ,.wr_en   ( en                )
    ,.rd_en   ( conv1_rd_en       )
    ,.wr_data ( data_in           )
    //output
    ,.rd_data ( fifo_conv1_out    )
    ,.full    ( fifo_conv1_full   )
    ,.empty   ( fifo_conv1_empty  )
    ,.valid   ( fifo_conv1_valid  )
  );

  conv #(
    .pDATA_WIDTH          ( c1_DATA_WIDTH         )
    ,.pINPUT_WIDTH        ( c1_INPUT_WIDTH        )
    ,.pINPUT_HEIGHT       ( c1_INPUT_HEIGHT       )
    ,.pIN_CHANNEL         ( c1_IN_CHANNEL         )
    ,.pOUT_CHANNEL        ( c1_OUT_CHANNEL        )
    ,.pKERNEL_SIZE        ( c1_KERNEL_SIZE        )
    ,.pPADDING            ( c1_PADDING            )
    ,.pSTRIDE             ( c1_STRIDE             )
    ,.pOUTPUT_PARALLEL    ( c1_OUTPUT_PARALLEL    )
    ,.pKERNEL_DATA_WIDTH  ( c1_KERNEL_DATA_WIDTH  )
    ,.pWEIGHT_DATA_WIDTH  ( c1_WEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( c1_WEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( c1_ACTIVATION         )
  ) u_conv1 (
    .clk          ( clk               )
    ,.rst         ( rst               )
    ,.en          ( !fifo_conv1_empty )
    ,.load_weight ( load_weight       )
    ,.weight_addr ( weight_addr       )
    ,.weight_data ( weight_data       )
    ,.rd_en       ( conv1_rd_en       )
    ,.data_valid  ( fifo_conv1_valid  )
    ,.data_in     ( fifo_conv1_out    )
    ,.data_out    ( conv1_out         )
    ,.valid       ( conv1_valid       )
    ,.done        ( conv1_done        )
    ,.top_valid   ( valid              )
  );
  
//--------------------------pool 1---------------------------//
  fifo #(
    .pDATA_WIDTH  ( pool1_f_DATA_WIDTH )
    ,.pDEPTH      ( pool1_f_DEPTH                     )
  ) u_fifo_pool1 (
    .clk      ( clk               )
    ,.rst_count(en                )
    ,.rst     ( rst               )
    ,.wr_en   ( conv1_valid       )
    ,.rd_en   ( pool1_rd_en       )
    ,.wr_data ( conv1_out         )
    ,.rd_data ( fifo_pool1_out    )
    ,.full    (                   )
    ,.empty   ( fifo_pool1_empty  )
    ,.valid   ( fifo_pool1_valid  )
  );

  pooling #(
    .pDATA_WIDTH    ( pool1_DATA_WIDTH   )
    ,.pINPUT_WIDTH  ( pool1_INPUT_WIDTH  )
    ,.pINPUT_HEIGHT ( pool1_INPUT_HEIGHT )
    ,.pCHANNEL      ( pool1_CHANNEL      )
    ,.pKERNEL_SIZE  ( pool1_KERNEL_SIZE  )
    ,.pPADDING      ( pool1_PADDING      )
    ,.pSTRIDE       ( pool1_STRIDE       )
    ,.pPOOLING_TYPE ( pool1_POOLING_TYPE )
  ) u_pool1 (
    .clk          ( clk                )
    ,.rst         ( rst                )
    ,.en          ( !fifo_pool1_empty  )
    ,.rd_en       ( pool1_rd_en        )
    ,.data_valid  ( fifo_pool1_valid   )
    ,.data_in     ( fifo_pool1_out     )
    ,.data_out    ( pool1_out          )
    ,.valid       ( pool1_valid        )
    ,.done        ( pool1_done         )
    ,.top_valid   ( valid              )
  );

  //---------------------------conv 2---------------------------//
  fifo #(
    .pDATA_WIDTH  ( c2_f_DATA_WIDTH )
    ,.pDEPTH      ( c2_f_DEPTH      )
  ) u_fifo_conv2 (
   .clk      ( clk               )
   ,.rst     ( rst               )
   //input
   ,.rst_count(en                )
   ,.wr_en   ( pool1_valid       )
   ,.rd_en   ( conv2_rd_en       )
   ,.wr_data ( pool1_out         )
   //output
   ,.rd_data ( fifo_conv2_out    )
   ,.full    (                   )
   ,.empty   ( fifo_conv2_empty  )
   ,.valid   ( fifo_conv2_valid  )
  );

  conv #(
    .pDATA_WIDTH          ( c2_DATA_WIDTH         )
    ,.pINPUT_WIDTH        ( c2_INPUT_WIDTH        )
    ,.pINPUT_HEIGHT       ( c2_INPUT_HEIGHT       )
    ,.pIN_CHANNEL         ( c2_IN_CHANNEL         )
    ,.pOUT_CHANNEL        ( c2_OUT_CHANNEL        )
    ,.pKERNEL_SIZE        ( c2_KERNEL_SIZE        )
    ,.pPADDING            ( c2_PADDING            )
    ,.pSTRIDE             ( c2_STRIDE             )
    ,.pOUTPUT_PARALLEL    ( c2_OUTPUT_PARALLEL    )
    ,.pWEIGHT_DATA_WIDTH  ( c2_WEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( c2_WEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( c2_ACTIVATION         )
  ) u_conv2 (
    .clk          ( clk               )
    ,.rst         ( rst               )
    ,.en          ( !fifo_conv2_empty )
    ,.load_weight ( load_weight       )
    ,.weight_addr ( weight_addr       )
    ,.weight_data ( weight_data       )
    ,.rd_en       ( conv2_rd_en       )
    ,.data_valid  ( fifo_conv2_valid  )
    ,.data_in     ( fifo_conv2_out    )
    ,.data_out    ( conv2_out         )
    ,.valid       ( conv2_valid       )
    ,.done        ( conv2_done        )
    ,.top_valid   ( valid              )
  );
  
  
  //---------------------------pool 2---------------------------//
  fifo #(
    .pDATA_WIDTH  ( pool2_f_DATA_WIDTH )
    ,.pDEPTH      ( pool2_f_DEPTH      )
  ) u_fifo_pool2 (
    .clk      ( clk               )
    ,.rst     ( rst               )
    ,.rst_count(en                )
    ,.wr_en   ( conv2_valid       )
    ,.rd_en   ( pool2_rd_en       )
    ,.wr_data ( conv2_out         )
    ,.rd_data ( fifo_pool2_out    )
    ,.full    (                   )
    ,.empty   ( fifo_pool2_empty  )
    ,.valid   ( fifo_pool2_valid  )
  );

  pooling #(
    .pDATA_WIDTH    ( pool2_DATA_WIDTH   )
    ,.pINPUT_WIDTH  ( pool2_INPUT_WIDTH  )
    ,.pINPUT_HEIGHT ( pool2_INPUT_HEIGHT )
    ,.pCHANNEL      ( pool2_CHANNEL      )
    ,.pKERNEL_SIZE  ( pool2_KERNEL_SIZE  )
    ,.pPADDING      ( pool2_PADDING      )
    ,.pSTRIDE       ( pool2_STRIDE       )
    ,.pPOOLING_TYPE ( pool2_POOLING_TYPE )
  ) u_pool2 (
    .clk          ( clk                )
    ,.rst         ( rst                )
    ,.en          ( !fifo_pool2_empty  )
    ,.rd_en       ( pool2_rd_en        )
    ,.data_valid  ( fifo_pool2_valid   )
    ,.data_in     ( fifo_pool2_out     )
    ,.data_out    ( pool2_out          )
    ,.valid       ( pool2_valid        )
    ,.done        ( pool2_done         )
    ,.top_valid   ( valid              )
  );
  
  //---------------------------conv 3---------------------------//
  fifo #(
    .pDATA_WIDTH  ( c3_f_DATA_WIDTH )
    ,.pDEPTH      ( c3_f_DEPTH                     )
  ) u_fifo_conv3 (
   .clk      ( clk               )
   ,.rst     ( rst               )
   //input
   ,.rst_count(en                )
   ,.wr_en   ( pool2_valid       )
   ,.rd_en   ( conv3_rd_en       )
   ,.wr_data ( pool2_out         )
   //output
   ,.rd_data ( fifo_conv3_out    )
   ,.full    (                   )
   ,.empty   ( fifo_conv3_empty  )
   ,.valid   ( fifo_conv3_valid  )
  );

  conv #(
    .pDATA_WIDTH          ( c3_DATA_WIDTH         )
    ,.pINPUT_WIDTH        ( c3_INPUT_WIDTH        )
    ,.pINPUT_HEIGHT       ( c3_INPUT_HEIGHT       )
    ,.pIN_CHANNEL         ( c3_IN_CHANNEL         )
    ,.pOUT_CHANNEL        ( c3_OUT_CHANNEL        )
    ,.pKERNEL_SIZE        ( c3_KERNEL_SIZE        )
    ,.pPADDING            ( c3_PADDING            )
    ,.pSTRIDE             ( c3_STRIDE             )
    ,.pOUTPUT_PARALLEL    ( c3_OUTPUT_PARALLEL    )
    ,.pWEIGHT_DATA_WIDTH  ( c3_WEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( c3_WEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( c3_ACTIVATION         )
  ) u_conv3 (
    .clk          ( clk               )
    ,.rst         ( rst               )
    ,.en          ( !fifo_conv3_empty )
    ,.load_weight ( load_weight       )
    ,.weight_addr ( weight_addr       )
    ,.weight_data ( weight_data       )
    ,.rd_en       ( conv3_rd_en       )
    ,.data_valid  ( fifo_conv3_valid  )
    ,.data_in     ( fifo_conv3_out    )
    ,.data_out    ( conv3_out         )
    ,.valid       ( conv3_valid       )
    ,.done        ( conv3_done        )
    ,.top_valid   ( valid              )
  );
  
  
  //---------------------------pool 3---------------------------//
  fifo #(
    .pDATA_WIDTH  ( pool3_f_DATA_WIDTH )
    ,.pDEPTH      ( pool3_f_DEPTH      )
  ) u_fifo_pool3 (
    .clk      ( clk               )
    ,.rst_count(en                )
    ,.rst     ( rst               )
    ,.wr_en   ( conv3_valid       )
    ,.rd_en   ( pool3_rd_en       )
    ,.wr_data ( conv3_out         )
    ,.rd_data ( fifo_pool3_out    )
    ,.full    (                   )
    ,.empty   ( fifo_pool3_empty  )
    ,.valid   ( fifo_pool3_valid  )
  );

  pooling #(
    .pDATA_WIDTH    ( pool3_DATA_WIDTH   )
    ,.pINPUT_WIDTH  ( pool3_INPUT_WIDTH  )
    ,.pINPUT_HEIGHT ( pool3_INPUT_HEIGHT )
    ,.pCHANNEL      ( pool3_CHANNEL      )
    ,.pKERNEL_SIZE  ( pool3_KERNEL_SIZE  )
    ,.pPADDING      ( pool3_PADDING      )
    ,.pSTRIDE       ( pool3_STRIDE       )
    ,.pPOOLING_TYPE ( pool3_POOLING_TYPE )
  ) u_pool3 (
    .clk          ( clk                )
    ,.rst         ( rst                )
    ,.en          ( !fifo_pool3_empty  )
    ,.rd_en       ( pool3_rd_en        )
    ,.data_valid  ( fifo_pool3_valid   )
    ,.data_in     ( fifo_pool3_out     )
    ,.data_out    ( pool3_out          )
    ,.valid       ( pool3_valid        )
    ,.done        ( pool3_done         )
    ,.top_valid   ( valid              )
  );
  
  //---------------------------conv 4---------------------------//
  fifo #(
    .pDATA_WIDTH  ( c4_f_DATA_WIDTH )
    ,.pDEPTH      ( c4_f_DEPTH                     )
  ) u_fifo_conv4 (
   .clk      ( clk               )
   ,.rst     ( rst               )
   //input
   ,.rst_count(en                )
   ,.wr_en   ( pool3_valid       )
   ,.rd_en   ( conv4_rd_en       )
   ,.wr_data ( pool3_out         )
   //output
   ,.rd_data ( fifo_conv4_out    )
   ,.full    (                   )
   ,.empty   ( fifo_conv4_empty  )
   ,.valid   ( fifo_conv4_valid  )
  );

  conv #(
    .pDATA_WIDTH          ( c4_DATA_WIDTH         )
    ,.pINPUT_WIDTH        ( c4_INPUT_WIDTH        )
    ,.pINPUT_HEIGHT       ( c4_INPUT_HEIGHT       )
    ,.pIN_CHANNEL         ( c4_IN_CHANNEL         )
    ,.pOUT_CHANNEL        ( c4_OUT_CHANNEL        )
    ,.pKERNEL_SIZE        ( c4_KERNEL_SIZE        )
    ,.pPADDING            ( c4_PADDING            )
    ,.pSTRIDE             ( c4_STRIDE             )
    ,.pOUTPUT_PARALLEL    ( c4_OUTPUT_PARALLEL    )
    ,.pWEIGHT_DATA_WIDTH  ( c4_WEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( c4_WEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( c4_ACTIVATION         )
  ) u_conv4 (
    .clk          ( clk               )
    ,.rst         ( rst               )
    ,.en          ( !fifo_conv4_empty )
    ,.load_weight ( load_weight       )
    ,.weight_addr ( weight_addr       )
    ,.weight_data ( weight_data       )
    ,.rd_en       ( conv4_rd_en       )
    ,.data_valid  ( fifo_conv4_valid  )
    ,.data_in     ( fifo_conv4_out    )
    ,.data_out    ( conv4_out         )
    ,.valid       ( conv4_valid       )
    ,.done        ( conv4_done        )
    ,.top_valid   ( valid              )
  );
  
  
  //---------------------------pool 4---------------------------//
  fifo #(
    .pDATA_WIDTH  ( pool4_f_DATA_WIDTH )
    ,.pDEPTH      ( pool4_f_DEPTH      )
  ) u_fifo_pool4 (
    .clk      ( clk               )
    ,.rst     ( rst               )
    ,.rst_count(en                )
    ,.wr_en   ( conv4_valid       )
    ,.rd_en   ( pool4_rd_en       )
    ,.wr_data ( conv4_out         )
    ,.rd_data ( fifo_pool4_out    )
    ,.full    (                   )
    ,.empty   ( fifo_pool4_empty  )
    ,.valid   ( fifo_pool4_valid  )
  );

  pooling #(
    .pDATA_WIDTH    ( pool4_DATA_WIDTH   )
    ,.pINPUT_WIDTH  ( pool4_INPUT_WIDTH  )
    ,.pINPUT_HEIGHT ( pool4_INPUT_HEIGHT )
    ,.pCHANNEL      ( pool4_CHANNEL      )
    ,.pKERNEL_SIZE  ( pool4_KERNEL_SIZE  )
    ,.pPADDING      ( pool4_PADDING      )
    ,.pSTRIDE       ( pool4_STRIDE       )
    ,.pPOOLING_TYPE ( pool4_POOLING_TYPE )
  ) u_pool4 (
    .clk          ( clk                )
    ,.rst         ( rst                )
    ,.en          ( !fifo_pool4_empty  )
    ,.rd_en       ( pool4_rd_en        )
    ,.data_valid  ( fifo_pool4_valid   )
    ,.data_in     ( fifo_pool4_out     )
    ,.data_out    ( pool4_out          )
    ,.valid       ( pool4_valid        )
    ,.done        ( pool4_done         )
    ,.top_valid   ( valid              )
  );
  
  //---------------------------fifo conv 5---------------------------//
  fifo #(
    .pDATA_WIDTH  ( c5_f_DATA_WIDTH )
    ,.pDEPTH      ( c5_f_DEPTH                     )
  ) u_fifo_conv5 (
   .clk      ( clk               )
   ,.rst     ( rst               )
   //input
   ,.rst_count(en                )
   ,.wr_en   ( pool4_valid       )
   ,.rd_en   ( conv5_rd_en       )
   ,.wr_data ( pool4_out         )
   //output
   ,.rd_data ( fifo_conv5_out    )
   ,.full    (                   )
   ,.empty   ( fifo_conv5_empty  )
   ,.valid   ( fifo_conv5_valid  )
  );

  conv #(
    .pDATA_WIDTH          ( c5_DATA_WIDTH         )
    ,.pINPUT_WIDTH        ( c5_INPUT_WIDTH        )
    ,.pINPUT_HEIGHT       ( c5_INPUT_HEIGHT       )
    ,.pIN_CHANNEL         ( c5_IN_CHANNEL         )
    ,.pOUT_CHANNEL        ( c5_OUT_CHANNEL        )
    ,.pKERNEL_SIZE        ( c5_KERNEL_SIZE        )
    ,.pPADDING            ( c5_PADDING            )
    ,.pSTRIDE             ( c5_STRIDE             )
    ,.pOUTPUT_PARALLEL    ( c5_OUTPUT_PARALLEL    )
    ,.pWEIGHT_DATA_WIDTH  ( c5_WEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( c5_WEIGHT_BASE_ADDR   )
    ,.pACTIVATION         ( c5_ACTIVATION         )
  ) u_conv5 (
    .clk          ( clk               )
    ,.rst         ( rst               )
    ,.en          ( !fifo_conv5_empty )
    ,.load_weight ( load_weight       )
    ,.weight_addr ( weight_addr       )
    ,.weight_data ( weight_data       )
    ,.rd_en       ( conv5_rd_en       )
    ,.data_valid  ( fifo_conv5_valid  )
    ,.data_in     ( fifo_conv5_out    )
    ,.data_out    ( conv5_out         )
    ,.valid       ( conv5_valid       )
    ,.done        ( conv5_done        )
    ,.top_valid   ( valid              )
  );
  
  
  //---------------------------fifo pool 5---------------------------//
  fifo #(
    .pDATA_WIDTH  ( pool5_f_DATA_WIDTH )
    ,.pDEPTH      ( pool5_f_DEPTH      )
  ) u_fifo_pool5 (
    .clk      ( clk               )
    ,.rst     ( rst               )
    ,.rst_count(en                )
    ,.wr_en   ( conv5_valid       )
    ,.rd_en   ( pool5_rd_en       )
    ,.wr_data ( conv5_out         )
    ,.rd_data ( fifo_pool5_out    )
    ,.full    (                   )
    ,.empty   ( fifo_pool5_empty  )
    ,.valid   ( fifo_pool5_valid  )
  );

  pooling #(
    .pDATA_WIDTH    ( pool5_DATA_WIDTH   )
    ,.pINPUT_WIDTH  ( pool5_INPUT_WIDTH  )
    ,.pINPUT_HEIGHT ( pool5_INPUT_HEIGHT )
    ,.pCHANNEL      ( pool5_CHANNEL      )
    ,.pKERNEL_SIZE  ( pool5_KERNEL_SIZE  )
    ,.pPADDING      ( pool5_PADDING      )
    ,.pSTRIDE       ( pool5_STRIDE       )
    ,.pPOOLING_TYPE ( pool5_POOLING_TYPE )
  ) u_pool5 (
    .clk          ( clk                )
    ,.rst         ( rst                )
    ,.en          ( !fifo_pool5_empty  )
    ,.rd_en       ( pool5_rd_en        )
    ,.data_valid  ( fifo_pool5_valid   )
    ,.data_in     ( fifo_pool5_out     )
    ,.data_out    ( pool5_out          )
    ,.valid       ( pool5_valid        )
    ,.done        ( pool5_done         )
    ,.top_valid   ( valid              )
  );
  
  //---------------------------fc---------------------------//
  fifo #(
    .pDATA_WIDTH ( fc_f_DATA_WIDTH   )
   ,.pDEPTH      ( fc_f_DEPTH                     )
 ) u_fifo_fc1 (
  .clk       ( clk               )
  ,.rst_count(en                )
  ,.rst      ( rst               )
   ,.wr_en   ( pool5_valid       )
   ,.rd_en   ( fc_rd_en         )
   ,.wr_data ( pool5_out         )
   ,.rd_data ( fifo_fc_out      )
   ,.full    (                   )
   ,.empty   ( fifo_fc_empty    )
   ,.valid   ( fifo_fc_valid    )
 );

 linear #(
  .pDATA_WIDTH         ( fc_DATA_WIDTH         )
 ,.pIN_FEATURE         ( fc_IN_FEATURE         )
 ,.pOUT_FEATURE        ( fc_OUT_FEATURE        )
 ,.pCHANNEL            ( fc_CHANNEL            )
 ,.pOUTPUT_PARALLEL    ( fc_OUTPUT_PARALLEL    )
 ,.pWEIGHT_DATA_WIDTH  ( fc_WEIGHT_DATA_WIDTH  )
 ,.pWEIGHT_BASE_ADDR   ( fc_WEIGHT_BASE_ADDR   )
 ,.pACTIVATION         ( fc_ACTIVATION         )
) u_fc (
 .clk          ( clk             )
 ,.rst         ( rst             )
 ,.en          ( !fifo_fc_empty )
 ,.load_weight ( load_weight     )
 ,.weight_addr ( weight_addr     )
 ,.weight_data ( weight_data     )
 ,.rd_en       ( fc_rd_en       )
 ,.data_valid  ( fifo_fc_valid  )
 ,.data_in     ( fifo_fc_out    )
 ,.data_out    ( fc_out         )
 ,.valid       ( fc_valid       )
 ,.done        ( fc_done        )
);

//---------------------------maxtree---------------------------//
logic raw_valid;
logic [pOUTPUT_WIDTH-1:0] actual_data_out;
max_tree #(
  .pDATA_WIDTH ( pOUTPUT_WIDTH  )
 ,.pINPUT_NUM  ( pINPUT_NUM     )
 ,.pMAX_INDEX  ( pMAX_INDEX     )
) u_classification (
 .clk        ( clk       )
 ,.rst       ( rst       )
 ,.en        ( fc_valid )
 ,.data_in   ( fc_out   )
 ,.data_out  ( actual_data_out  )
 ,.valid     ( raw_valid     )
); 
// --- LOGIC GIỮ TÍN HIỆU (LATCH) ---
// Không cần đếm counter nữa, chỉ cần giữ tín hiệu done
logic done_latch;

always_ff @(posedge clk or posedge rst) begin
  if (rst) begin
    done_latch <= 0;
  end else begin
    // Khi có kết quả từ Max Tree, bật Done lên và giữ luôn
    if (raw_valid) begin
        done_latch <= 1;
    end
  end
end

assign valid = raw_valid; // Output valid xung nhịp
assign done  = done_latch; // Output done giữ trạng thái
assign data_out = actual_data_out + 32'd1;
endmodule

module fifo_safe #(
   parameter  pDATA_WIDTH = 8
  ,parameter  pDEPTH      = 1024
)(
   input  logic                   clk
  ,input  logic                   rst
  ,input  logic                   wr_en
  ,input  logic                   rd_en
  ,input  logic [pDATA_WIDTH-1:0] wr_data
  ,input  logic                   rst_count // Giữ cổng này cho tương thích
  
  ,output logic [pDATA_WIDTH-1:0] rd_data
  ,output logic                   full
  ,output logic                   empty
  ,output logic                   valid
);

  localparam pADDR_WIDTH = $clog2(pDEPTH);
  
  // --- KHỐI RAM ---
  (* ram_style = "block" *)
  logic [pDATA_WIDTH-1:0] mem_r [0:pDEPTH-1];
  
  // --- QUAN TRỌNG: ĐÃ TĂNG 1 BIT ĐỂ CHỨA ĐƯỢC GIÁ TRỊ pDEPTH ---
  logic [pADDR_WIDTH:0]   counter_r; 
  // -------------------------------------------------------------

  logic [pADDR_WIDTH-1:0] wr_ptr_r;
  logic [pADDR_WIDTH-1:0] rd_ptr_r;

  // Logic Valid Output
  always_ff @(posedge clk) begin
    if (rst) valid <= 'b0;
    else     valid <= rd_en && !empty;
  end
  
  // Logic Counter (Đếm số lượng phần tử)
  always_ff @(posedge clk) begin
    if (rst) begin
      counter_r <= 'b0;
    end else begin
      if ((wr_en && !full) && (rd_en && !empty))
        counter_r <= counter_r; // Vừa ghi vừa đọc -> Giữ nguyên
      else if (wr_en && !full)
        counter_r <= counter_r + 1'b1;
      else if (rd_en && !empty)
        counter_r <= counter_r - 1'b1;
    end
  end
  
  // Logic Con trỏ Ghi/Đọc
  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr_r <= 'b0;
      rd_ptr_r <= 'b0;
    end else begin
      if (wr_en && !full) begin
        if (wr_ptr_r == pDEPTH-1) wr_ptr_r <= 0;
        else                      wr_ptr_r <= wr_ptr_r + 1'b1;
      end
      if (rd_en && !empty) begin
        if (rd_ptr_r == pDEPTH-1) rd_ptr_r <= 0;
        else                      rd_ptr_r <= rd_ptr_r + 1'b1;
      end
    end
  end

  // Logic Memory Access
  always_ff @(posedge clk) begin
    if (wr_en && !full)
      mem_r[wr_ptr_r] <= wr_data;
    if (rd_en && !empty) // Sửa logic đọc synchronous
      rd_data <= mem_r[rd_ptr_r];
  end

  // Logic Báo Trạng Thái
  assign full  = (counter_r == pDEPTH);
  assign empty = (counter_r == 0);

endmodule