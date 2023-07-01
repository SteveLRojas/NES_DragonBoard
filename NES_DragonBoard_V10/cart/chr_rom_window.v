`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser Rojas (ELR)
// 
// Create Date:    08:20:42 06/25/2023 
// Design Name: 
// Module Name:    chr_rom_window 
// Project Name: Nexys3_NES
// Target Devices: XC6SLX16, EP4CE6E22C8N
// Tool versions: ISE 14.7, Quartus 19.1
// Description: 
//
// Dependencies: chr_window_ram
//
// Revision: 
// Revision 0.01 - File Created
// Revision 0.02 - Updated for DragonBoard
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module chr_rom_window(
		input wire clk,
		input wire rst,
		//CHR ROM interface
		input wire[7:0] page,
		input wire init_req,
		input wire[12:0] chr_addr,
		output wire[7:0] chr_data,
		//Memory interface
		input wire ready,
		input wire req_ack,
		input wire[7:0] from_mem,
		output wire[20:0] mem_addr,
		output wire req
	);

	reg mem_req_ff;
	reg[12:0] addr_count_req;
	reg[12:0] addr_count_res;
	reg[7:0] prev_page;
	wire page_change;
	
	assign req = mem_req_ff;
	assign mem_addr = {page, addr_count_req};
	assign page_change = init_req | (page != prev_page);

	chr_window_ram chr_window_ram_i(
		.clock(clk),
		.data(from_mem),
		.rdaddress(chr_addr),
		.wraddress(addr_count_res),
		.wren(ready),
		.q(chr_data)
	);
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			mem_req_ff <= 1'b0;
			addr_count_req <= 13'h0000;
			addr_count_res <= 13'h0000;
			prev_page <= 8'h00;
		end
		else
		begin
			mem_req_ff <= page_change | (mem_req_ff & ~(&addr_count_req & req_ack));
			prev_page <= page;
			
			if(page_change)
			begin
				addr_count_req <= 13'h0000;
				addr_count_res <= 13'h0000;
			end
			else if(req_ack)
			begin
				addr_count_res <= addr_count_req;
				addr_count_req <= addr_count_req + 13'h0001;
			end
		end
	end

endmodule
