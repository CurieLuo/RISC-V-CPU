`include "consts.v"

module ReorderBuffer #(parameter ROB_WIDTH) (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  output reg clr_in,
  output reg rob_full,
  output reg rob_new_index,

  input wire [ROB_WIDTH-1:0] iu_to_rob_rs1_depend,
  output wire rob_to_iu_rs1_ready,
  output wire [31:0] rob_to_iu_val1,
  input wire [ROB_WIDTH-1:0] iu_to_rob_rs2_depend,
  output wire rob_to_iu_rs2_ready,
  output wire [31:0] rob_to_iu_val2,
  output reg [31:0] rob_to_iu_actual_pc,

  input wire lsb_ready,
  input wire [ROB_WIDTH-1:0] lsb_rob_index,
  input wire [31:0] lsb_val,

  input wire rs_ready,
  input wire [ROB_WIDTH-1:0] rs_rob_index,
  input wire [31:0] rs_val,
  input wire rs_actual_br,
  input wire [31:0] rs_pc_jump,

  input wire issue_ready,
  input wire [5:0] issue_op_id,
  input wire [6:0] issue_opcode,
  input wire [4:0] issue_rd_id,
  input wire [31:0] issue_pc,
  input wire issue_prediction,

  output reg rob_to_rf_ready, // commit
  output reg [4:0] rob_to_rf_reg_id,
  output reg [31:0] rob_to_rf_reg_val,
  output reg [ROB_WIDTH-1:0] rob_to_rf_rob_index,

  output reg rob_to_bp_ready,
  output reg [31:0] rob_to_bp_pc,
  output reg rob_to_bp_actual_br
);

  parameter ROB_SIZE=2**ROB_WIDTH;
  reg [ROB_WIDTH-1:0] head, tail; // (head,tail]
  reg ready [ROB_SIZE-1:0]; // ready to commit
  reg [5:0] op_id [ROB_SIZE-1:0];
  reg [4:0] rd_id [ROB_SIZE-1:0];
  reg [31:0] val [ROB_SIZE-1:0];
  reg [31:0] pc_jump [ROB_SIZE-1:0];
  reg [31:0] pc [ROB_SIZE-1:0];
  reg pred_br [ROB_SIZE-1:0];
  reg actual_br [ROB_SIZE-1:0];

  wire [ROB_WIDTH-1:0] next_head = head+1==ROB_SIZE?1:head+1;
  wire [ROB_WIDTH-1:0] next_tail = tail+1==ROB_SIZE?1:tail+1;
  assign rob_full = next_tail==head;
  wire rob_empty = tail==head;
  assign rob_new_index=next_tail;
  assign rob_to_iu_rs1_ready=ready[iu_to_rob_rs1_depend];
  assign rob_to_iu_val1=val[iu_to_rob_rs1_depend];
  assign rob_to_iu_rs2_ready=ready[iu_to_rob_rs2_depend];
  assign rob_to_iu_val2=val[iu_to_rob_rs2_depend];

  always @(posedge clk_in) begin
    if (rst_in||clr_in) begin
      clr_in<=0;
      head<=1;
      tail<=1;
      rob_to_bp_ready<=0;
      rob_to_rf_ready<=0;
    end
    else if (rdy_in) begin
      if (lsb_ready) begin
        ready[lsb_rob_index]<=1;
        val[lsb_rob_index]<=lsb_val;
      end
      if (rs_ready) begin
        ready[rs_rob_index]<=1;
        val[rs_rob_index]<=rs_val;
        actual_br[rs_rob_index]<=rs_actual_br;
        pc_jump[rs_rob_index]<=rs_pc_jump;
      end
      if (issue_ready) begin
        ready[next_tail]<=0;
        actual_br[next_tail]<=0;//issue_op_id==`OP_JAL
        op_id[next_tail]<=issue_op_id;
        rd_id[next_tail]<=issue_rd_id;
        pc[next_tail]<=issue_pc;
        pred_br[next_tail]<=issue_prediction;
        tail<=next_tail;
      end
      //commit
      if (!rob_empty&&ready[next_head])begin
        head<=next_head;
        rob_to_rf_ready<=1;
        rob_to_rf_reg_id<=rd_id[next_head];
        rob_to_rf_reg_val<=val[next_head];
        rob_to_rf_rob_index<=next_head;
        //wrong prediction
        if (op_id[next_head]==`OP_JALR||pred_br[next_head]!=actual_br[next_head]) begin
          clr_in<=1;
          rob_to_iu_actual_pc<=actual_br[next_head]?pc_jump[next_head]:(pc[next_head]+4);
        end
        if (issue_opcode==`OPCODE_B) begin
          rob_to_bp_ready<=1;
          rob_to_bp_pc<=pc[next_head];
          rob_to_bp_actual_br<=actual_br[next_head];
        end
      end
      else begin
        rob_to_bp_ready<=0;
        rob_to_rf_ready<=0;
      end
    end
  end

endmodule