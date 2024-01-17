`include "consts.v"
module MemController #(
) (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,

  output reg [31:0] mc_dout,

  output reg [31:0] mc_to_mem_addr,
  output reg mc_to_mem_wr,
  input wire [7:0] mem_to_mc_din,
  output reg [7:0] mc_to_mem_dout,

  input wire ic_to_mc_request,
  input wire [31:0] ic_to_mc_pc,
  output reg mc_to_ic_rdy,

  input wire lsb_to_mc_request,
  output reg mc_to_lsb_rdy,
);

  reg [1:0] state;
  reg [1:0] byte_index;

  always @(posedge clk_in) begin // TODO
    if (rst_in) begin
      state<=`STAT_IDLE;
      byte_index<=0;
      mc_dout<=0;
      mc_to_ic_rdy<=0;
      mc_to_lsb_rdy<=0;
      mc_to_mem_dout<=0;
      mc_to_mem_addr<=0;
    end
    else if (rdy_in) begin
      case (state)
        `STAT_IDLE: begin
          if (lsb_to_mc_request) begin
            //TODO
          end
          else if (ic_to_mc_request) begin
            state<=`STAT_IFETCH;
            mc_to_mem_addr<=ic_to_mc_pc;
            mc_to_mem_wr<=0;
          end
        end
        `STAT_IFETCH: begin
          case (byte_index)
          2'b00:begin
            mc_dout[7:0]<=mem_to_mc_din;
            byte_index<=2'b01;
          end
          2'b01:begin
            mc_dout[15:8]<=mem_to_mc_din;
            byte_index<=2'b10;
          end
          2'b10:begin
            mc_dout[23:16]<=mem_to_mc_din;
            byte_index<=2'b11;
          end
          2'b11:begin
            mc_dout[31:24]<=mem_to_mc_din;
            byte_index<=2'b00;
            state<=`STAT_IDLE;
            mc_to_ic_rdy<=1;
          end
          endcase
        end
        mc_to_mem_addr<=mc_to_mem_addr+1;
      endcase
    end
  end
  

endmodule