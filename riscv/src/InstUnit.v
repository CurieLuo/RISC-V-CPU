`include "consts.v"
module InstUnit #(parameter ROB_WIDTH
) (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,

  //instruction fetch
  output wire [31:0] iu_to_ic_pc,
  input wire ic_to_iu_rdy,
  input wire [31:0] ic_to_iu_inst,

  //get rs1 and rs2 (instantly)
  output wire [4:0] iu_to_rf_rs1_id,
  input wire [31:0] rf_to_iu_rs1_val,
  input wire [ROB_WIDTH-1:0] rf_to_iu_rs1_depend,
  output wire [4:0] iu_to_rf_rs2_id,
  input wire [31:0] rf_to_iu_rs2_val,
  input wire [ROB_WIDTH-1:0] rf_to_iu_rs2_depend,

  input wire rob_full,
  input wire [ROB_WIDTH-1:0] rob_new_idx,
  output wire [ROB_WIDTH-1:0] iu_to_rob_rs1_depend,
  input wire rob_to_iu_rs1_rdy,
  input wire [31:0] rob_to_iu_rs1_val,
  output wire [ROB_WIDTH-1:0] iu_to_rob_rs2_depend,
  input wire rob_to_iu_rs2_rdy,
  input wire [31:0] rob_to_iu_rs2_val,

  input wire rs_full,
  //TODO
  input wire lsb_full,

  output reg issue_rdy,
  output reg issue_rs_rdy,
  output reg issue_lsb_rdy,
  output reg [4:0] issue_rd_id,
  output reg [ROB_WIDTH-1:0] issue_rob_idx, // the index of the entry to be filled
  output reg [31:0] issue_rs1_val, // rs1_val and rs2_val might be immediates
  output reg [ROB_WIDTH-1:0] issue_rs1_depend,
  output reg [31:0] issue_rs2_val,
  output reg [ROB_WIDTH-1:0] issue_rs2_depend,
  output reg [5:0] issue_op_id,
  output reg [31:0] issue_pc,
  output reg [31:0] issue_imm,
  output reg issue_prediction,

  output wire [31:0] iu_to_bp_pc,
  input wire bp_to_iu_prediction
);

  reg [31:0] pc, inst, pc_jump;
  reg inst_rdy;
  
  reg stall;
  assign iu_to_bp_pc = pc;
  assign iu_to_ic_pc = pc;
  //TODO

  always@(posedge clk_in) begin //instruction fetch
    if (rst_in) begin
      pc<=8'hfffffffc;//TODO!!!
      inst<=0;
      inst_rdy<=0;
      stall<=0;
      pc_jump<=0;
    end
    else if (rdy_in) begin
      if (clr_in)begin
        inst_rdy<=0;
        pc<=
        //TODO
      end
      else if (!stall) begin
        pc<=bp_to_iu_prediction?pc_jump:pc+4;//TODO!!!
        inst_rdy<=0;
      end
      if (!inst_rdy&&ic_to_iu_rdy) begin
          inst_rdy<=1;
          inst<=ic_to_iu_inst;
        end
      end
    end
  end

  assign iu_to_rob_rs1_depend = rf_to_iu_rs1_depend;
  assign iu_to_rob_rs2_depend = rf_to_iu_rs2_depend;

  wire opcode = inst[6:0];
  wire sub_opcode = inst[14:12];
  assign iu_to_rf_rs1_id=inst[19:15];
  assign iu_to_rf_rs2_id=inst[24:20];
  wire [31:0] imm_B = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_I = {{20{inst[31]}}, inst[31:20]};
  wire [31:0] imm_S = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  wire [31:0] imm_shamt = {27{0},inst[24:20]};

  always@(*) begin //instruction decode & issue
  stall=0;
  issue_rdy=0;
  issue_rd_id=inst[11:7];
  issue_rob_idx=0;
  issue_op_id=`OP_NOP;
  issue_rd=inst[11:7];
  issue_rs1_depend=0;
  issue_rs2_depend=0;
  issue_rs1_val=0;
  issue_rs2_val=0;
  issue_pc=pc;
  issue_rob_idx=rob_new_idx;
  //TODO
  if (rst_in||!rdy_in||clr_in||rob_full||rs_full||lsb_full) stall = 1; // optimize (rs,lsb)
  else if(inst_rdy) begin
    inst_rdy=0;issue_rdy=1; // optimize (rs,lsb)
    if (rf_to_iu_rs1_depend==0) issue_rs1_val=rf_to_iu_rs1_val;
    else if (rob_to_iu_rs1_rdy) issue_rs1_val=rob_to_iu_rs1_val;
    else issue_rs1_depend=rf_to_iu_rs1_depend;
    //TODO rs,lsb
    if (rf_to_iu_rs2_depend==0) issue_rs2_val=rf_to_iu_rs2_val;
    else if (rob_to_iu_rs2_rdy) issue_rs2_val=rob_to_iu_rs2_val;
    else issue_rs2_depend=rf_to_iu_rs2_depend;

    case (opcode)
      `OPCODE_LUI:begin
        issue_op_id=`OP_LUI;
        issue_rs1_depend=0;
        issue_rs2_depend=0;
        issue_rs1_val={inst[31:12],12'b0};
        issue_rs2_val=0;
      end
      `OPCODE_AUIPC:begin
        issue_op_id=`OP_AUIPC;
        issue_rs1_depend=0;
        issue_rs2_depend=0;
        issue_rs1_val={inst[31:12],12'b0};
        issue_rs2_val=0;
      end
      `OPCODE_JAL:begin
        issue_op_id=`OP_JAL;
        issue_rs1_depend=0;
        issue_rs2_depend=0;
        issue_rs1_val=pc+4;
        issue_rs2_val=0;
        issue_imm={{12{inst[31]}}, inst[19:12], inst[20], inst[30:21],1'b0};
        pc_jump=pc+issue_imm;
      end
      `OPCODE_JALR: begin
        issue_rs_rdy=1;
        issue_op_id=`OP_JALR;
        issue_rs2_depend=0;
        issue_rs2_val=imm_I; //TODO
        pc_jump=pc+4; // TODO
      end
      `OPCODE_B: begin
        issue_rs_rdy=1;
        case (sub_opcode)
          3'b000:issue_op_id=OP_BEQ;
          3'b001:issue_op_id=OP_BNE;
          3'b100:issue_op_id=OP_BLT;
          3'b101:issue_op_id=OP_BGE;
          3'b110:issue_op_id=OP_BLTU;
          3'b111:issue_op_id=OP_BGEU;
        endcase
        issue_rd_id=0;
        issue_imm=imm_B;
        pc_jump=pc+issue_imm;
      end
      `OPCODE_L:begin
        issue_lsb_rdy=1;
        case (sub_opcode)
          3'b000:issue_op_id=OP_LB;
          3'b001:issue_op_id=OP_LH;
          3'b010:issue_op_id=OP_LW;
          3'b100:issue_op_id=OP_LBU;
          3'b101:issue_op_id=OP_LHU;
        endcase
        issue_rs2_depend=0;
        issue_imm=imm_L;
      end
      `OPCODE_S:begin
        issue_lsb_rdy=1;
        case (sub_opcode)
          3'b000:issue_op_id=OP_SB;
          3'b001:issue_op_id=OP_SH;
          3'b010:issue_op_id=OP_SW;
        endcase
        issue_rd_id=0;
        issue_imm=imm_S;
      end
      `OPCODE_I:begin
        issue_rs_rdy=1;
        issue_rs2_depend=0;
        issue_rs2_val=imm_I;
        case (sub_opcode)
          3'b000:issue_op_id=OP_ADDI;
          3'b001:begin
            issue_op_id=OP_SLLI;
            issue_rs2_val=imm_shamt;
          end
          3'b010:issue_op_id=OP_SLTI;
          3'b011:issue_op_id=OP_SLTIU;
          3'b100:issue_op_id=OP_XORI;
          3'b101: begin
            issue_op_id=inst[30]==0?OP_SRLI:OP_SRAI;
            issue_rs2_val=imm_shamt;
          end
          3'b110:issue_op_id=OP_ORI;
          3'b111:issue_op_id=OP_ANDI;
        endcase
      end
      `OPCODE_R:begin
        issue_rs_rdy=1;
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