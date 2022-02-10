module joypad(
		input logic clk,
		input logic wren,
		input logic[15:0] addr,
		input logic from_cpu,
		input logic jp1_data,
		input logic jp2_data,
		output logic jp1_clk,
		output logic jp2_clk,
		output logic jp_latch,
		output logic[7:0] to_cpu);
		
	// Joypads are mapped into the APU's range.
	reg jp1_data_s;
	reg jp2_data_s;
	
	wire joypad1_cs;
	wire joypad2_cs;
	
	assign joypad1_cs = (addr == 16'h4016);
	assign joypad2_cs = (addr == 16'h4017);
	//assign jp_latch = (joypad1_cs && wren && from_cpu);
	assign jp1_clk = joypad1_cs & ~wren;
	assign jp2_clk = joypad2_cs & ~wren;
	assign to_cpu = {1'b0, joypad1_cs | joypad2_cs, 5'h00, (joypad1_cs & ~jp1_data_s) | (joypad2_cs & ~jp2_data_s)};
	
	always @(posedge clk)
	begin
		jp1_data_s <= jp1_data;
		jp2_data_s <= jp2_data;
		if(joypad1_cs & wren)
			jp_latch <= from_cpu;
	end
	
	endmodule
	