`include "consts.v"
module MemController (
  input wire                      clk_in,
  input wire                      rst_in,
  input wire                      rdy_in,
  input wire clr_in,

  output reg [31:0] mc_dout,

  //ram
  input wire io_buffer_full,
  output reg [31:0] mc_to_mem_addr,
  output reg mc_to_mem_wr,
  input wire [7:0] mem_to_mc_din,//load
  output reg [7:0] mc_to_mem_dout,//store

  input wire ic_to_mc_ready,
  input wire [31:0] ic_to_mc_pc,
  output reg mc_to_ic_ready,

  input wire lsb_to_mc_ready,
  input wire lsb_to_mc_op,
  input wire [1:0] lsb_to_mc_len, //1,2,0
  input wire [31:0] lsb_to_mc_addr,
  input wire [31:0] lsb_to_mc_data,//store
  output reg [31:0] mc_to_lsb_data,//load
  output reg mc_to_lsb_ready
);

  reg [1:0] state;
  reg [1:0] byte_index;
  reg [31:0] mc_din;

  always @(posedge clk_in) begin
    if (rst_in) begin
      state<=`STAT_IDLE;
      byte_index<=0;
      mc_dout<=0;
      mc_to_ic_ready<=0;
      mc_to_lsb_ready<=0;
      mc_to_mem_dout<=0;
      mc_to_mem_addr<=0;
    end
    else if (rdy_in) begin
      case (state)
        `STAT_IDLE: begin
          byte_index<=0;
          mc_dout<=0;
          mc_to_ic_ready<=0;
          mc_to_lsb_ready<=0;
          mc_to_mem_dout<=0;
          mc_to_mem_addr<=0;

          if (lsb_to_mc_ready) begin
            state<={1,lsb_to_mc_op};//load:0,store:1
            mc_to_mem_addr<=lsb_to_mc_addr;
            mc_to_mem_wr<=lsb_to_mc_op;
            if (lsb_to_mc_op) mc_din<=lsb_to_mc_data;
          end
          else if (ic_to_mc_ready) begin
            state<=`STAT_IFETCH;
            mc_to_mem_addr<=ic_to_mc_pc;
            mc_to_mem_wr<=0;
          end
        end
        `STAT_IFETCH: begin
          case (byte_index)
          2'b00:begin
            mc_dout[7:0]<=mem_to_mc_din;
          end
          2'b01:begin
            mc_dout[15:8]<=mem_to_mc_din;
          end
          2'b10:begin
            mc_dout[23:16]<=mem_to_mc_din;
          end
          2'b11:begin
            mc_dout[31:24]<=mem_to_mc_din;
          end
          endcase
          if (byte_index+1==2'b00) begin
            state<=`STAT_IDLE;
            mc_to_ic_ready<=1;
          end
          byte_index<=byte_index+1;
          mc_to_mem_addr<=mc_to_mem_addr+1;
        end
        `STAT_LOAD:begin
          case (byte_index)
          2'b00:begin
            mc_dout[7:0]<=mem_to_mc_din;
          end
          2'b01:begin
            mc_dout[15:8]<=mem_to_mc_din;
          end
          2'b10:begin
            mc_dout[23:16]<=mem_to_mc_din;
          end
          2'b11:begin
            mc_dout[31:24]<=mem_to_mc_din;
          end
          endcase
          if (byte_index+1==lsb_to_mc_len) begin
            state<=`STAT_IDLE;
            mc_to_lsb_ready<=1;
          end
          byte_index<=byte_index+1;
          mc_to_mem_addr<=mc_to_mem_addr+1;
        end
        `STAT_STORE:
          if (mc_to_mem_addr[17:16]!=2'b11||!io_buffer_full) begin
          case (byte_index)
          2'b00:begin
            mem_to_mc_dout<=mc_din[7:0];
          end
          2'b01:begin
            mem_to_mc_din<=mc_din[15:8];
          end
          2'b10:begin
            mem_to_mc_din<=mc_din[23:16];
          end
          2'b11:begin
            mem_to_mc_din<=mc_din[31:24];
          end
          endcase
          if (byte_index+1==lsb_to_mc_len) begin
            state<=`STAT_IDLE;
            mc_to_lsb_ready<=1;
          end
          byte_index<=byte_index+1;
          mc_to_mem_addr<=mc_to_mem_addr+1;
        end
      endcase
    end
  end
  

endmodule