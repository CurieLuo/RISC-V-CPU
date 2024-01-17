`include "consts.v"

module LoadStoreBuffer#(parameter ROB_WIDTH,parameter LSB_WIDTH)(
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,
  output wire lsb_full,

  input wire issue_lsb_ready,
  input wire [ROB_WIDTH-1:0] issue_rob_idx,
  input wire [31:0] issue_val1, // val1 and val2 might be immediates
  input wire [ROB_WIDTH-1:0] issue_rs1_depend,
  input wire [31:0] issue_val2,
  input wire [ROB_WIDTH-1:0] issue_rs2_depend,
  input wire [5:0] issue_op_id,
  input wire [6:0] issue_opcode,
  input wire [31:0] issue_offset,

  // broadcast from RS
  input wire rs_ready,
  input wire [ROB_WIDTH-1:0] rs_rob_idx,
  input wire [31:0] rs_val,

  output reg lsb_ready,
  output reg [ROB_WIDTH-1:0] lsb_rob_idx,
  output reg [31:0] lsb_val,
)

  parameter LSB_SIZE=2**LSB_WIDTH;
  reg [LSB_WIDTH-1:0] head, tail; // (head,tail]
  wire [LSB_WIDTH-1:0] next_head = head+1==LSB_SIZE?1:head+1;
  wire [LSB_WIDTH-1:0] next_tail = tail+1==LSB_SIZE?1:tail+1;
  assign lsb_full = next_tail==head;
  wire lsb_empty = tail==head;

  reg op_id[LSB_SIZE-1:0];
  reg opcode[LSB_SIZE-1:0];//can be optimized
  reg [31:0] val1[LSB_SIZE-1:0];
  reg [ROB_WIDTH-1:0] depend1[LSB_SIZE-1:0];
  reg [31:0] val2[LSB_SIZE-1:0];
  reg [ROB_WIDTH-1:0] depend2[LSB_SIZE-1:0];
  reg [ROB_WIDTH-1:0] rob_idx[LSB_SIZE-1:0];
  reg [31:0] offset[LSB_SIZE-1:0];

  always@(posedge clk_in) begin
    if (rst_in||clr_in)begin
      head<=1;
      tail<=1;
      lsb_ready<=0;
    end
    else if (rdy_in) begin
      if (rs_ready) begin
        for(int i=0;i<LSB_SIZE;i=i+1)begin
          if (busy[i]&&depend1[i]==rs_rob_idx) begin
            val1[i]<=rs_val;
            depend1[i]<=0;
          end
          if (busy[i]&&depend2[i]==rs_rob_idx) begin
            val2[i]<=rs_val;
            depend2[i]<=0;
          end
        end
      end
      if (lsb_ready) begin
        for(int i=0;i<LSB_SIZE;i=i+1)begin
          if (busy[i]&&depend1[i]==lsb_rob_idx) begin
            val1[i]<=lsb_val;
            depend1[i]<=0;
          end
          if (busy[i]&&depend2[i]==lsb_rob_idx) begin
            val2[i]<=lsb_val;
            depend2[i]<=0;
          end
        end
      end
      //issue to LSB (not full)
      if (issue_lsb_ready) begin
        op_id[next_tail]<=issue_op_id;
        opcode[next_tail]<=issue_opcode;
        val1[next_tail]<=issue_val1;
        depend1[next_tail]<=issue_depend1;
        val2[next_tail]<=issue_val2;
        depend2[next_tail]<=issue_depend2;
        offset[next_tail]<=issue_offset;
        pc[next_tail]<=issue_pc;
        rob_idx[next_tail]<=issue_rob_idx;
        tail<=text_tail;
      end
    end
  end
endmodule