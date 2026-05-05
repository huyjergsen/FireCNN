module test_ip(a,b,c,clk,rst);

    input clk;
    input a,b, rst;
    output c;

    always_ff @(posedge clk) begin
        if(rst == 1) c<= 0;
        else c <= a + b;
    end
    
endmodule