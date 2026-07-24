`timescale 1ns/1ps

module testbench();

  localparam pPERIOD = 4;

  localparam pDATA_WIDTH  = 8;

  localparam pINPUT_WIDTH = 128;
  localparam pINPUT_HEIGHT = 128;
  localparam pINPUT_CHANNEL = 3;
  
  localparam pWEIGHT_DATA_WIDTH = 64;
  localparam pWEIGHT_BASE_ADDR = 32'd0000_0000;
  
  localparam pKERNEL_NUM_CONV1 = 3*4*9/4;
  localparam pBIAS_NUM_CONV1 = 4/2;
  
  localparam pKERNEL_NUM_CONV2 = 4*4*9/8;
  localparam pBIAS_NUM_CONV2 = 4/2;
  
  localparam pKERNEL_NUM_CONV3 = 4*8*9/8;
  localparam pBIAS_NUM_CONV3 = 8/2;
  
  localparam pKERNEL_NUM_CONV4 = 8*8*9/8;
  localparam pBIAS_NUM_CONV4 = 8/2;
  
  localparam pKERNEL_NUM_CONV5 = 8*16*9/8;
  localparam pBIAS_NUM_CONV5 = 16/2;
  
  localparam pWEIGHT_NUM_FC = 4*4*16*2/8;
  localparam pBIAS_NUM_FC = 2/2;
  
  
  localparam pWEIGHT_BASE_ADDR_CONV1  = pWEIGHT_BASE_ADDR;
  localparam pWEIGHT_BASE_ADDR_CONV2  = pWEIGHT_BASE_ADDR_CONV1 + 9 + pBIAS_NUM_CONV1 + 1;
  localparam pWEIGHT_BASE_ADDR_CONV3  = pWEIGHT_BASE_ADDR_CONV2 + 9 + pBIAS_NUM_CONV2 + 1;
  localparam pWEIGHT_BASE_ADDR_CONV4  = pWEIGHT_BASE_ADDR_CONV3 + 9 + pBIAS_NUM_CONV3 + 1;
  localparam pWEIGHT_BASE_ADDR_CONV5  = pWEIGHT_BASE_ADDR_CONV4 + 9 + pBIAS_NUM_CONV4 + 1;
  localparam pWEIGHT_BASE_ADDR_FC     = pWEIGHT_BASE_ADDR_CONV5 + 9 + pBIAS_NUM_CONV5 + 1;
  
  localparam pWEIGHTS_NUM = 1317;
        
  logic clk;
  logic rst;
  logic en;
  logic load_weight;
  logic [31:0] weight_addr;
  logic [pWEIGHT_DATA_WIDTH-1:0] weight_data;
  logic [pDATA_WIDTH*pINPUT_CHANNEL-1:0] data_in;
  logic [31:0] data_out;
  logic valid;
  
  int ram_idx;
  int scale;
  int addr;
  int idx;

  always @(clk) #(pPERIOD/2) clk <= !clk;

  logic [pDATA_WIDTH*pINPUT_CHANNEL-1:0] image [0:pINPUT_WIDTH*pINPUT_HEIGHT-1];
  logic [pWEIGHT_DATA_WIDTH-1:0] weights [0:pWEIGHTS_NUM-1];
  
  int dataset_file;
  int result_file;
  int conv1_data,conv2_data,conv3_data,conv4_data,conv5_data;
  int pool1_data,pool2_data,pool3_data,pool4_data,pool5_data;
  string image_path;
  string dataset_path = "/home/quoc/Projects/top_KLTN/Dataset/dataset_hex";
  
  
  initial begin
    dataset_file = $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/txt/dataset.txt", "r");
    result_file = $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/txt/result_fpga.txt", "w");
    conv1_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/conv1.txt","w");
    conv2_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/conv2.txt","w");
    conv3_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/conv3.txt","w");
    conv4_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/conv4.txt","w");
    conv5_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/conv5.txt","w");
    pool1_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/pool1.txt","w");
    pool2_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/pool2.txt","w");
    pool3_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/pool3.txt","w");
    pool4_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/pool4.txt","w");
    pool5_data =  $fopen("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_fpga/pool5.txt","w");
    
    if (!dataset_file) begin
      $display("dataset file was not open successfully\n");
      $finish;
    end
    
    if (!result_file) begin
      $display("result file was not open successfully!\n");
      $finish;
    end
    
    $readmemh("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/txt/weights.txt", weights);
    
    idx = 0;
    
    clk = 1'b0;
    rst = 1'b1;
    en = 1'b0;
    load_weight = 1'b0;
    weight_addr = 'b0;
    weight_data = 'b0;
    data_in = 'b0;
    
    #pPERIOD;
    rst = 1'b0;
    load_weights();
    #(pPERIOD/2);
    
    // load image    
    while (!$feof(dataset_file)) begin
      $fgets(image_path, dataset_file);
      image_path = image_path.substr(0, image_path.len()-2);  // remove "\n"
      $readmemh(image_path, image);
      
      en = 1'b1;
      //#(pPERIOD/2);
      for (int j=0; j < pINPUT_WIDTH*pINPUT_HEIGHT; j = j+1) begin
        data_in = image[j];
        #pPERIOD;
      end
      en = 1'b0;
      @(posedge valid);
      #pPERIOD;
    end
    
    $fclose(dataset_file);
    $fclose(result_file);
    $finish;
  end
  
  always @(posedge valid) begin
        //$display("%h\n", data_out[0]);
       // $fwrite(result_file, data_out); 
  end
  
  always @(posedge clk) begin
    if(u_model.conv1_valid) $fdisplay(conv1_data,"%h",u_model.conv1_out); 
    if(u_model.conv2_valid) $fdisplay(conv2_data,"%h",u_model.conv2_out); 
    if(u_model.conv3_valid) $fdisplay(conv3_data,"%h",u_model.conv3_out); 
    if(u_model.conv4_valid) $fdisplay(conv4_data,"%h",u_model.conv4_out); 
    if(u_model.conv5_valid) $fdisplay(conv5_data,"%h",u_model.conv5_out); 
    if(u_model.pool1_valid) $fdisplay(pool1_data,"%h",u_model.pool1_out); 
    if(u_model.pool2_valid) $fdisplay(pool2_data,"%h",u_model.pool2_out);
    if(u_model.pool3_valid) $fdisplay(pool3_data,"%h",u_model.pool3_out);
    if(u_model.pool4_valid) $fdisplay(pool4_data,"%h",u_model.pool4_out);
    if(u_model.pool5_valid) $fdisplay(pool5_data,"%h",u_model.pool5_out);
  end
    
  model #(
     .pINPUT_WIDTH        ( pINPUT_WIDTH        )
    ,.pINPUT_HEIGHT       ( pINPUT_HEIGHT       )
    ,.pINPUT_CHANNEL      ( pINPUT_CHANNEL      )
    ,.pDATA_WIDTH         ( pDATA_WIDTH         )
    ,.pWEIGHT_DATA_WIDTH  ( pWEIGHT_DATA_WIDTH  )
    ,.pWEIGHT_BASE_ADDR   ( pWEIGHT_BASE_ADDR   )
  ) u_model (
     .clk         ( clk         )
    ,.rst         ( rst         )
    ,.en          ( en          )
    ,.load_weight ( load_weight )
    ,.weight_data ( weight_data )
    ,.weight_addr ( weight_addr )
    ,.data_in     ( data_in     )
    ,.data_out    ( data_out    )
    ,.valid       ( valid       )
  );
  
  task load_weights();
    ram_idx = 0;
    scale = 0;
    addr = 0;
    
    load_weight = 1'b1;
    
    // conv1 weight
    for (int i = 0; i < pKERNEL_NUM_CONV1; i = i+1) begin
      weight_addr = i - ram_idx - 2*scale + pWEIGHT_BASE_ADDR_CONV1;
      weight_data = weights[addr++];
      #pPERIOD;
      
      if (ram_idx == 2) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end   
    
    for (int i = 0; i < pBIAS_NUM_CONV1; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV1 + pKERNEL_NUM_CONV1/3;
      weight_data = weights[addr++];
      #pPERIOD;
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    #pPERIOD;
    
    // conv2 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV2; i = i+1) begin
      weight_addr = i - ram_idx - 1*scale + pWEIGHT_BASE_ADDR_CONV2;
      weight_data = weights[addr++];
      #pPERIOD;
      
      if (ram_idx == 1) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV2; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV2 + pKERNEL_NUM_CONV2/2;
      weight_data = weights[addr++];
      #pPERIOD;
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    #pPERIOD;
    
    // conv3 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV3; i = i+1) begin
      weight_addr = i - ram_idx - 3*scale + pWEIGHT_BASE_ADDR_CONV3;
      weight_data = weights[addr++];
      #pPERIOD;
      
      if (ram_idx == 3) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV3; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV3 + pKERNEL_NUM_CONV3/4;
      weight_data = weights[addr++];
      #pPERIOD;
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    #pPERIOD;
    
    // conv4 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV4; i = i+1) begin
      weight_addr = i - ram_idx - 7*scale + pWEIGHT_BASE_ADDR_CONV4;
      weight_data = weights[addr++];
      #pPERIOD;
      
      if (ram_idx == 7) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV4; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV4 + pKERNEL_NUM_CONV4/8;
      weight_data = weights[addr++];
      #pPERIOD;
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    #pPERIOD;
    
    // conv5 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV5; i = i+1) begin
      weight_addr = i - ram_idx - 15*scale + pWEIGHT_BASE_ADDR_CONV5;
      weight_data = weights[addr++];
      #pPERIOD;
      
      if (ram_idx == 15) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV5; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV5 + pKERNEL_NUM_CONV5/16;
      weight_data = weights[addr++];
      #pPERIOD;
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    #pPERIOD;
   
    // fc weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pWEIGHT_NUM_FC; i = i+1) begin
      weight_addr = i - ram_idx - 1*scale + pWEIGHT_BASE_ADDR_FC;
      weight_data = weights[addr++];
      #pPERIOD;
      
      if (ram_idx == 1) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end   
    
    for (int i = 0; i < pBIAS_NUM_FC; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_FC + pWEIGHT_NUM_FC/2;
      weight_data = weights[addr++];
      #pPERIOD;
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    #pPERIOD;
    
    #pPERIOD;
    load_weight = 1'b0;
  endtask
  
endmodule
