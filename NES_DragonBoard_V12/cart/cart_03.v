//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    20:30:26 06/22/2019 
// Design Name: cart
// Module Name:    cart_03
// Project Name: FPGA_NES
// Target Devices: XC6SLX9, EP4CE6E22C8N
// Tool versions: 
// Description: Mapper 03 for NES
//
// Dependencies: eeprom.sv, I2C_phy.sv, SDRAM_SP8_I.sv, chr_rom_window.v
//
// Revision: 
// Revision 0.01 - File Created
// Revision 0.02 - Adapted file for Nexys3
// Revision 0.03 - Adapted file for DragonBoard V1.2
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module cart_03(
		input wire clk_sys,				// system clock signal
		input wire clk_mem,
		input wire rst,
		output wire rst_out,
		// PRG-ROM interface.
		input wire prg_nce_in,			// prg-rom chip enable (active low)
		input wire[14:0] prg_a_in,		// prg-rom address
		input wire prg_r_nw_in,			// prg-rom read/write select
		input wire[7:0] prg_d_in,		// prg-rom data in
		output wire[7:0] prg_d_out,		// prg-rom data out
		// CHR ROM interface
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
		inout wire i2c_scl
	);
	
	reg reset_hold;
	reg init_req;
	reg[1:0] page;
	reg[7:0] prgrom_dout;
	
	wire[20:0] window_mem_address;
	wire[7:0] chrrom_dout;
	wire[14:0] mem_address;
	wire[7:0] mem_dout;
	wire prg_addr_change;
	wire window_req;	//Indicates that window module needs to access the main memory
	wire mem_ready;
	wire mem_req;
	wire mem_busy;
	wire req_type;
	
	reg[14:0] prev_prg_mem_address;
	reg mem_active;
	reg req_type_ff;
	
	assign ciram_a10_out = chr_a_in[11];	//A10 for vertical mirroring, A11 for horizontal
	assign ciram_nce_out = ~chr_a_in[13];
	assign prg_d_out = prgrom_dout & {8{~prg_nce_in}};
	assign chr_d_out = chrrom_dout & {8{ciram_nce_out}};
	assign rst_out = reset_hold;
	
	assign prg_addr_change = prg_a_in != prev_prg_mem_address;
	assign mem_req = init_req | prg_addr_change | window_req;
	assign mem_busy = mem_active & ~mem_ready;
	assign req_type = window_req & ~(init_req | prg_addr_change);
	assign mem_address = req_type ? window_mem_address[14:0] : prg_a_in;
	
	initial
	begin
		 page = 2'b00;
		 reset_hold = 1'b1;
		 init_req = 1'b1;
	end
	
	always @(posedge clk_sys or posedge rst)
	begin
		if(rst)
			page <= 2'b00;
		else if((~prg_r_nw_in) & (~prg_nce_in))   //register enabled by write to rom space
			page <= prg_d_in[1:0];
	end

	always @(posedge clk_mem or posedge rst)
	begin
		if(rst)
		begin
			reset_hold <= 1'b1;
			init_req <= 1'b1;
			prgrom_dout <= 8'h00;
			prev_prg_mem_address <= 15'h0000;
			mem_active <= 1'b0;
			req_type_ff <= 1'b0;
		end
		else
		begin
			if(mem_ready)
				reset_hold <= 1'b0;
			init_req <= 1'b0;
			mem_active <= mem_req | (mem_active & ~mem_ready);
			
			if(mem_req & ~mem_busy)
			begin
				if(~req_type)
					prev_prg_mem_address <= prg_a_in;
				req_type_ff <= req_type;
			end
			
			if(mem_ready & ~req_type_ff)
			begin
				prgrom_dout <= mem_dout;
			end
		end
	end
	
	chr_rom_window chr_rom_window_i(
		.clk(clk_mem),
		.rst(rst),
		//CHR ROM interface
		.page({6'h00, page}),
		.init_req(init_req),
		.chr_addr(chr_a_in[12:0]),
		.chr_data(chrrom_dout),
		//Memory interface
		.ready(mem_ready & req_type_ff),
		.req_ack(mem_req & ~mem_busy & req_type),
		.from_mem(mem_dout),
		.mem_addr(window_mem_address),
		.req(window_req)
	);
	
	wire eep_init_req;
	wire eep_init_ready;
	wire[20:0] eep_init_address;
	wire[7:0] eep_init_data;
	
	SDRAM_SP8_I SDRAM_inst(
		.clk(clk_mem),
		.rst(rst),
		// Port 1
		.mem_address({5'h00, req_type, mem_address}),
		.to_mem(8'h00),
		.from_mem(mem_dout),
		.mem_req(mem_req & ~mem_busy),
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
		.init_stop(21'h0FFFF),
		.init_address(eep_init_address),
		.init_data(eep_init_data)
	);
	
	I2C_EEPROM EEPROM_inst(
		.clk(clk_mem),
		.rst(rst),
		.read_req(eep_init_req),
		.address(eep_init_address[16:0]),
		.ready(eep_init_ready),
		.data(eep_init_data),
		.i2c_sda(i2c_sda),
		.i2c_scl(i2c_scl)
	);
	
endmodule
