class cnn_sequence extends uvm_sequence #(cnn_sequence_item);

  localparam pDATA_WIDTH  = 8;

  localparam pINPUT_WIDTH = 128;
  localparam pINPUT_HEIGHT = 128;
  localparam pINPUT_CHANNEL = 3;
  
  localparam pWEIGHT_DATA_WIDTH = 64;
  localparam pWEIGHT_BASE_ADDR = 32'd0000_0000;
  
  // Weights configuration for Model Backbones
  localparam pKERNEL_NUM_CONV1 = 3*16*9/8; // Need to verify actual shapes but kept existing struct
  localparam pBIAS_NUM_CONV1 = 16/2;
  
  localparam pKERNEL_NUM_CONV2 = 16*16*9/8;
  localparam pBIAS_NUM_CONV2 = 16/2;
  
  localparam pKERNEL_NUM_CONV3 = 16*16*9/8;
  localparam pBIAS_NUM_CONV3 = 16/2;
  
  localparam pKERNEL_NUM_CONV4 = 16*16*9/8;
  localparam pBIAS_NUM_CONV4 = 16/2;
  
  localparam pKERNEL_NUM_CONV5 = 16*16*9/8;
  localparam pBIAS_NUM_CONV5 = 16/2;
  

  
  localparam pWEIGHT_BASE_ADDR_CONV1  = pWEIGHT_BASE_ADDR;
  localparam pWEIGHT_BASE_ADDR_CONV2  = pWEIGHT_BASE_ADDR_CONV1 + pKERNEL_NUM_CONV1/6  + pBIAS_NUM_CONV1 + 1;
  localparam pWEIGHT_BASE_ADDR_CONV3  = pWEIGHT_BASE_ADDR_CONV2 + pKERNEL_NUM_CONV2/32 + pBIAS_NUM_CONV2 + 1;
  localparam pWEIGHT_BASE_ADDR_CONV4  = pWEIGHT_BASE_ADDR_CONV3 + pKERNEL_NUM_CONV3/32 + pBIAS_NUM_CONV3 + 1;
  localparam pWEIGHT_BASE_ADDR_CONV5  = pWEIGHT_BASE_ADDR_CONV4 + pKERNEL_NUM_CONV4/32 + pBIAS_NUM_CONV4 + 1;

  
  localparam pWEIGHTS_NUM = 2000; // Increased buffer

  `uvm_object_utils(cnn_sequence);
  
  function new (input string name = "cnn_sequence");
    super.new(name);
  endfunction
    
  virtual task body ();

    logic en;
    logic load_weight;
    logic [31:0] weight_addr;
    logic [pWEIGHT_DATA_WIDTH-1:0] weight_data;
    logic [pDATA_WIDTH*pINPUT_CHANNEL-1:0] data_in;
    
    int ram_idx;
    int scale;
    int addr;
    int idx;
    
    logic [pDATA_WIDTH*pINPUT_CHANNEL-1:0] image [0:pINPUT_WIDTH*pINPUT_HEIGHT-1];
    logic [pWEIGHT_DATA_WIDTH-1:0] weights [0:pWEIGHTS_NUM-1];
    
    int dataset_file;
    int result_file;
    string image_path;
    
    // Updated path to current structure
    dataset_file = $fopen("../../software/txt/dataset.txt", "r");
    result_file = $fopen("../../software/txt/result_fpga.txt", "w");
    
    if (!dataset_file) begin
      $display("dataset file was not open successfully\n");
      $finish;
    end
    
    if (!result_file) begin
      $display("result file was not open successfully!\n");
      $finish;
    end
    
    $readmemh("../../software/txt/weights.txt", weights);
    
    idx = 0;
    en = 1'b0;
    load_weight = 1'b0;
    weight_addr = 'b0;
    weight_data = 'b0;
    data_in = 'b0;
    
    ram_idx = 0;
    scale = 0;
    addr = 0;
    
    load_weight = 1'b1;
    
    // conv1 weight
    for (int i = 0; i < pKERNEL_NUM_CONV1; i = i+1) begin
      weight_addr = i - ram_idx - 5*scale + pWEIGHT_BASE_ADDR_CONV1;
      weight_data = weights[addr++];
      
      if (ram_idx == 5) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end   
    
    for (int i = 0; i < pBIAS_NUM_CONV1; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV1 + pKERNEL_NUM_CONV1/6;
      weight_data = weights[addr++];
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    
    // conv2 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV2; i = i+1) begin
      weight_addr = i - ram_idx - 31*scale + pWEIGHT_BASE_ADDR_CONV2;
      weight_data = weights[addr++];
    
      if (ram_idx == 31) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV2; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV2 + pKERNEL_NUM_CONV2/32;
      weight_data = weights[addr++];
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    
    // conv3 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV3; i = i+1) begin
      weight_addr = i - ram_idx - 31*scale + pWEIGHT_BASE_ADDR_CONV3;
      weight_data = weights[addr++];
      
      if (ram_idx == 31) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV3; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV3 + pKERNEL_NUM_CONV3/32;
      weight_data = weights[addr++];
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    
    // conv4 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV4; i = i+1) begin
      weight_addr = i - ram_idx - 31*scale + pWEIGHT_BASE_ADDR_CONV4;
      weight_data = weights[addr++];
      
      if (ram_idx == 31) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV4; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV4 + pKERNEL_NUM_CONV4/32;
      weight_data = weights[addr++];
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    
    // conv5 weight
    ram_idx = 0;
    scale = 0;
    for (int i = 0; i < pKERNEL_NUM_CONV5; i = i+1) begin       // Fixed from pKERNEL_NUM_CONV3
      weight_addr = i - ram_idx - 31*scale + pWEIGHT_BASE_ADDR_CONV5;
      weight_data = weights[addr++];
      
      if (ram_idx == 31) begin
        ram_idx = 0;
        scale = scale + 1;
      end else begin
        ram_idx = ram_idx + 1;
      end
    end
    
    ram_idx = 0;
    scale = 0;
    
    for (int i = 0; i < pBIAS_NUM_CONV5; i = i+1) begin
      weight_addr = i + pWEIGHT_BASE_ADDR_CONV5 + pKERNEL_NUM_CONV5/32;
      weight_data = weights[addr++];
    end
    
    weight_addr++;
    weight_data = weights[addr++];
    

    

    load_weight = 1'b0;
    #100; // Small delay before feeding image
    
    // load image    
    while (!$feof(dataset_file)) begin
      $fgets(image_path, dataset_file);
      image_path = image_path.substr(0, image_path.len()-2);  // remove "\n"
      $readmemh(image_path, image);
      
      en = 1'b1;
      for (int j=0; j < pINPUT_WIDTH*pINPUT_HEIGHT; j = j+1) begin
      data_in = image[j];
      #10; // Assuming 10ns clock period
      end
      en = 1'b0;
      
      // Wait for inference to complete
      #100000;
  end
  $fclose(dataset_file);
  $fclose(result_file);
  $display("Simulation Stimulus Completed.");
  
  endtask

endclass
