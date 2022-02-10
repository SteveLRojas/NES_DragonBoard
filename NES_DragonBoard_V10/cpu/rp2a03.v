/***************************************************************************************************
** fpga_nes/hw/src/cpu/rp2a03.v
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  Implementation of the RP2A03 chip for an fpga-based NES emulator.  Contains a MOS-6502 CPU
*  core, APU, sprite DMA engine, and joypad control logic.
***************************************************************************************************/

module rp2a03
(
  input  wire        clk_in,         // system clock
  input  wire        rst_in,         // system reset

  // CPU signals.
  input  wire        rdy_in,         // ready signal
  input  wire [ 7:0] d_in,           // data input bus
  input  wire        nnmi_in,        // /nmi interrupt signal (active low)
  output wire [ 7:0] d_out,          // data output bus
  output wire [15:0] a_out,          // address bus
  output wire        r_nw_out,       // read/write select (write low)

  // Joypad signals.
  input  wire        jp_data1_in,    // joypad 1 input signal
  input  wire        jp_data2_in,    // joypad 2 input signal
  output wire        jp1_clk,         // joypad output clk signal
  output wire			jp2_clk,
  output wire        jp_latch,       // joypad output latch signal

  // Audio signals.
  output wire        audio_out      // pwm audio output
);

reg[5:0] clk_count;
wire cpu_clk;

always @(posedge clk_in)
begin
    if(rst_in)
    begin
        clk_count <= 6'h00;
    end
    else
    begin
		if(clk_count == 6'd13)
            clk_count <= 6'h00;
        else
            clk_count <= clk_count + 6'h01;
    end
end

assign cpu_clk = (clk_count == 6'h00);

//
// CPU: central processing unit block.
//
wire        cpu_ready;
wire [ 7:0] cpu_din;
wire        apu_irq;
wire [ 7:0] cpu_dout;
wire [15:0] cpu_a;
wire        cpu_r_nw;

cpu cpu_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .ready_in(cpu_ready),
  .d_in(cpu_din),
  .nnmi_in(nnmi_in),
  .nirq_in(~apu_irq),
  .d_out(cpu_dout),
  .a_out(cpu_a),
  .r_nw_out(cpu_r_nw));

//
// APU: audio processing unit block.
//
wire [7:0] audio_dout;

//apu apu_blk(
//  .clk_in(clk_in),
//  .rst_in(rst_in),
//  .a_in(cpu_a),
//  .d_in(cpu_dout),
//  .r_nw_in(cpu_r_nw),
//  .audio_out(audio_out),
//  .d_out(audio_dout)
//);
apu_gen2 apu_inst(
  .clk(clk_in),
  .cpu_clk(cpu_clk),
  .rst(rst_in),
  .a_in(cpu_a),
  .from_cpu(cpu_dout),
  .r_nw(cpu_r_nw),
  .audio_out(audio_out),
  .to_cpu(audio_dout),
  .irq(apu_irq));

//
// JP: joypad controller block.
//
wire [7:0] jp_dout;

joypad jp_inst(
		.clk(clk_in),
		.wren(~cpu_r_nw),
		.addr(cpu_a),
		.from_cpu(cpu_dout[0]),
		.jp1_data(jp_data1_in),
		.jp2_data(jp_data2_in),
		.jp1_clk(jp1_clk),
		.jp2_clk(jp2_clk),
		.jp_latch(jp_latch),
		.to_cpu(jp_dout));

//
// SPRDMA: sprite dma controller block.
//
wire        sprdma_active;
wire [15:0] sprdma_a;
wire [ 7:0] sprdma_dout;
wire        sprdma_r_nw;

//sprdma sprdma_blk(
//    .horiz_advance(horiz_advance),
//    .clk_in(clk_in),
//    .rst_in(rst_in),
//    .cpumc_a_in(cpu_a),
//    .cpumc_din_in(cpu_dout),
//    .cpumc_dout_in(cpu_din),
//    .cpu_r_nw_in(cpu_r_nw),
//    .active_out(sprdma_active),
//    .cpumc_a_out(sprdma_a),
//    .cpumc_d_out(sprdma_dout),
//    .cpumc_r_nw_out(sprdma_r_nw)
//);
rp2a03_dma dma_inst(
		.clk(clk_in),
		.cpu_clk(cpu_clk),
		.rst(rst_in),
		.spr_trig(cpu_a == 16'h4014 && !cpu_r_nw),		// Sprite DMA trigger
		.dmc_trig(1'b0),		// DMC DMA trigger
		.cpu_r_nw(cpu_r_nw),		// CPU is in a read cycle
		.from_cpu(cpu_dout),		// Data written by CPU
		.from_ram(d_in),		// Data read from RAM
		.dmc_dma_addr(16'hxxxx),		// DMC DMA Address
		.a_out(sprdma_a),		// Address to access
		.dma_active(sprdma_active),		// DMA controller wants bus control
		.dma_r_nw(sprdma_r_nw),		// 1 = read, 0 = write
		.to_ram(sprdma_dout),		// Value to write to RAM
		.dmc_ack());		// ACK the DMC DMA

assign cpu_ready = rdy_in & !sprdma_active;
assign cpu_din   = d_in | jp_dout | audio_dout;

assign d_out     = (sprdma_active) ? sprdma_dout : cpu_dout;
assign a_out     = (sprdma_active) ? sprdma_a    : cpu_a;
assign r_nw_out  = (sprdma_active) ? sprdma_r_nw : cpu_r_nw;

endmodule

