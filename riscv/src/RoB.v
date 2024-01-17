`include "consts.v"

module ReorderBuffer #(parameter ROB_WIDTH
) (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  output reg clr_in,
  output reg rob_full,
  output reg rob_new_idx,

  input wire [ROB_WIDTH-1:0] iu_to_rob_rs1_depend,
  output wire rob_to_iu_rs1_rdy,
  output wire [31:0] rob_to_iu_rs1_val,
  input wire [ROB_WIDTH-1:0] iu_to_rob_rs2_depend,
  output wire rob_to_iu_rs2_rdy,
  output wire [31:0] rob_to_iu_rs2_val,

  input wire lsb_rdy,

  input wire rs_rdy,

  input wire issue_rdy,
  input wire [5:0] issue_op_id,
  input wire [4:0] issue_rd_id,
  input wire [31:0] issue_pc,
  input wire issue_prediction,

)

  parameter ROB_SIZE=2**ROB_WIDTH;
  reg [ROB_WIDTH-1:0] head, tail; // closed intervals
  reg rdy [ROB_SIZE-1:0]; // ready to commit
  reg [5:0] op_id [ROB_SIZE-1:0];
  reg [4:0] rd_id [ROB_SIZE-1:0];
  reg [31:0] val [ROB_SIZE-1:0];
  reg [31:0] pc [ROB_SIZE-1:0];
  reg pred_br [ROB_SIZE-1:0];
  reg actual_br [ROB_SIZE-1:0];

  wire [ROB_WIDTH-1:0] next_head = head+1==ROB_SIZE?1:head+1;
  wire [ROB_WIDTH-1:0] next_tail = tail+1==ROB_SIZE?1:tail+1;
  assign rob_full = next_tail==head;
  wire rob_empty = tail==head;
  assign rob_new_index=next_tail;
  assign rob_to_iu_rs1_rdy=rdy[iu_to_rob_rs1_depend];
  assign rob_to_iu_rs1_val=val[iu_to_rob_rs1_depend];
  assign rob_to_iu_rs2_rdy=rdy[iu_to_rob_rs2_depend];
  assign rob_to_iu_rs2_val=val[iu_to_rob_rs2_depend];

  integer i;
  always @(posedge clk_in) begin
    if (rst_in||clr_in) begin
      clr_in<=0;
      head<=1;
      tail<=1;
      for(i=0;i<ROB_SIZE;i=i+1) begin
        rdy[i]<=0;
        //TODO
      end
    end
    else if (rdy_in) begin
      if (lsb_rdy) begin
        //TODO
      end
      else if (rs_rdy) begin
        //TODO
      end
      else if (issue_rdy) begin
        rdy[next_tail]<=0;
        op_id[next_tail]<=issue_op_id;
        rd_id[next_tail]<=issue_rd_id;
        pc[next_tail]<=issue_pc;
        pred_br[next_tail]<=issue_prediction;
        // TODO LUI,AUIPC,JAL not added to RS yet
      end
    end
  end

endmodule