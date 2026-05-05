`include "cnn_pkg.sv"
`include "test_ip.sv"
import uvm_pkg::*;

module testbench ();
  import cnn_pkg::*;

  localparam pPERIOD = 10;
  
  logic clk;
  logic rst;
  logic a,b,c;   
  
  cnn_interface #(
    .pWEIGHT_DATA_WIDTH(64),
    .pDATA_WIDTH(24)
  ) intf (
    .clk(clk),
    .rst(rst)
  );

  test_ip test_ip (
     .clk	(	clk		)
    ,.rst(	rst)
    ,.a(a)
    ,.b(b)
    ,.c(c)
  );
  
  always #(pPERIOD/2) clk <= !clk;
  
  initial begin
    clk = 1'b0;
    rst = 1'b0;
    
    #pPERIOD;
    rst  = 1'b1;
  end
  
  initial begin
    uvm_config_db #(virtual cnn_interface)::set(uvm_root::get(), "*", "vif", intf);
    run_test();
  end

endmodule

`endif