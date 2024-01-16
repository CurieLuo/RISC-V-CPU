`include "consts.v"
module InstUnit #(parameter ROB_WIDTH
) (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,

  //instruction fetch
  output reg [31:0] iu_to_ic_pc,
  input wire ic_to_iu_rdy,
  input wire [31:0] ic_to_iu_inst,

  input wire rob_full,


  output reg issue_rdy,
  output reg [4:0] issue_rd_id,
  output reg [ROB_WIDTH-1:0] issue_rob_idx,
  output reg [31:0] issue_rs1_val,
  output reg issue_rs1_depend,
  output reg [31:0] issue_rs2_val,
  output reg issue_rs2_depend,
  output reg [31:0] issue_imm,

);

  reg [31:0] pc;
  reg [31:0] inst;
  reg inst_rdy;
  // wire stall;
  // assign stall = rob_to_iu_full||rs_to_iu_full||lsb_to_iu_full;

  always@(posedge clk_in) begin //instruction fetch
    if (rst_in) begin
      pc<=0;
      inst<=0;
      inst_rdy<=0;
    end
    else if (rdy_in) begin
      if (clr_in)begin
        //TODO
      end
      else if (~inst_rdy) begin
        if (ic_to_iu_rdy&&iu_to_ic_pc==pc) begin
          inst_rdy<=1;
          inst<=ic_to_iu_inst;
        end
        else iu_to_ic_pc<=pc;
      end
      else begin
        //TODO
      end
    end
  end

  assign opcode = inst[6:0];

  always@(*) begin //instruction decode & issue
  if (inst_rdy&&~rob_full)begin //TODO
    case (opcode)
      `OP_NOP:; //TODO
      `OP_LUI:begin
        
      end
      `OP_AUIPC:begin
        
      end
    endcase
  end
  end
  

endmodule