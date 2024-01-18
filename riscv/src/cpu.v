// RISCV32I CPU top module
// port modification allowed for debugging purposes

`include "consts.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

  parameter ROB_WIDTH=4;
  parameter RS_WIDTH=4;
  parameter LSB_WIDTH=4;
  parameter RAM_ADDR_WIDTH=18;//TODO
  parameter ICACHE_SET_WIDTH=8;
  parameter BHT_WIDTH=6;

  //instruction unit
  wire clr_in;

  wire [31:0] iu_to_ic_pc;
  wire ic_to_iu_ready;
  wire [31:0] ic_to_iu_inst;

  wire [4:0] iu_to_rf_rs1_id;
  wire [31:0] rf_to_iu_val1;
  wire [ROB_WIDTH-1:0] rf_to_iu_rs1_depend;
  wire [4:0] iu_to_rf_rs2_id;
  wire [31:0] rf_to_iu_val2;
  wire [ROB_WIDTH-1:0] rf_to_iu_rs2_depend;

  wire rob_full;
  wire [ROB_WIDTH-1:0] rob_new_index;
  wire [ROB_WIDTH-1:0] iu_to_rob_rs1_depend;
  wire rob_to_iu_rs1_ready;
  wire [31:0] rob_to_iu_val1;
  wire [ROB_WIDTH-1:0] iu_to_rob_rs2_depend;
  wire rob_to_iu_rs2_ready;
  wire [31:0] rob_to_iu_val2;
  wire [31:0] rob_to_iu_actual_pc;

  wire lsb_full;
  wire lsb_ready;
  wire [ROB_WIDTH-1:0] lsb_rob_index;
  wire [31:0] lsb_val;
  
  wire rs_full;
  wire rs_ready;
  wire [ROB_WIDTH-1:0] rs_rob_index;
  wire [31:0] rs_val;
  // wire rs_actual_br;
  // wire [31:0] rs_pc_jump;

  wire issue_ready;
  wire issue_rs_ready;
  wire issue_lsb_ready;
  wire [4:0] issue_rd_id;
  wire [ROB_WIDTH-1:0] issue_rob_index;
  wire [31:0] issue_val1;
  wire [ROB_WIDTH-1:0] issue_rs1_depend;
  wire [31:0] issue_val2;
  wire [ROB_WIDTH-1:0] issue_rs2_depend;
  wire [5:0] issue_op_id;
  wire [6:0] issue_opcode;
  wire [31:0] issue_pc;
  wire [31:0] issue_offset;
  wire issue_prediction;

  wire [31:0] iu_to_bp_pc;
  wire bp_to_iu_prediction;

  //memory controller
  wire [31:0] mc_dout;
  
  wire [31:0] mc_to_mem_addr;
  wire mc_to_mem_wr;
  wire [7:0] mem_to_mc_din;
  wire [7:0] mc_to_mem_dout;

  wire ic_to_mc_ready;
  wire [31:0] ic_to_mc_pc;
  wire mc_to_ic_ready;

  wire lsb_to_mc_ready;
  wire lsb_to_mc_op;
  wire [1:0] lsb_to_mc_len;
  wire [31:0] lsb_to_mc_addr;
  wire [31:0] lsb_to_mc_data;
  wire [31:0] mc_to_lsb_data;
  wire mc_to_lsb_ready;

  //reorder buffer
  wire rs_actual_br;
  wire [31:0] rs_pc_jump;
  wire rob_to_rf_ready;
  wire [4:0] rob_to_rf_reg_id;
  wire [31:0] rob_to_rf_reg_val;
  wire [ROB_WIDTH-1:0] rob_to_rf_rob_index;
  wire rob_to_bp_ready;
  wire [31:0] rob_to_bp_pc;
  wire rob_to_bp_actual_br;


  InstUnit#(.ROB_WIDTH(ROB_WIDTH)) inst_unit(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .clr_in(clr_in),

    .iu_to_ic_pc(iu_to_ic_pc),
    .ic_to_iu_ready(ic_to_iu_ready),
    .ic_to_iu_inst(ic_to_iu_inst),

    .iu_to_rf_rs1_id(iu_to_rf_rs1_id),
    .rf_to_iu_val1(rf_to_iu_val1),
    .rf_to_iu_rs1_depend(rf_to_iu_rs1_depend),
    .iu_to_rf_rs2_id(iu_to_rf_rs2_id),
    .rf_to_iu_val2(rf_to_iu_val2),
    .rf_to_iu_rs2_depend(rf_to_iu_rs2_depend),

    .rob_full(rob_full),
    .rob_new_index(rob_new_index),
    .iu_to_rob_rs1_depend(iu_to_rob_rs1_depend),
    .rob_to_iu_rs1_ready(rob_to_iu_rs1_ready),
    .rob_to_iu_val1(rob_to_iu_val1),
    .iu_to_rob_rs2_depend(iu_to_rob_rs2_depend),
    .rob_to_iu_rs2_ready(rob_to_iu_rs2_ready),
    .rob_to_iu_val2(rob_to_iu_val2),
    .rob_to_iu_actual_pc(rob_to_iu_actual_pc),

    .lsb_full(lsb_full),
    .lsb_ready(lsb_ready),
    .lsb_rob_index(lsb_rob_index),
    .lsb_val(lsb_val),
    
    .rs_full(rs_full),
    .rs_ready(rs_ready),
    .rs_rob_index(rs_rob_index),
    .rs_val(rs_val),

    .issue_ready(issue_ready),
    .issue_rs_ready(issue_rs_ready),
    .issue_lsb_ready(issue_lsb_ready),
    .issue_rd_id(issue_rd_id),
    .issue_rob_index(issue_rob_index), // the index of the entry to be filled
    .issue_val1(issue_val1), // val1 and val2 might be immediates
    .issue_rs1_depend(issue_rs1_depend),
    .issue_val2(issue_val2),
    .issue_rs2_depend(issue_rs2_depend),
    .issue_op_id(issue_op_id),
    .issue_opcode(issue_opcode),
    .issue_pc(issue_pc),
    .issue_offset(issue_offset),
    .issue_prediction(issue_prediction),

    .iu_to_bp_pc(iu_to_bp_pc),
    .bp_to_iu_prediction(bp_to_iu_prediction)
  );

  ICache#(.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),.ICACHE_SET_WIDTH(ICACHE_SET_WIDTH)) icache(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .iu_to_ic_pc(iu_to_ic_pc),
    .ic_to_iu_ready(ic_to_iu_ready),
    .ic_to_iu_inst(ic_to_iu_inst),

    .ic_to_mc_ready(ic_to_mc_ready),
    .ic_to_mc_pc(ic_to_mc_pc),
    .mc_to_ic_ready(mc_to_ic_ready),
    .mc_to_ic_inst(mc_to_ic_inst)
  );

  RegFile#(.ROB_WIDTH(ROB_WIDTH)) reg_file(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .clr_in(clr_in),

    .issue_ready(issue_ready),
    .issue_rd_id(issue_rd_id),
    .issue_rob_index(issue_rob_index),

    .iu_to_rf_rs1_id(iu_to_rf_rs1_id),
    .rf_to_iu_rs1_depend(rf_to_iu_rs1_depend),
    .rf_to_iu_val1(rf_to_iu_val1),
    .iu_to_rf_rs2_id(iu_to_rf_rs2_id),
    .rf_to_iu_rs2_depend(rf_to_iu_rs2_depend),
    .rf_to_iu_val2(rf_to_iu_val2),

    .rob_to_rf_ready(rob_to_rf_ready),
    .rob_to_rf_reg_id(rob_to_rf_reg_id),
    .rob_to_rf_reg_val(rob_to_rf_reg_val),
    .rob_to_rf_rob_index(rob_to_rf_rob_index)
  );

  MemController mem_controller(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .clr_in(clr_in),

    .mc_dout(mc_dout),

    .io_buffer_full(io_buffer_full),
    .mc_to_mem_addr(mc_to_mem_addr),
    .mc_to_mem_wr(mc_to_mem_wr),
    .mem_to_mc_din(mem_to_mc_din),
    .mc_to_mem_dout(mc_to_mem_dout),

    .ic_to_mc_ready(ic_to_mc_ready),
    .ic_to_mc_pc(ic_to_mc_pc),
    .mc_to_ic_ready(mc_to_ic_ready),

    .lsb_to_mc_ready(lsb_to_mc_ready),
    .lsb_to_mc_op(lsb_to_mc_op),
    .lsb_to_mc_len(lsb_to_mc_len),
    .lsb_to_mc_addr(lsb_to_mc_addr),
    .lsb_to_mc_data(lsb_to_mc_data),
    .mc_to_lsb_data(mc_to_lsb_data),
    .mc_to_lsb_ready(mc_to_lsb_ready)
  );

  BranchPredictor#(.BHT_WIDTH(BHT_WIDTH)) branch_predictor(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .iu_to_bp_pc(iu_to_bp_pc),
    .iu_to_bp_inst(iu_to_bp_inst),
    .bp_to_iu_prediction(bp_to_iu_prediction),

    .rob_to_bp_ready(rob_to_bp_ready),
    .rob_to_bp_pc(rob_to_bp_pc),
    .rob_to_bp_actual_br(rob_to_bp_actual_br)
  );

  ReorderBuffer#(.ROB_WIDTH(ROB_WIDTH)) reorder_buffer(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .clr_in(clr_in),
    .rob_full(rob_full),
    .rob_new_index(rob_new_index),

    .iu_to_rob_rs1_depend(iu_to_rob_rs1_depend),
    .rob_to_iu_rs1_ready(rob_to_iu_rs1_ready),
    .rob_to_iu_val1(rob_to_iu_val1),
    .iu_to_rob_rs2_depend(iu_to_rob_rs2_depend),
    .rob_to_iu_rs2_ready(rob_to_iu_rs2_ready),
    .rob_to_iu_val2(rob_to_iu_val2),
    .rob_to_iu_actual_pc(rob_to_iu_actual_pc),

    .lsb_ready(lsb_ready),
    .lsb_rob_index(lsb_rob_index),
    .lsb_val(lsb_val),

    .rs_ready(rs_ready),
    .rs_rob_index(rs_rob_index),
    .rs_val(rs_val),
    .rs_actual_br(rs_actual_br),
    .rs_pc_jump(rs_pc_jump),

    .issue_ready(issue_ready),
    .issue_op_id(issue_op_id),
    .issue_opcode(issue_opcode),
    .issue_rd_id(issue_rd_id),
    .issue_pc(issue_pc),
    .issue_prediction(issue_prediction),

    .rob_to_rf_ready(rob_to_rf_ready),
    .rob_to_rf_reg_id(rob_to_rf_reg_id),
    .rob_to_rf_reg_val(rob_to_rf_reg_val),
    .rob_to_rf_rob_index(rob_to_rf_rob_index),

    .rob_to_bp_ready(rob_to_bp_ready),
    .rob_to_bp_pc(rob_to_bp_pc),
    .rob_to_bp_actual_br(rob_to_bp_actual_br)
  );

  LoadStoreBuffer#(.ROB_WIDTH(ROB_WIDTH),.LSB_WIDTH(LSB_WIDTH)) load_store_buffer(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .clr_in(clr_in),
    .lsb_full(lsb_full),

    .issue_lsb_ready(issue_lsb_ready),
    .issue_rob_index(issue_rob_index),
    .issue_val1(issue_val1),
    .issue_rs1_depend(issue_rs1_depend),
    .issue_val2(issue_val2),
    .issue_rs2_depend(issue_rs2_depend),
    .issue_op_id(issue_op_id),
    .issue_opcode(issue_opcode),
    .issue_offset(issue_offset),

    .rs_ready(rs_ready),
    .rs_rob_index(rs_rob_index),
    .rs_val(rs_val),

    .lsb_ready(lsb_ready),
    .lsb_rob_index(lsb_rob_index),
    .lsb_val(lsb_val),

    .lsb_to_mc_ready(lsb_to_mc_ready),
    .lsb_to_mc_op(lsb_to_mc_op),
    .lsb_to_mc_len(lsb_to_mc_len),
    .lsb_to_mc_addr(lsb_to_mc_addr),
    .lsb_to_mc_data(lsb_to_mc_data),
    .mc_to_lsb_data(mc_to_lsb_data),
    .mc_to_lsb_ready(mc_to_lsb_ready)
  );

  ReservationStation#(.ROB_WIDTH(ROB_WIDTH),.RS_WIDTH(RS_WIDTH)) reservation_station(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .clr_in(clr_in),
    .rs_full(rs_full),
    
    .issue_rs_ready(issue_rs_ready),
    .issue_rob_index(issue_rob_index),
    .issue_val1(issue_val1),
    .issue_rs1_depend(issue_rs1_depend),
    .issue_val2(issue_val2),
    .issue_rs2_depend(issue_rs2_depend),
    .issue_op_id(issue_op_id),
    .issue_opcode(issue_opcode),
    .issue_pc(issue_pc),
    .issue_offset(issue_offset),

    .lsb_ready(lsb_ready),
    .lsb_rob_index(lsb_rob_index),
    .lsb_val(lsb_val),

    .rs_ready(rs_ready),
    .rs_rob_index(rs_rob_index),
    .rs_val(rs_val),
    .rs_actual_br(rs_actual_br),
    .rs_pc_jump(rs_pc_jump)
  );

endmodule