`include "consts.v"

// direct mapped cache
module ICache#(
  parameter RAM_ADDR_WIDTH=17,
  parameter SET_WIDTH=8
)(
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,

  // output instruction
  input wire [31:0] iu_to_ic_pc,
  output wire ic_to_iu_ready,
  output wire [31:0] ic_to_iu_inst,

  // input instruction from mem
  output reg ic_to_mc_request,
  output reg [31:0] ic_to_mc_pc, // fetch from mem
  input wire mc_to_ic_ready,
  input wire [31:0] mc_to_ic_inst, // instruction
  
);
  parameter TAG_WIDTH = RAM_ADDR_WIDTH-(SET_WIDTH+2); // TODO
  parameter SET_SIZE = 2**SET_WIDTH;

  // cache
  reg valid [SET_SIZE-1:0];
  reg [RAM_ADDR_WIDTH-1:SET_WIDTH+2] tag [SET_SIZE-1:0];
  reg [31:0] data [SET_SIZE-1:0];

  wire hit = valid[iu_to_ic_pc[SET_WIDTH+2-1:2]]&&tag[SET_WIDTH+2-1:2]==iu_to_ic_pc[RAM_ADDR_WIDTH-1:SET_WIDTH+2];
  assign ic_to_iu_ready = hit||mc_to_ic_ready&&ic_to_mc_pc==iu_to_ic_pc; // TODO
  assign ic_to_iu_inst = hit?data[iu_to_ic_pc[SET_WIDTH+2-1:2]]:mc_to_ic_inst;

  integer i;
  always @(posedge clk_in) begin
    if (rst_in) begin
      ic_to_mc_request<=0;
      for (i=0;i<SET_SIZE;i=i+1) valid[i]<=0;
    end
    else if (rdy_in) begin
       // if(hit) ic_to_mc_request<=0;
      if (!hit) begin
        if (ic_to_iu_ready) begin // TODO ic_to_mc_request && ~mc_to_ic_ready
          valid[iu_to_ic_pc[SET_WIDTH+2-1:2]]<=1;
          tag[iu_to_ic_pc[SET_WIDTH+2-1:2]]<=iu_to_ic_pc
          data[iu_to_ic_pc[SET_WIDTH+2-1:2]]<=mc_to_ic_inst;
          ic_to_mc_request<=0;
        end
        else begin
          ic_to_mc_request<=1;
          ic_to_mc_pc<=iu_to_ic_pc;
        end
      end
    end
  end

endmodule
