/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_pulse.v
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
*  APU noise channel.
***************************************************************************************************/

module apu_pulse_test(
  input  wire       clk_in,              // system clock signal
  input  wire       rst_in,              // reset signal
  input  wire       en_in,               // enable (via $4015)
  input  wire       cpu_cycle_pulse_in,  // 1 clk pulse on every cpu cycle
  input logic apu_clk,
  input  wire       lc_pulse_in,         // 1 clk pulse for every length counter decrement
  input  wire       eg_pulse_in,         // 1 clk pulse for every env gen update
  input  wire [1:0] a_in,                // control register addr (i.e. $4000 - $4003)
  input  wire [7:0] d_in,                // control register write value
  input  wire       wr_in,               // enable control register write
  output wire [3:0] pulse_out,           // pulse channel output
  output wire       active_out           // pulse channel active (length counter > 0)
);

wire clk;
wire rst;
wire wren;
wire[7:0] from_cpu;
wire l_pulse;
assign l_pulse = lc_pulse_in;
assign from_cpu = d_in;
assign wren = wr_in;
assign clk = clk_in;
assign rst = rst_in;
//
// Envelope
//
wire       envelope_generator_wr;
wire       envelope_generator_restart;
wire [3:0] envelope_generator_out;

apu_envelope_generator_gen2 envelope_generator(
  .clk(clk_in),
  .rst(rst_in),
  .clk_en(eg_pulse_in),
  .from_cpu(d_in[5:0]),
  .env_wren(envelope_generator_wr),
  .env_restart(envelope_generator_restart),
  .env_out(envelope_generator_out)
);

assign envelope_generator_wr      = wr_in && (a_in == 2'b00);
assign envelope_generator_restart = wr_in && (a_in == 2'b11);

//
// Timer
//

	logic[10:0] timer_period;
	//reg  [10:0] q_timer_period, d_timer_period;
	logic[10:0] timer_count;
	logic timer_pulse;
	
	logic[1:0] duty;
	logic[2:0] sequencer_cnt;
	logic seq_bit;
	wire [3:0] sequencer_out;
	
	logic sweep_reload;
	logic[7:0] from_cpu_hold;
	logic[2:0] sweep_count;
	logic sweep_pulse;
	logic sweep_silence;
	logic[11:0] sweep_target_period;
	
	assign timer_pulse = apu_clk & (timer_count == 11'h000);
	assign sweep_pulse = l_pulse & (sweep_count == 3'h0);
	
	always_ff @(posedge clk)
	begin
		if(rst)
		begin
			timer_period <= 11'h000;
			timer_count <= 11'h000;
			duty <= 2'h0;
			sequencer_cnt <= 3'h0;
			sweep_reload <= 1'b0;
			from_cpu_hold <= 8'h00;
		end
		else
		begin
			//timer
			if(apu_clk)
			begin
				if(timer_count)
					timer_count <= timer_count - 11'h001;
				else
					timer_count <= timer_period;
			end
			
			//sequencer
			if(wren && (a_in == 2'b00))
				duty <= from_cpu[7:6];

			if(timer_pulse)
				sequencer_cnt <= sequencer_cnt - 3'h1;
				
			//sweep
			if(wren && (a_in == 2'b01))
			begin
				from_cpu_hold <= from_cpu;
				sweep_reload <= 1'b1;
			end
			else if(l_pulse)
			begin
				sweep_reload <= 1'b0;
			end
			
			if(l_pulse)
			begin
				sweep_count <= sweep_count - 3'h1;
				if(sweep_reload || (sweep_count == 3'h0))
					sweep_count <= from_cpu_hold[6:4];
			end
			
			if(wren && (a_in == 2'b10))
				timer_period[7:0] <= from_cpu;
			if(wren && (a_in == 2'b11))
				timer_period[10:8] <= from_cpu[2:0];
			
			if(sweep_pulse && from_cpu_hold[7] && !sweep_silence && (from_cpu_hold[2:0] != 3'h0))
				timer_period <= sweep_target_period[10:0];
		end
	end
	
	always_comb
	begin
		//sequencer
		unique case(duty)
			2'h0: seq_bit = &sequencer_cnt[2:0];
			2'h1: seq_bit = &sequencer_cnt[2:1];
			2'h2: seq_bit = sequencer_cnt[2];
			2'h3: seq_bit = ~&sequencer_cnt[2:1];
		endcase
		sequencer_out   = (seq_bit) ? envelope_generator_out : 4'h0;
		
		//sweep
		if(~from_cpu_hold[3])
			sweep_target_period = timer_period + (timer_period >> from_cpu_hold[2:0]);
		else
			sweep_target_period = timer_period + ~(timer_period >> from_cpu_hold[2:0]);
			
		sweep_silence = (timer_period[10:3] == 8'h00) || sweep_target_period[11];
	end

//
// Length Counter
//
reg  q_length_counter_halt;
wire d_length_counter_halt;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_length_counter_halt <= 1'b0;
      end
    else
      begin
        q_length_counter_halt <= d_length_counter_halt;
      end
  end

assign d_length_counter_halt = (wr_in && (a_in == 2'b00)) ? d_in[5] : q_length_counter_halt;

wire length_counter_wr;
wire length_counter_en;

apu_length_counter length_counter(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(en_in),
  .halt_in(q_length_counter_halt),
  .length_pulse_in(lc_pulse_in),
  .length_in(d_in[7:3]),
  .length_wr_in(length_counter_wr),
  .en_out(length_counter_en)
);

assign length_counter_wr = wr_in && (a_in == 2'b11);

assign pulse_out  = (length_counter_en && !sweep_silence) ? sequencer_out : 4'h0;
assign active_out = length_counter_en;

endmodule

