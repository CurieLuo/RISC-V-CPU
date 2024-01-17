`ifndef _CONSTS_V_
`define _CONSTS_V_

`define OPCODE_LUI 7'b0110111
`define OPCODE_AUIPC 7'b0010111
`define OPCODE_JAL 7'b1101111
`define OPCODE_JALR 7'b1100111
`define OPCODE_B 7'b1100011
`define OPCODE_L 7'b0000011
`define OPCODE_S 7'b0100011
`define OPCODE_I 7'b0010011
`define OPCODE_R 7'b0110011

`define OP_NOP 6'd0
`define OP_LUI 6'd1
`define OP_AUIPC 6'd2
`define OP_JAL 6'd3
`define OP_JALR 6'd4
`define OP_BEQ 6'd5
`define OP_BNE 6'd6
`define OP_BLT 6'd7
`define OP_BGE 6'd8
`define OP_BLTU 6'd9
`define OP_BGEU 6'd10
`define OP_LB 6'd11
`define OP_LH 6'd12
`define OP_LW 6'd13
`define OP_LBU 6'd14
`define OP_LHU 6'd15
`define OP_SB 6'd16
`define OP_SH 6'd17
`define OP_SW 6'd18
`define OP_ADDI 6'd19
`define OP_SLTI 6'd20
`define OP_SLTIU 6'd21
`define OP_XORI 6'd22
`define OP_ORI 6'd23
`define OP_ANDI 6'd24
`define OP_SLLI 6'd25
`define OP_SRLI 6'd26
`define OP_SRAI 6'd27
`define OP_ADD 6'd28
`define OP_SUB 6'd29
`define OP_SLL 6'd30
`define OP_SLT 6'd31
`define OP_SLTU 6'd32
`define OP_XOR 6'd33
`define OP_SRL 6'd34
`define OP_SRA 6'd35
`define OP_OR 6'd36
`define OP_AND 6'd37

`define STAT_IDLE 2'b00
`define STAT_IFETCH 2'b01
`define STAT_LOAD 2'b10
`define STAT_STORE 2'b11

`endif