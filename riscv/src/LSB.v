`include "consts.v"

module LoadStoreBuffer#(parameter ROB_WIDTH=4,parameter LSB_WIDTH=4)(
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,
  output wire lsb_full,

  input wire issue_lsb_ready,
  input wire [ROB_WIDTH-1:0] issue_rob_index,
  input wire [31:0] issue_val1, // val1 and val2 might be immediates
  input wire [ROB_WIDTH-1:0] issue_depend1,
  input wire [31:0] issue_val2,
  input wire [ROB_WIDTH-1:0] issue_depend2,
  input wire [5:0] issue_op_id,
  input wire [6:0] issue_opcode,
  input wire [31:0] issue_offset,

  // broadcast from RS
  input wire rs_ready,
  input wire [ROB_WIDTH-1:0] rs_rob_index,
  input wire [31:0] rs_val,

  output reg lsb_ready,
  output reg [ROB_WIDTH-1:0] lsb_rob_index,
  output reg [31:0] lsb_val,

  output reg lsb_to_mc_ready,
  output reg lsb_to_mc_op,
  output reg [1:0] lsb_to_mc_len, //1,2,0
  output reg [31:0] lsb_to_mc_addr,
  output reg [31:0] lsb_to_mc_data,//store
  input wire [31:0] mc_to_lsb_data,//load
  input wire mc_to_lsb_ready
);

  parameter LSB_SIZE=2**LSB_WIDTH;
  reg [LSB_WIDTH-1:0] head, tail; // (head,tail]
  wire [LSB_WIDTH-1:0] next_head = head+1==LSB_SIZE?1:head+1;
  wire [LSB_WIDTH-1:0] next_tail = tail+1==LSB_SIZE?1:tail+1;
  assign lsb_full = next_tail==head;
  wire lsb_empty = tail==head;

  reg [5:0] op_id[LSB_SIZE-1:0];
  reg opcode[LSB_SIZE-1:0];//can be optimized
  reg [31:0] val1[LSB_SIZE-1:0];
  reg [ROB_WIDTH-1:0] depend1[LSB_SIZE-1:0];
  reg [31:0] val2[LSB_SIZE-1:0];
  reg [ROB_WIDTH-1:0] depend2[LSB_SIZE-1:0];
  reg [ROB_WIDTH-1:0] rob_index[LSB_SIZE-1:0];
  reg [31:0] offset[LSB_SIZE-1:0];

  reg [5:0] cur_op_id;

  integer i;
  always@(posedge clk_in) begin
    if (rst_in||clr_in)begin
      head<=1;
      tail<=1;
      lsb_ready<=0;
    end

    else if (rdy_in) begin
      if (rs_ready) begin
        for(i=1;i<LSB_SIZE;i=i+1)begin
          if (depend1[i]==rs_rob_index) begin
            val1[i]<=rs_val;
            depend1[i]<=0;
          end
          if (depend2[i]==rs_rob_index) begin
            val2[i]<=rs_val;
            depend2[i]<=0;
          end
        end
      end
      if (lsb_ready) begin
        for(i=1;i<LSB_SIZE;i=i+1)begin
          if (depend1[i]==lsb_rob_index) begin
            val1[i]<=lsb_val;
            depend1[i]<=0;
          end
          if (depend2[i]==lsb_rob_index) begin
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
        rob_index[next_tail]<=issue_rob_index;
        tail<=next_tail;
      end

      if (!lsb_to_mc_ready) begin
        lsb_ready<=0;
        if (!lsb_empty&&!depend1[next_head]&&!depend2[next_head]) begin
          head<=next_head;
          lsb_to_mc_ready<=1;
          lsb_to_mc_op<=opcode[next_head]==`OPCODE_S;
          lsb_to_mc_addr<=val1[next_head]+offset[next_head];
          lsb_to_mc_data<=val2[next_head];
          cur_op_id<=op_id[next_head];
          lsb_rob_index<=rob_index[next_head];
          case (op_id[next_head])
            `OP_LB,`OP_LBU,`OP_SB:lsb_to_mc_len=1;
            `OP_LH,`OP_LHU,`OP_SH:lsb_to_mc_len=2;
            `OP_LW,`OP_SW:lsb_to_mc_len=4;
          endcase
        end
      end
      else begin
        if (mc_to_lsb_ready) begin
          if (lsb_to_mc_op==0) begin
            case (cur_op_id)
              `OP_LB:lsb_val<={24'b0,mc_to_lsb_data[7:0]};
              `OP_LH:lsb_val<={16'b0,mc_to_lsb_data[15:0]};
              `OP_LW:lsb_val<=mc_to_lsb_data;
              `OP_LBU:lsb_val<={{24{mc_to_lsb_data[7]}},mc_to_lsb_data[7:0]};
              `OP_LHU:lsb_val<={{16{mc_to_lsb_data[15]}},mc_to_lsb_data[15:0]};
            endcase
          end
          lsb_ready<=1;
          lsb_to_mc_ready<=0;
        end
      end
    end
  end
endmodule