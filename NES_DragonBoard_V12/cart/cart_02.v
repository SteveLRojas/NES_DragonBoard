//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    20:30:26 06/22/2019 
// Design Name: cart
// Module Name:    cart_02 
// Project Name: FPGA_NES
// Target Devices: EP4CE6E22C8N
// Tool versions: Quartus 18.1, 19.1
// Description: Mapper 02 for NES
//
// Dependencies: eeprom.sv, I2C_phy.sv, SDRAM_SP8_I.sv, CHR_RAM.v
//
// Revision: 
// Revision 0.01 - File Created
// Revision 0.02 - Cleanup and optimization
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module cart_02(
		input  wire clk_sys,	// system clock signal
		input wire clk_mem,
		input wire rst,
		output wire rst_out,
		// PRG-ROM interface:
		input wire prg_nce_in,			// prg-rom chip enable (active low)
		input wire[14:0] prg_a_in,		// prg-rom address
		input wire prg_r_nw_in,			// prg-rom read/write select
		input wire[7:0] prg_d_in,		// prg-rom data in
		output wire[7:0] prg_d_out,	// prg-rom data out
		// CHR RAM interface
		input wire[7:0] chr_d_in,
		output wire[7:0] chr_d_out,
		input wire[13:0] chr_a_in,
		input wire chr_r_nw_in,			// chr-rom read/write select
		output wire ciram_nce_out,
		output wire ciram_a10_out,
		// SDRAM interface:
		output wire sdram_cke,
		output wire sdram_cs_n,
		output wire sdram_wre_n,
		output wire sdram_cas_n,
		output wire sdram_ras_n,
		output wire[10:0] sdram_a,
		output wire sdram_ba,
		output wire sdram_dqm,
		inout wire[7:0] sdram_dq,
		// I2C interface:
		inout wire i2c_sda,
		inout wire i2c_scl);
  
	wire[7:0] chrram_dout;
	wire[7:0] prgrom_dout;
	wire chrram_we;

	wire[16:0] mem_address;
	wire mem_ready;
	wire mem_req;

	reg[2:0] page;
	reg reset_hold;
	reg[16:0] prev_mem_address;
	reg init_req;

	assign ciram_a10_out = chr_a_in[10];	//A10 for vertical mirroring, A11 for horizontal
	assign ciram_nce_out = ~chr_a_in[13];
	assign prg_d_out = prgrom_dout & {8{~prg_nce_in}};
	assign chr_d_out = chrram_dout & {8{ciram_nce_out}};
	assign chrram_we = ~chr_a_in[13] & ~chr_r_nw_in;

	assign mem_address = {({3{prg_a_in[14]}} | page), prg_a_in[13:0]};
	assign mem_req = init_req | (mem_address != prev_mem_address);
	assign rst_out = reset_hold;

	initial
	begin
		 page = 3'b111;
		 reset_hold = 1'b1;
		 init_req = 1'b1;
	end

	always @(posedge clk_sys)
	begin
		if((~prg_r_nw_in) & (~prg_nce_in))   //register enabled by write to rom space
			page <= prg_d_in[2:0];
	end

	always @(posedge clk_mem)
	begin
		if(rst)
		begin
			reset_hold <= 1'b1;
			prev_mem_address <= 17'h0F;
			init_req <= 1'b1;
		end
		else
		begin
			if(mem_ready)
				reset_hold <= 1'b0;
			prev_mem_address <= mem_address;
			init_req <= 1'b0;
		end
	end

	wire eep_init_req;
	wire eep_init_ready;
	wire[20:0] eep_init_address;
	wire[7:0] eep_init_data;
	
	SDRAM_SP8_I SDRAM_inst(
			.clk(clk_mem),
			.rst(rst),
			
			.mem_address({4'h0, mem_address}),
			.to_mem(8'h00),
			.from_mem(prgrom_dout),
			.mem_req(mem_req),
			.mem_wren(1'b0),
			.mem_ready(mem_ready),
			
			.sdram_cke(sdram_cke),
			.sdram_cs_n(sdram_cs_n),
			.sdram_wre_n(sdram_wre_n),
			.sdram_cas_n(sdram_cas_n),
			.sdram_ras_n(sdram_ras_n),
			.sdram_a(sdram_a),
			.sdram_ba(sdram_ba),
			.sdram_dqm(sdram_dqm),
			.sdram_dq(sdram_dq),
			
			.init_req(eep_init_req),
			.init_ready(eep_init_ready),
			.init_stop(21'h1FFFF),
			.init_address(eep_init_address),
			.init_data(eep_init_data));
			
	I2C_EEPROM EEPROM_inst(
			.clk(clk_mem),
			.rst(rst),
			.read_req(eep_init_req),
			.address(eep_init_address[16:0]),
			.ready(eep_init_ready),
			.data(eep_init_data),
			.i2c_sda(i2c_sda),
			.i2c_scl(i2c_scl));
			
	CHR_RAM CHR_inst(.address(chr_a_in[12:0]), .clock(clk_sys), .data(chr_d_in), .wren(chrram_we), .q(chrram_dout));

endmodule
