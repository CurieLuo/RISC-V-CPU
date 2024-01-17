`include "consts.v"
module InstUnit #(parameter ROB_WIDTH
) (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,

  //instruction fetch
  output wire [31:0] iu_to_ic_pc,
  input wire ic_to_iu_ready,
  input wire [31:0] ic_to_iu_inst,

  //get rs1 and rs2 (instantly)
  output wire [4:0] iu_to_rf_rs1_id,
  input wire [31:0] rf_to_iu_val1,
  input wire [ROB_WIDTH-1:0] rf_to_iu_rs1_depend,
  output wire [4:0] iu_to_rf_rs2_id,
  input wire [31:0] rf_to_iu_val2,
  input wire [ROB_WIDTH-1:0] rf_to_iu_rs2_depend,

  input wire rob_full,
  input wire [ROB_WIDTH-1:0] rob_new_idx,
  output wire [ROB_WIDTH-1:0] iu_to_rob_rs1_depend,
  input wire rob_to_iu_rs1_ready,
  input wire [31:0] rob_to_iu_val1,
  output wire [ROB_WIDTH-1:0] iu_to_rob_rs2_depend,
  input wire rob_to_iu_rs2_ready,
  input wire [31:0] rob_to_iu_val2,

  input wire lsb_full,
  input wire lsb_ready,
  input wire [ROB_WIDTH-1:0] lsb_rob_idx,
  input wire [31:0] lsb_val,
  //TODO!
  input wire rs_full,
  input wire rs_ready,
  input wire [ROB_WIDTH-1:0] rs_rob_idx,
  input wire [31:0] rs_val,
  input wire rs_actual_br,
  input wire [31:0] rs_pc_jump,
  //TODO!

  output reg issue_ready,
  output reg issue_rs_ready,
  output reg issue_lsb_ready,
  output reg [4:0] issue_rd_id,
  output reg [ROB_WIDTH-1:0] issue_rob_idx, // the index of the entry to be filled
  output reg [31:0] issue_val1, // val1 and val2 might be immediates
  output reg [ROB_WIDTH-1:0] issue_rs1_depend,
  output reg [31:0] issue_val2,
  output reg [ROB_WIDTH-1:0] issue_rs2_depend,
  output reg [5:0] issue_op_id,
  output reg [6:0] issue_opcode,
  output reg [31:0] issue_pc,
  output reg [31:0] issue_offset,
  output reg issue_prediction,

  output wire [31:0] iu_to_bp_pc,
  input wire bp_to_iu_prediction
);

  reg [31:0] pc, inst, pc_jump;
  reg inst_ready;
  
  reg stall;
  assign iu_to_bp_pc = pc;
  assign iu_to_ic_pc = pc;
  wire opcode = inst[6:0];
  wire prediction=opcode==OPCODE_B?bp_to_iu_prediction:(opcode==`OPCODE_JAL||opcode==`OPCODE_JALR);
  //TODO

  always@(posedge clk_in) begin //instruction fetch
    if (rst_in) begin
      pc<=8'hfffffffc;//TODO!!!
      inst<=0;
      inst_ready<=0;
      stall<=0;
      pc_jump<=0;
    end
    else if (rdy_in) begin
      if (clr_in)begin
        inst_ready<=0;
        pc<=//rob
        //TODO
      end
      else if (!stall) begin
        pc<=prediction?pc_jump:pc+4;//TODO!!!
        inst_ready<=0;
      end
      if (!inst_ready&&ic_to_iu_ready) begin
          inst_ready<=1;
          inst<=ic_to_iu_inst;
        end
    end
  end

  assign iu_to_rob_rs1_depend = rf_to_iu_rs1_depend;
  assign iu_to_rob_rs2_depend = rf_to_iu_rs2_depend;

  wire sub_opcode = inst[14:12];
  assign iu_to_rf_rs1_id=inst[19:15];
  assign iu_to_rf_rs2_id=inst[24:20];
  wire [31:0] imm_B = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_I = {{20{inst[31]}}, inst[31:20]};
  wire [31:0] imm_S = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  wire [31:0] imm_shamt = {27{0},inst[24:20]};

  always@(*) begin //instruction decode & issue
  stall=0;
  issue_ready=0;
  //TODO
  if (rst_in||!rdy_in||clr_in||rob_full||rs_full||lsb_full) stall = 1; // optimize (rs,lsb)
  if(!stall&&inst_ready) begin

    issue_rd_id=inst[11:7];
    issue_rob_idx=0;
    issue_op_id=`OP_NOP;
    issue_rd=inst[11:7];
    issue_rs1_depend=0;
    issue_rs2_depend=0;
    issue_val1=0;
    issue_val2=0;
    issue_pc=pc;
    issue_rob_idx=rob_new_idx;
    issue_prediction=prediction;
    issue_opcode=opcode;//TODO wire

    inst_ready=0;issue_ready=1; // optimize (rs,lsb)
    if (rf_to_iu_rs1_depend==0) issue_val1=rf_to_iu_val1;
    else if (rob_to_iu_rs1_ready) issue_val1=rob_to_iu_val1;
    else issue_rs1_depend=rf_to_iu_rs1_depend;
    //TODO!!! rs,lsb
    if (rf_to_iu_rs2_depend==0) issue_val2=rf_to_iu_val2;
    else if (rob_to_iu_rs2_ready) issue_val2=rob_to_iu_val2;
    else issue_rs2_depend=rf_to_iu_rs2_depend;

    case (opcode)
      `OPCODE_LUI:begin
        issue_rs_ready=1;
        issue_op_id=`OP_LUI;
        issue_rs1_depend=0;
        issue_rs2_depend=0;
        issue_val1={inst[31:12],12'b0};
        issue_val2=0;
      end
      `OPCODE_AUIPC:begin
        issue_rs_ready=1;
        issue_op_id=`OP_AUIPC;
        issue_rs1_depend=0;
        issue_rs2_depend=0;
        issue_val1={inst[31:12],12'b0};
        issue_val2=0;
      end
      `OPCODE_JAL:begin
        issue_rs_ready=1;
        issue_op_id=`OP_JAL;
        issue_rs1_depend=0;
        issue_rs2_depend=0;
        issue_offset={{12{inst[31]}}, inst[19:12], inst[20], inst[30:21],1'b0};
        pc_jump=pc+issue_offset;
      end
      `OPCODE_JALR: begin
        issue_rs_ready=1;
        issue_op_id=`OP_JALR;
        issue_rs2_depend=0;
        issue_offset=imm_I;
        pc_jump=pc+4; // TODO
        //stall=1;
      end
      `OPCODE_B: begin
        issue_rs_ready=1;
        case (sub_opcode)
          3'b000:issue_op_id=OP_BEQ;
          3'b001:issue_op_id=OP_BNE;
          3'b100:issue_op_id=OP_BLT;
          3'b101:issue_op_id=OP_BGE;
          3'b110:issue_op_id=OP_BLTU;
          3'b111:issue_op_id=OP_BGEU;
        endcase
        issue_rd_id=0;
        issue_offset=imm_B;
        pc_jump=pc+issue_offset;
      end
      `OPCODE_L:begin
        issue_lsb_ready=1;
        case (sub_opcode)
          3'b000:issue_op_id=OP_LB;
          3'b001:issue_op_id=OP_LH;
          3'b010:issue_op_id=OP_LW;
          3'b100:issue_op_id=OP_LBU;
          3'b101:issue_op_id=OP_LHU;
        endcase
        issue_rs2_depend=0;
        issue_offset=imm_L;
      end
      `OPCODE_S:begin
        issue_lsb_ready=1;
        case (sub_opcode)
          3'b000:issue_op_id=OP_SB;
          3'b001:issue_op_id=OP_SH;
          3'b010:issue_op_id=OP_SW;
        endcase
        issue_rd_id=0;
        issue_offset=imm_S;
      end
      `OPCODE_I:begin
        issue_rs_ready=1;
        issue_rs2_depend=0;
        issue_val2=imm_I;
        case (sub_opcode)
          3'b000:issue_op_id=OP_ADDI;
          3'b001:begin
            issue_op_id=OP_SLLI;
            issue_val2=imm_shamt;
          end
          3'b010:issue_op_id=OP_SLTI;
          3'b011:issue_op_id=OP_SLTIU;
          3'b100:issue_op_id=OP_XORI;
          3'b101: begin
            issue_op_id=inst[30]==0?OP_SRLI:OP_SRAI;
            issue_val2=imm_shamt;
          end
          3'b110:issue_op_id=OP_ORI;
          3'b111:issue_op_id=OP_ANDI;
        endcase
      end
      `OPCODE_R:begin
        issue_rs_ready=1;
        case (sub_opcode)
          3'b000:issue_op_id=inst[30]==0?OP_ADD:OP_SUB;
          3'b001:issue_op_id=OP_SLL;
          3'b010:issue_op_id=OP_SLT;
          3'b011:issue_op_id=OP_SLTU;
          3'b100:issue_op_id=OP_XOR;
          3'b101:issue_op_id=inst[30]==0?OP_SRL:SRA;
          3'b110:issue_op_id=OP_OR;
          3'b111:issue_op_id=OP_AND;
        endcase
      end
    endcase
  end
  end
  

endmodule