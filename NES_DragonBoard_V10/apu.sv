module apu_gen2(
		input logic clk,
		input logic cpu_clk,
		input logic rst,		// reset signal
		input logic[15:0] a_in,		// addr input bus
		input logic[7:0] from_cpu,	// data input bus
		input logic r_nw,		// read/write select
		output logic audio_out,		// pwm audio output
		output logic[7:0] to_cpu,	// data output bus
		output logic irq);
		
	logic apu_clk_div;
	logic apu_clk;
	logic e_pulse;
	logic l_pulse;
	logic f_pulse;
	logic pulse1_en;
	logic pulse2_en;
	logic triangle_en;
	logic noise_en;
	logic read_status;
	logic frame_interrupt;
	
	logic frame_counter_mode_wr;
	logic[3:0] pulse1_out;
	logic pulse1_active;
	logic pulse1_wr;
	logic[3:0] pulse2_out;
	logic pulse2_active;
	logic pulse2_wr;
	logic[3:0] triangle_out;
	logic triangle_active;
	logic triangle_wr;
	logic[3:0] noise_out;
	logic noise_active;
	logic noise_wr;
	
	assign apu_clk = cpu_clk & ~apu_clk_div;
	assign frame_counter_mode_wr = ~r_nw && (a_in == 16'h4017);
	assign read_status = r_nw & (a_in == 16'h4015);
	assign pulse1_wr = ~r_nw & (a_in[15:2] == 14'h1000);	//01 0000 0000 0000
	assign pulse2_wr = ~r_nw & (a_in[15:2] == 14'h1001);	//01 0000 0000 0001
	assign triangle_wr = ~r_nw & (a_in[15:2] == 14'h1002);	//01 0000 0000 0010
	assign noise_wr = ~r_nw & (a_in[15:2] == 14'h1003);
	
	always_ff @(posedge clk)
	begin
		if(rst)
		begin
			pulse1_en <= 1'b0;
			pulse2_en <= 1'b0;
			triangle_en <= 1'b0;
			noise_en <= 1'b0;
			apu_clk_div <= 1'b0;
			frame_interrupt <= 1'b0;
		end
		else
		begin
			if(cpu_clk)
				apu_clk_div <= ~apu_clk_div;
			
			if(~r_nw & (a_in == 16'h4015))
			begin
				pulse1_en <= from_cpu[0];
				pulse2_en <= from_cpu[1];
				triangle_en <= from_cpu[2];
				noise_en <= from_cpu[3];
			end
			
			if((frame_counter_mode_wr & from_cpu[6]) || (read_status & cpu_clk))	//write one to frame interrupt or read status
				frame_interrupt <= 1'b0;
			if(f_pulse)
				frame_interrupt <= 1'b1;
		
		end
	end
	
	apu_frame_counter_gen2 apu_frame_counter_inst(
			.clk(clk),
			.rst(rst),
			.apu_clk_pulse(apu_clk),
			.to_apu(from_cpu[7:6]),
			.mode_wren(frame_counter_mode_wr),
			.e_pulse(e_pulse),
			.l_pulse(l_pulse),
			.f_pulse(f_pulse));
			
	apu_pulse_1 apu_pulse_1_inst(
			.clk(clk),
			.rst(rst),
			.pulse_en(pulse1_en),
			.apu_clk(apu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(pulse1_wr),
			.pulse_out(pulse1_out),
			.active_out(pulse1_active));
			
	apu_pulse_2 apu_pulse_2_inst(
			.clk(clk),
			.rst(rst),
			.pulse_en(pulse2_en),
			.apu_clk(apu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(pulse2_wr),
			.pulse_out(pulse2_out),
			.active_out(pulse2_active));
			
	apu_triangle_gen2 apu_triangle_inst(
			.clk(clk),
			.rst(rst),
			.triangle_en(triangle_en),
			.cpu_clk(cpu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(triangle_wr),
			.triangle_out(triangle_out),
			.active_out(triangle_active));
			
	apu_noise_gen2 apu_noise_inst(
			.clk(clk),
			.rst(rst),
			.noise_en(noise_en),
			.apu_clk(apu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(noise_wr),
			.noise_out(noise_out),
			.active_out(noise_active));
	  
	apu_mixer_gen2 apu_mixer_inst(
			.clk(clk),
			.from_dmc(7'h00),
			.from_pulse1(pulse1_out),
			.from_pulse2(pulse2_out),
			.from_triangle(triangle_out),
			.from_noise(noise_out),
			.audio_out(audio_out));
			
	assign to_cpu = {1'b0, {7{read_status}} & {frame_interrupt, 2'b00, noise_active, triangle_active, pulse2_active, pulse1_active}};
	assign irq = frame_interrupt;
	
endmodule
	