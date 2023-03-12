`timescale 10ns/1ns
module Testbench_sdram();

//External signals
reg clk;
reg n_reset;
reg[3:0] button;
wire[3:0] LED;
wire NES_JOYPAD_CLK;    // joypad output clk signal
wire NES_JOYPAD_LATCH;  // joypad output latch signal
wire AUDIO;             // pwm output audio channel
wire HSYNC, VSYNC;

wire sdram_clk;
wire sdram_cke;
wire sdram_cs_n;
wire sdram_wre_n;
wire sdram_cas_n;
wire sdram_ras_n;
wire[10:0] sdram_a;
wire sdram_ba;
wire sdram_dqm;
wire[7:0] sdram_dq;

wire i2c_sda;
wire i2c_scl;

pullup(i2c_scl);
pullup(i2c_sda);

NES_DragonBoard nes_inst(
		.CLK_50MHZ(clk),		// 50MHz system clock signal
		.reset(n_reset),			// reset push button (active low)
		.button(button),
		.LED(LED),

		.jp_data1(1'b1),
		.jp_data2(1'b1),
		.jp_clk1(),
		.jp_clk2(),
		.jp_latch1(),
		.jp_latch2(),

		.VGA_HSYNC(HSYNC),			// vga hsync signal
		.VGA_VSYNC(VSYNC),			// vga vsync signal
		.VGA_RED(),		// vga red signal
		.VGA_GREEN(),	// vga green signal
		.VGA_BLUE(),	// vga blue signal

		.AUDIO(),		// pwm output audio channel
		// SDRAM interface:
		.sdram_clk(sdram_clk),
		.sdram_cke(sdram_cke),
		.sdram_cs_n(sdram_cs_n),
		.sdram_wre_n(sdram_wre_n),
		.sdram_cas_n(sdram_cas_n),
		.sdram_ras_n(sdram_ras_n),
		.sdram_a(sdram_a),
		.sdram_ba(sdram_ba),
		.sdram_dqm(sdram_dqm),
		.sdram_dq(sdram_dq),
		// I2C interface:
		.i2c_sda(i2c_sda),
		.i2c_scl(i2c_scl));
		
sdr sdram0(
		.Dq(sdram_dq),
		.Addr(sdram_a),
		.Ba(sdram_ba),
		.Clk(sdram_clk),
		.Cke(sdram_cke),
		.Cs_n(sdram_cs_n),
		.Ras_n(sdram_ras_n),
		.Cas_n(sdram_cas_n),
		.We_n(sdram_wre_n),
		.Dqm(sdram_dqm));

always begin: CLOCK_GENERATION
#1 clk =  ~clk;
end

initial begin: CLOCK_INITIALIZATION
	clk = 0;
end

initial begin: TEST_VECTORS
//initial conditions
n_reset = 1'b0;
button = 4'b1110;

#20 n_reset = 1'b1;	//release reset
#20 button = 4'b1111;	//release halt
//#1000 n_reset = 1'b0;
//#20 n_reset = 1'b1;
end
endmodule
