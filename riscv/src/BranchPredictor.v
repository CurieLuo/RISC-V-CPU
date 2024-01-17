`include "consts.v"

module BranchPredictor#(parameter BHT_WIDTH=6)(
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,

  input wire [31:0] iu_to_bp_pc,
  input wire [31:0] iu_to_bp_inst,
  output wire bp_to_iu_prediction,

  input wire rob_to_bp_ready,
  input wire [31:0] rob_to_bp_pc,
  input wire rob_to_bp_actual_br,
)
  parameter BHT_SIZE=2**BHT_WISTH;
  reg [1:0] bht [BHT_SIZE-1:0]; // branch history table
  wire [BHT_WIDTH-1:0] hash = rob_to_bp_pc[BHT_WIDTH+1:2];
  assign bp_to_iu_prediction = bht[iu_to_bp_pc[BHT_WIDTH+1:2]][1];

  integer i;
  always @(posedge clk_in) begin
    if (rst_in) begin
      for(i=0;i<BHT_SIZE;i=i+1) bht[i]<=2'b10;
    end
    else if (rdy_in) begin
      if (rob_to_bp_ready) begin
        case (bht[hash])
          2'b00:bht[hash]<=rob_to_bp_actual_br?2'b01:2'b00;
          2'b01:bht[hash]<=rob_to_bp_actual_br?2'b10:2'b00;
          2'b10:bht[hash]<=rob_to_bp_actual_br?2'b11:2'b01;
          2'b11:bht[hash]<=rob_to_bp_actual_br?2'b11:2'b10;
        endcase
      end
    end
  end


endmodule