`include "consts.v"

module ReservationStation#(parameter ROB_WIDTH,parameter RS_WIDTH=4)(
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,
  output wire rs_full,
  
  input wire issue_rs_ready,
  input wire [ROB_WIDTH-1:0] issue_rob_idx,
  input wire [31:0] issue_val1, // val1 and val2 might be immediates
  input wire [ROB_WIDTH-1:0] issue_rs1_depend,
  input wire [31:0] issue_val2,
  input wire [ROB_WIDTH-1:0] issue_rs2_depend,
  input wire [5:0] issue_op_id,
  input wire [6:0] issue_opcode,
  input wire [31:0] issue_pc,
  input wire [31:0] issue_offset,

  // broadcast from LSB
  input wire lsb_ready,
  input wire [ROB_WIDTH-1:0] lsb_rob_idx,
  input wire [31:0] lsb_val,

  output reg rs_ready,
  output reg [ROB_WIDTH-1:0] rs_rob_idx,
  output reg [31:0] rs_val,
  output reg rs_actual_br,
  output reg [31:0] rs_pc_jump,

)
  parameter RS_SIZE=2**RS_WIDTH;
  reg [RS_SIZE-1:0] busy;
  reg op_id[RS_SIZE-1:0];
  reg opcode[RS_SIZE-1:0];//can be optimized
  reg [31:0] val1[RS_SIZE-1:0];
  reg [ROB_WIDTH-1:0] depend1[RS_SIZE-1:0];
  wire [RS_SIZE-1:0] depend1_bool;
  reg [31:0] val2[RS_SIZE-1:0];
  reg [ROB_WIDTH-1:0] depend2[RS_SIZE-1:0];
  wire [RS_SIZE-1:0] depend2_bool;
  reg [ROB_WIDTH-1:0] rob_idx[RS_SIZE-1:0];
  reg [31:0] offset[RS_SIZE-1:0];
  reg [31:0] pc[RS_SIZE-1:0];

  genvar j;
  generate
    for(j=0;j<RS_SIZE;j=j+1) begin
      assign depend1_bool[j]=depend1[j]==0;
      assign depend2_bool[j]=depend2[j]==0;
    end
  endgenerate

  assign rs_full=busy[vacant_entry];
  // can be replaced with generate for
  wire [RS_WIDTH-1:0] vacant_entry =  !busy[0] ? 0 :
                                      !busy[1] ? 1 :
                                      !busy[2] ? 2 :
                                      !busy[3] ? 3 :
                                      !busy[4] ? 4 :
                                      !busy[5] ? 5 :
                                      !busy[6] ? 6 :
                                      !busy[7] ? 7 :
                                      !busy[8] ? 8 :
                                      !busy[9] ? 9 :
                                      !busy[10] ? 10 :
                                      !busy[11] ? 11 :
                                      !busy[12] ? 12 :
                                      !busy[13] ? 13 :
                                      !busy[14] ? 14 :
                                      15;
  wire [RS_SIZE-1:0] ready = busy&~(depend1_bool|depend2_bool);
  wire [RS_WIDTH-1:0] ready_entry = ready[0] ? 0 :
                                    ready[1] ? 1 :
                                    ready[2] ? 2 :
                                    ready[3] ? 3 :
                                    ready[4] ? 4 :
                                    ready[5] ? 5 :
                                    ready[6] ? 6 :
                                    ready[7] ? 7 :
                                    ready[8] ? 8 :
                                    ready[9] ? 9 :
                                    ready[10] ? 10 :
                                    ready[11] ? 11 :
                                    ready[12] ? 12 :
                                    ready[13] ? 13 :
                                    ready[14] ? 14 :
                                    15;

  always@(*)begin
    if (rs_ready)begin
      rs_actual_br=0;
      if (opcode[ready_entry]==`OPCODE_B) rs_pc_jump=pc[ready_entry]+offset[ready_entry];
      case (op_id[ready_entry])
        `OP_LUI:rs_val=val1[ready_entry];
        `OP_AUIPC:rs_val=pc[ready_entry]+val1[ready_entry];
        `OP_JAL:begin
          rs_val=pc[ready_entry]+4;
          rs_actual_br=1;
          rs_pc_jump=pc[ready_entry]+offset[ready_entry];
        end
        `OP_JALR:begin
          rs_val=pc[ready_entry]+4;
          rs_actual_br=1;
          rs_pc_jump=(val1[ready_entry]+offset[ready_entry])&~32'b1;
        end
        `OP_BEQ:begin
          rs_actual_br=val1[ready_entry]==val2[ready_entry];
        end
        `OP_BNE:begin
          rs_actual_br=val1[ready_entry]!=val2[ready_entry];
        end
        `OP_BLT:begin
          rs_actual_br=$signed(val1[ready_entry])<$signed(val2[ready_entry]);
        end
        `OP_BGE:begin
          rs_actual_br=$signed(val1[ready_entry])>=$signed(val2[ready_entry]);
        end
        `OP_SLT,`OP_SLTI:begin
          rs_val=$signed(val1[ready_entry])<$signed(val2[ready_entry]);
        end
        `OP_SLTU,`OP_SLTIU:begin
          rs_val=val1[ready_entry]<val2[ready_entry];
        end
        `OP_BLTU:begin
          rs_actual_br=val1[ready_entry]<val2[ready_entry];
        end
        `OP_BGEU:begin
          rs_actual_br=val1[ready_entry]>=val2[ready_entry];
        end
        `OP_ADD,`OP_ADDI:begin
          rs_val=val1[ready_entry]+val2[ready_entry];
        end
        `OP_XOR,`OP_XORI:begin
          rs_val=val1[ready_entry]^val2[ready_entry];
        end
        `OP_OR,`OP_ORI:begin
          rs_val=val1[ready_entry]|val2[ready_entry];
        end
        `OP_AND,`OP_ANDI:begin
          rs_val=val1[ready_entry]&val2[ready_entry];
        end
        `OP_SLL,`OP_SLLI:begin
          rs_val=val1[ready_entry]<<val2[ready_entry];
        end
        `OP_SRL,`OP_SRLI:begin
          rs_val=val1[ready_entry]>>val2[ready_entry];
        end
        `OP_SRA,`OP_SRAI:begin
          rs_val=val1[ready_entry]>>>val2[ready_entry];
        end
        `OP_SUB:begin
          rs_val=val1[ready_entry]-val2[ready_entry];
        end
      endcase
      rs_rob_idx=rob_idx[ready_entry];
      busy[ready_entry]=0;
    end
  end

  integer i;
  always @(posedge clk_in)begin
    if (rst_in||clr_in) begin
      busy<=0;
      rs_ready<=0;
    end
    else if (rdy_in) begin
      if (rs_ready) begin
        for(int i=0;i<RS_SIZE;i=i+1)begin
          if (busy[i]&&depend1[i]==rs_rob_idx) begin
            val1[i]<=rs_val;
            depend1[i]<=0;
            // depend1_bool[i]<=0;
          end
          if (busy[i]&&depend2[i]==rs_rob_idx) begin
            val2[i]<=rs_val;
            depend2[i]<=0;
            // depend2_bool[i]<=0;
          end
        end
      end
      if (lsb_ready) begin
        for(int i=0;i<RS_SIZE;i=i+1)begin
          if (busy[i]&&depend1[i]==lsb_rob_idx) begin
            val1[i]<=lsb_val;
            depend1[i]<=0;
            // depend1_bool[i]<=0;
          end
          if (busy[i]&&depend2[i]==lsb_rob_idx) begin
            val2[i]<=lsb_val;
            depend2[i]<=0;
            // depend2_bool[i]<=0;
          end
        end
      end
      //issue to RS (not full)
      if (issue_rs_ready) begin
        op_id[vacant_entry]<=issue_op_id;
        opcode[vacant_entry]<=issue_opcode;
        val1[vacant_entry]<=issue_val1;
        depend1[vacant_entry]<=issue_depend1;
        // depend1_bool[vacant_entry]<=issue_depend1!=0;
        val2[vacant_entry]<=issue_val2;
        depend2[vacant_entry]<=issue_depend2;
        // depend2_bool[vacant_entry]<=issue_depend2!=0;
        offset[vacant_entry]<=issue_offset;
        pc[vacant_entry]<=issue_pc;
        rob_idx[vacant_entry]<=issue_rob_idx;
        busy[vacant_entry]<=1;
      end
      if (ready!=0) begin
        rs_ready<=1;
        rs_busy[ready_entry]<=0;
      end
      else rs_ready<=0;
    end
  end
endmodule