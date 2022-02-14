module apu_mixer_gen2(
		input logic clk,
		input logic[6:0] from_dmc,
		input logic[3:0] from_pulse1,    // pulse 0 channel input
		input logic[3:0] from_pulse2,    // pulse 1 channel input
		input logic[3:0] from_triangle,  // triangle channel input
		input logic[3:0] from_noise,     // noise channel input
		output logic audio_out);     // mixed audio output

	//pulse multiplier (for pulse 1 + pulse 2): 2.243592 (144/64)
	//triangle multiplier: 2.5389585 (162/64)
	//noise multiplier: 1.473849 (94/64)
	//DMC multiplier: 0.9994725 (1/1)
	
	logic[6:0] dmc_hold;
	logic[3:0] pulse1_hold, pulse2_hold;
	logic[3:0] triangle_hold;
	logic[3:0] noise_hold;
	
	logic[4:0] combined_pulse;
	
	logic[15:0] pulse_result;
	logic[15:0] triangle_result;
	logic[15:0] noise_result;
	
	logic[6:0] scaled_pulse;
	logic[5:0] scaled_triangle;
	logic[4:0] scaled_noise;
	
	logic[7:0] pulse_triangle;
	logic[7:0] pulse_triangle_noise;
	logic[8:0] combined_sample;
	
	logic[7:0] pwm_counter;
	
	multiplier pulse_scaler(.dataa({3'h0, combined_pulse}), .datab(8'd144), .result(pulse_result));
	multiplier traingle_scaler(.dataa({4'h0, triangle_hold}), .datab(8'd162), .result(triangle_result));
	multiplier noise_scaler(.dataa({4'h0, noise_hold}), .datab(8'd94), .result(noise_result));
	
	initial
	begin
		pwm_counter = 8'h00;
	end
	
	always @(posedge clk)
	begin
		dmc_hold <= from_dmc;
		pulse1_hold <= from_pulse1;
		pulse2_hold <= from_pulse2;
		triangle_hold <= from_triangle;
		noise_hold <= from_noise;
		
		combined_pulse <= pulse1_hold + pulse2_hold;
		
		scaled_pulse <= pulse_result[12:6];
		scaled_triangle <= triangle_result[11:6];
		scaled_noise <= noise_result[10:6];
		
		pulse_triangle <= scaled_pulse + scaled_triangle;
		pulse_triangle_noise <= pulse_triangle[6:0] + scaled_noise;
		combined_sample <= pulse_triangle_noise[6:0] + dmc_hold;
		
		pwm_counter <= pwm_counter + 8'h01;
		audio_out <= (combined_sample[7:0] > pwm_counter);
	end

endmodule
