`include "consts.v"

module RegFile #( parameter ROB_WIDTH
) (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low
  input wire clr_in,

  // update new dependency when a new instruction is issued
  input wire issue_ready,
  input wire [4:0] issue_rd_id,
  input wire [ROB_WIDTH-1:0] issue_rob_idx

  input wire rob_to_rf_commit,
  input wire [4:0] rob_to_rf_reg_id,
  input wire [31:0] rob_to_rf_reg_val,
  input wire [ROB_WIDTH-1:0] rob_to_rf_rob_idx,

);
  
  reg [31:0] val[31:0];
  reg [ROB_WIDTH-1:0] depend[31:0];
  integer i;
  always @(posedge clk_in) begin
    if (rst_in) begin
      for(i=0;i<32;i=i+1) begin
        val[i]<=0;
        depend[i]<=0;//use 0 as null value
      end
    end
    else if (rdy_in) begin
      if (clr_in) begin
        for(i=0;i<32;i=i+1) begin
          depend[i]<=0;
        end
      end
      if (rob_to_rf_commit && rob_to_rf_reg_id!=0) begin
        if (depend[rob_to_rf_reg_id]==rob_to_rf_rob_idx) begin
          depend[rob_to_rf_reg_id]<=0;
          //TODO
        end
        val[rob_to_rf_reg_id]<=rob_to_rf_reg_val;
      end
      // TODO order
      if (issue_ready&&issue_rd_id!=0) depend[issue_rd_id]=issue_rob_idx;
    end
  end


endmodule