module SDRAM_SP8_I(
		input wire clk,
		input wire rst,
		
		input wire[20:0] mem_address,
		input wire[7:0] to_mem,
		output reg[7:0] from_mem,
		input wire mem_req,
		input wire mem_wren,
		output wire mem_ready,
		
		output wire sdram_cke,
		output wire sdram_cs_n,
		output wire sdram_wre_n,
		output wire sdram_cas_n,
		output wire sdram_ras_n,
		output reg[10:0] sdram_a,
		output reg sdram_ba,
		output reg sdram_dqm,
		inout wire[7:0] sdram_dq,
		
		output reg init_req,
		input wire init_ready,
		input wire[20:0] init_stop,
		output wire[20:0] init_address,
		input wire[7:0] init_data);
		
reg ready;
reg req_flag;
reg prev_req;
reg gate_out;
reg[2:0] sdram_cmd;
reg[2:0] init_refresh_count;	//initially set to 7. On refresh the number of refresh cycles performed will be this number plus one.
reg[9:0] refresh_timer;
reg init_flag;
reg refresh_flag;
reg[20:0] address_hold;
reg[7:0] data_hold;
reg[7:0] data_out;
reg wren;

assign mem_ready = ready;
assign sdram_cke = 1'b1;
assign sdram_cs_n = 1'b0;
assign {sdram_ras_n, sdram_cas_n, sdram_wre_n} = sdram_cmd;
assign sdram_dq = gate_out ? data_out : 8'hZZ;
assign init_address = address_hold;

localparam [2:0] SDRAM_CMD_LOADMODE  = 3'b000;
localparam [2:0] SDRAM_CMD_REFRESH   = 3'b001;
localparam [2:0] SDRAM_CMD_PRECHARGE = 3'b010;
localparam [2:0] SDRAM_CMD_ACTIVE    = 3'b011;
localparam [2:0] SDRAM_CMD_WRITE     = 3'b100;
localparam [2:0] SDRAM_CMD_READ      = 3'b101;
localparam [2:0] SDRAM_CMD_NOP       = 3'b111;

enum logic[5:0] {
			S_RESET,
			S_INIT_DEVICE,
			S_INIT_DEVICE_NOP,
			S_MODE,
			S_MODE_NOP,
			S_IDLE,
			
			S_ACTIVATE,
			S_ACTIVATE_NOP,
			S_READ,
			S_READ_NOP1,
			S_READ_NOP2,
			S_READ_DATA,
			S_WRITE,
			S_WRITE_NOP1,
			S_WRITE_NOP2,
			
			S_REFRESH,
			S_REFRESH_NOP1,
			S_REFRESH_NOP2,
			S_REFRESH_NOP3,
			
			S_INIT_LOAD,
			S_INIT_READ,
			S_INIT_ACTIVATE,
			S_INIT_ACTIVATE_NOP,
			S_INIT_WRITE,
			S_INIT_NOP,
			S_INIT_INC} state;
			
