module apu_noise_gen2(
		input logic clk,
		input logic rst,
		input logic noise_en,	// enable (via $4015)
		input logic apu_clk,	// 1 clk pulse on every apu cycle
		input logic l_pulse,	// 1 clk pulse for every length counter decrement
		input logic e_pulse,	// 1 clk pulse for every env gen update
		input logic[1:0] a_in,	// control register addr (i.e. $400C - $400F)
		input logic[7:0] from_cpu,	// control register write value
		input logic wren,	// enable control register write
		output logic[3:0] noise_out,	// noise channel output
		output logic active_out);	// noise channel active (length counter > 0)

	//
	// Envelope
	//
	logic env_wren;
	//logic env_restart;
	logic[3:0] env_out;
	logic length_wren;
	logic length_halt;
	
	logic[11:0] timer_period;
	logic[11:0] timer_count;
	logic timer_pulse;
	logic[14:0] lfsr;
	logic mode;

	apu_envelope_generator_gen2 envelope_generator(
			.clk(clk),
			.rst(rst),
			.clk_en(e_pulse),
			.from_cpu(from_cpu[5:0]),
			.env_wren(env_wren),
			//.env_restart(env_restart),
			.env_restart(length_wren),
			.env_out(env_out));

	assign env_wren = wren && (a_in == 2'b00);
	//assign env_restart = wren && (a_in == 2'b11);
	assign length_wren = wren && (a_in == 2'b11);
	assign timer_pulse = apu_clk && (timer_count == 12'h000);
	
	always_ff @(posedge clk)
	begin
		if(rst)
		begin
			timer_period <= 12'h000;
			timer_count <= 12'h000;
			lfsr <= 15'h0001;
			mode <= 1'b0;
			length_halt <= 1'b0;
		end
		else
		begin
			if(apu_clk)
			begin
				if(timer_count)
					timer_count <= timer_count - 12'h001;
				else
					timer_count <= timer_period;
			end
			
			if(wren && (a_in == 2'b10))
			begin
				mode <= from_cpu[7];
				unique case (from_cpu[3:0])
					4'h0: timer_period <= 12'd4;
					4'h1: timer_period <= 12'd8;
					4'h2: timer_period <= 12'd16;
					4'h3: timer_period <= 12'd32;
					4'h4: timer_period <= 12'd64;
					4'h5: timer_period <= 12'd96;
					4'h6: timer_period <= 12'd128;
					4'h7: timer_period <= 12'd160;
					4'h8: timer_period <= 12'd202;
					4'h9: timer_period <= 12'd254;
					4'hA: timer_period <= 12'd380;
					4'hB: timer_period <= 12'd508;
					4'hC: timer_period <= 12'd762;
					4'hD: timer_period <= 12'd1016;
					4'hE: timer_period <= 12'd2034;
					4'hF: timer_period <= 12'd4068;
				endcase
			end
			
			if(timer_pulse)
			begin
				if(mode)
					lfsr <= {lfsr[0] ^ lfsr[6], lfsr[14:1]};
				else
					lfsr <= {lfsr[0] ^ lfsr[1], lfsr[14:1]};
			end
			
			if(wren && (a_in == 2'b00))
			begin
				length_halt <= from_cpu[5];
			end
		end
	end

	apu_length_counter_gen2 length_counter_inst(
			.clk(clk),
			.rst(rst),
			.length_en(noise_en),
			.length_halt(length_halt),
			.l_pulse(l_pulse),
			.from_cpu(from_cpu[7:3]),
			.length_wren(length_wren),
			.active_out(active_out));
			
	assign noise_out = {4{lfsr[0] & active_out}} & env_out;
		
endmodule
