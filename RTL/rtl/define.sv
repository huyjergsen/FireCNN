`ifndef DEFINE_V
`define DEFINE_V

// define parameter
parameter  in_INPUT_NUM         = 3;
parameter  in_MAX_INDEX         = 1;
// define fifo
parameter pDEPTH = 1024;


// define input
parameter  in_INPUT_WIDTH       = 128;
parameter  in_INPUT_HEIGHT      = 128;
parameter  in_INPUT_CHANEL      = 4;
parameter  in_DATA_WIDTH        = 8;
parameter  in_OUTPUT_WIDTH      = 32;
parameter  in_WEIGHT_DATA_WIDTH = 64;
parameter  in_WEIGHT_ADDR_WIDTH = 32;
parameter  in_WEIGHT_BASE_ADDR  = 0000_0000;

// define for fifo1 
parameter f1_DATA_WIDTH  =  in_DATA_WIDTH*in_INPUT_CHANEL;
parameter f1_DEPTH       =  pDEPTH;

// define for conv1
parameter c1_DATA_WIDTH        =  in_DATA_WIDTH;
parameter c1_INPUT_WIDTH       =  in_INPUT_WIDTH;
parameter c1_INPUT_HEIGHT      =  in_INPUT_HEIGHT;
parameter c1_IN_CHANNEL        =  in_INPUT_CHANEL;
parameter c1_OUT_CHANNEL       =  16;
parameter c1_KERNEL_SIZE       =  3;
parameter c1_PADDING           =  1;
parameter c1_STRIDE            =  1;     
parameter c1_OUTPUT_PARALLEL   =  16;
parameter c1_WEIGHT_DATA_WIDTH =  in_WEIGHT_DATA_WIDTH;
parameter c1_WEIGHT_BASE_ADDR  =  in_WEIGHT_BASE_ADDR;
parameter c1_ACTIVATION        =  "sigmoid";

// define for fifo2
parameter f2_DATA_WIDTH  =  in_DATA_WIDTH*c1_OUT_CHANNEL;
parameter f2_DEPTH       =  pDEPTH;  

//define for pool1
parameter pool1_DATA_WIDTH    = in_DATA_WIDTH;
parameter pool1_INPUT_WIDTH   = 128; //tinh theo cong thuc
parameter pool1_INPUT_HEIGHT  = 128; //tinh theo cong thuc
parameter pool1_CHANNEL       = c1_OUT_CHANNEL;
parameter pool1_KERNEL_SIZE   = 2;
parameter pool1_PADDING       = 0;
parameter pool1_STRIDE        = 2;
parameter pool1_POOLING_TYPE  = "max" ;

// define for fifo3 
parameter f3_DATA_WIDTH  =  in_DATA_WIDTH*c1_OUT_CHANNEL;
parameter f3_DEPTH       =  pDEPTH;  

// define for conv2
parameter c2_DATA_WIDTH        =  in_DATA_WIDTH;
parameter c2_INPUT_WIDTH       =  64; //tinh theo cong thuc
parameter c2_INPUT_HEIGHT      =  64; //tinh theo cong thuc
parameter c2_IN_CHANNEL        =  c1_OUT_CHANNEL;
parameter c2_OUT_CHANNEL       =  16;
parameter c2_KERNEL_SIZE       =  3;
parameter c2_PADDING           =  1;
parameter c2_STRIDE            =  1;     
parameter c2_OUTPUT_PARALLEL   =  16;
parameter c2_WEIGHT_DATA_WIDTH =  in_WEIGHT_DATA_WIDTH;
parameter c2_WEIGHT_BASE_ADDR  =  32'd0000_0026;
parameter c2_ACTIVATION        =  "sigmoid";

// define for fifo4
parameter f4_DATA_WIDTH  =  in_DATA_WIDTH*c2_OUT_CHANNEL;
parameter f4_DEPTH       =  pDEPTH;  

//define for pool
parameter pool2_DATA_WIDTH    = in_DATA_WIDTH;
parameter pool2_INPUT_WIDTH   = 64; //tinh theo cong thuc
parameter pool2_INPUT_HEIGHT  = 64; //tinh theo cong thuc
parameter pool2_CHANNEL       = c2_OUT_CHANNEL;
parameter pool2_KERNEL_SIZE   = 2;
parameter pool2_PADDING       = 0;
parameter pool2_STRIDE        = 2;
parameter pool2_POOLING_TYPE  = "max" ;

// define for fifo5
parameter f5_DATA_WIDTH  =  in_DATA_WIDTH*pool2_CHANNEL;
parameter f5_DEPTH       =  pDEPTH; 

//define for fc1
parameter fc1_DATA_WIDTH          =  in_DATA_WIDTH;
parameter fc1_IN_FEATURE          =  32*32*pool2_CHANNEL; //tinh theo cong thuc
parameter fc1_OUT_FEATURE         =  128;
parameter fc1_CHANNEL             =  pool2_CHANNEL;
parameter fc1_OUTPUT_PARALLEL     =  4;
parameter fc1_WEIGHT_DATA_WIDTH   =  in_WEIGHT_DATA_WIDTH;
parameter fc1_WEIGHT_BASE_ADDR    =  32'd0000_0107;
parameter fc1_ACTIVATION          =  "sigmoid";

// define for fifo6
parameter f6_DATA_WIDTH  =  in_DATA_WIDTH*fc1_OUT_FEATURE;
parameter f6_DEPTH       =  pDEPTH; 

//define for fc2
parameter fc2_DATA_WIDTH          =  in_DATA_WIDTH;
parameter fc2_IN_FEATURE          =  fc1_OUT_FEATURE; 
parameter fc2_OUT_FEATURE         =  3;
parameter fc2_CHANNEL             =  fc1_OUT_FEATURE;
parameter fc2_OUTPUT_PARALLEL     =  1;
parameter fc2_WEIGHT_DATA_WIDTH   =  in_WEIGHT_DATA_WIDTH;
parameter fc2_WEIGHT_BASE_ADDR    =  32'd0000_6444 ;
parameter fc2_ACTIVATION          =  "softmax";


`endif