always @(posedge clk)
begin
	if(rst)
	begin
		state <= S_RESET;
		req_flag <= 1'b0;
		prev_req <= 1'b0;
		gate_out <= 1'b0;
		address_hold <= 21'h000;
		ready <= 1'b0;
		init_req <= 1'b0;
		refresh_timer <= 10'h00;
		refresh_flag <= 1'b1;
	end
	else
	begin
		prev_req <= mem_req;
		if(mem_req & ~prev_req)
			req_flag <= 1'b1;
		if(refresh_timer == 10'd390)
		begin
			refresh_timer <= 10'h00;
			refresh_flag <= 1'b1;
		end
		else
			refresh_timer <= refresh_timer + 10'h01;
		case(state)
			S_RESET:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				gate_out <= 1'b0;
				sdram_dqm <= 1'b1;
				init_refresh_count <= 3'b111;
				init_flag <= 1'b1;
				state <= S_INIT_DEVICE;
			end
			S_INIT_DEVICE:
			begin
				sdram_cmd <= SDRAM_CMD_PRECHARGE;
				sdram_a[10] <= 1'b1;	//precharge all
				gate_out <= 1'b0;
				sdram_dqm <= 1'b1;
				state <= S_INIT_DEVICE_NOP;
			end
			S_INIT_DEVICE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				gate_out <= 1'b0;
				sdram_dqm <= 1'b1;
				state <= S_MODE;
			end
			S_MODE:
			begin
				sdram_cmd <= SDRAM_CMD_LOADMODE;
				sdram_a <= 11'b0_000_010_0_000;	//burst length 1, sequential, CAS latency 2, burst read and write.
				sdram_ba <= 1'b0;
				gate_out <= 1'b0;
				sdram_dqm <= 1'b1;
				state <= S_MODE_NOP;
			end
			S_MODE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				gate_out <= 1'b0;
				sdram_dqm <= 1'b1;
				state <= S_REFRESH;
			end
			S_IDLE:
			begin
				ready <= 1'b0;
				if(refresh_flag)
				begin
					state <= S_REFRESH;
				end
				else if(mem_req || req_flag)	//port 2 is read and write
				begin
					address_hold <= mem_address;
					req_flag <= 1'b0;
					wren <= mem_wren;
					data_hold <= to_mem;
					state <= S_ACTIVATE;
				end
				else
				begin
					//wren <= 1'b0;
					state <= state;
				end
			end
			S_ACTIVATE:
			begin
				sdram_cmd <= SDRAM_CMD_ACTIVE;	//send activate command
				sdram_ba <= address_hold[0];	//set bank
				sdram_a[10:0] <= address_hold[11:1];	//set row
				sdram_dqm <= 1'b1;
				state <= S_ACTIVATE_NOP;
			end
			S_ACTIVATE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				if(wren)
					state <= S_WRITE;
				else
					state <= S_READ;
			end
			S_READ:
			begin
				sdram_cmd <= SDRAM_CMD_READ;
				sdram_a[10] <= 1'b1;	//auto precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set column
				sdram_dqm <= 1'b0;
				gate_out <= 1'b0;
				state <= S_READ_NOP1;
			end
			S_READ_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b0;
				gate_out <= 1'b0;
				state <= S_READ_NOP2;
			end
			S_READ_NOP2:
			begin
				state <= S_READ_DATA;
			end
			S_READ_DATA:
			begin
				from_mem <= sdram_dq;
				ready <= 1'b1;
				if(refresh_flag)
					state <= S_REFRESH;
				else
					state <= S_IDLE;
			end
			S_WRITE:
			begin
				sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set col
				sdram_dqm <= 1'b0;
				gate_out <= 1'b1;
				data_out <= data_hold;
				state <= S_WRITE_NOP1;
			end
			S_WRITE_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				state <= S_WRITE_NOP2;
			end
			S_WRITE_NOP2:
			begin
				ready <= 1'b1;
				state <= S_IDLE;
			end
			S_REFRESH:
			begin
				ready <= 1'b0;
				sdram_cmd <= SDRAM_CMD_REFRESH;
				sdram_dqm <= 1'b1;
				state <= S_REFRESH_NOP1;
			end
			S_REFRESH_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				state <= S_REFRESH_NOP2;
			end
			S_REFRESH_NOP2:
			begin
				state <= S_REFRESH_NOP3;
			end
			S_REFRESH_NOP3:
			begin
				if(init_refresh_count == 3'h0)
					refresh_flag <= 1'b0;
				else
					init_refresh_count <= init_refresh_count - 3'b001;
				if(init_flag)
					state <= S_INIT_LOAD;
				else
					state <= S_IDLE;
			end
			S_INIT_LOAD:
			begin
				if(refresh_flag)
				begin
					state <= S_REFRESH;
				end
				else
				begin
					init_req <= 1'b1;
					state <= S_INIT_READ;
				end
			end
			S_INIT_READ:
			begin
				init_req <= 1'b0;
				if(init_ready)
				begin
					data_hold <= init_data;
					state <= S_INIT_ACTIVATE;
				end
			end
			S_INIT_ACTIVATE:
			begin
				sdram_cmd <= SDRAM_CMD_ACTIVE;	//send activate command
				sdram_ba <= address_hold[0];	//set bank
				sdram_a[10:0] <= address_hold[11:1];	//set row
				sdram_dqm <= 1'b1;
				state <= S_INIT_ACTIVATE_NOP;
			end
			S_INIT_ACTIVATE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				state <= S_INIT_WRITE;
			end
			S_INIT_WRITE:
			begin
				sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set col
				sdram_dqm <= 1'b0;
				gate_out <= 1'b1;
				data_out <= data_hold;
				state <= S_INIT_NOP;
			end
			S_INIT_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				state <= S_INIT_INC;
			end
			S_INIT_INC:
			begin
				address_hold <= address_hold + 21'h001;
				if(address_hold == init_stop)
				begin
					init_flag <= 1'b0;
					state <= S_IDLE;
				end
				else
				begin
					state <= S_INIT_LOAD;
				end
			end
			default: ;
		endcase
	end
end
		
endmodule
