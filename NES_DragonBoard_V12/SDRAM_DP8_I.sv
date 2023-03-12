module SDRAM_DP8_I(
		input logic clk,
		input logic rst,
		
		input logic[20:0] p1_address,
		input logic[7:0] p1_to_mem,
		output logic[7:0] p1_from_mem,
		input logic p1_req,
		input logic p1_wren,
		output logic p1_ready,
		
		input logic[20:0] p2_address,
		input logic[7:0] p2_to_mem,
		output logic[7:0] p2_from_mem,
		input logic p2_req,
		input logic p2_wren,
		output logic p2_ready,
		
		output wire sdram_cke,
		output wire sdram_cs_n,
		output wire sdram_wre_n,
		output wire sdram_cas_n,
		output wire sdram_ras_n,
		output logic[11:0] sdram_a,
		output logic[1:0] sdram_ba,
		output logic[1:0] sdram_dqm,
		inout wire[15:0] sdram_dq,
		
		output logic init_req,
		input logic init_ready,
		input logic[20:0] init_stop,
		output logic[20:0] init_address,
		input logic[7:0] init_data);
		
reg ready1;
reg ready2;
reg p1_req_flag;
reg p2_req_flag;
reg prev_p1_req;
reg prev_p2_req;
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

assign p1_ready = ready1;
assign p2_ready = ready2;
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

//SDRAM controller states
enum logic[5:0] {
			S_RESET,
			S_INIT_DEVICE,
			S_INIT_DEVICE_NOP,
			S_MODE,
			S_MODE_NOP,
			S_IDLE,
			
			S_ACTIVATE_P1,
			S_ACTIVATE_P1_NOP,
			S_READ_P1,
			S_READ_P1_NOP1,
			S_READ_P1_NOP2,
			S_READ_P1_DATA,
			S_WRITE_P1,
			S_WRITE_P1_NOP1,
			S_WRITE_P1_NOP2,
			
			S_ACTIVATE_P2,
			S_ACTIVATE_P2_NOP,
			S_READ_P2,
			S_READ_P2_NOP1,
			S_READ_P2_NOP2,
			S_READ_P2_DATA,
			S_WRITE_P2,
			S_WRITE_P2_NOP1,
			S_WRITE_P2_NOP2,
			
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
		p1_req_flag <= 1'b0;
		p2_req_flag <= 1'b0;
		prev_p1_req <= 1'b0;
		prev_p2_req <= 1'b0;
		gate_out <= 1'b0;
		address_hold <= 21'h000;
		ready1 <= 1'b0;
		ready2 <= 1'b0;
		init_req <= 1'b0;
		refresh_timer <= 10'h00;
		refresh_flag <= 1'b1;
	end
	else
	begin
		prev_p1_req <= p1_req;
		prev_p2_req <= p2_req;
		if(p1_req & ~prev_p1_req)
			p1_req_flag <= 1'b1;
		if(p2_req & ~prev_p2_req)
			p2_req_flag <= 1'b1;
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
				sdram_dqm <= 2'b11;
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
				ready1 <= 1'b0;
				ready2 <= 1'b0;
				if(refresh_flag)
				begin
					state <= S_REFRESH;
				end
				else if(p1_req || p1_req_flag)	//port 1 is read and write
				begin
					address_hold <= p1_address;
					p1_req_flag <= 1'b0;
					wren <= p1_wren;
					data_hold <= p1_to_mem;
					state <= S_ACTIVATE_P1;
				end
				else if(p2_req || p2_req_flag)	//port 2 is read and write
				begin
					address_hold <= p2_address;
					p2_req_flag <= 1'b0;
					wren <= p2_wren;
					data_hold <= p2_to_mem;
					state <= S_ACTIVATE_P2;
				end
				else
				begin
					//wren <= 1'b0;
					state <= state;
				end
			end
			S_ACTIVATE_P1:
			begin
				sdram_cmd <= SDRAM_CMD_ACTIVE;	//send activate command
				sdram_ba <= address_hold[0];	//set bank
				sdram_a[10:0] <= address_hold[11:1];	//set row
				sdram_dqm <= 1'b1;
				state <= S_ACTIVATE_P1_NOP;
			end
			S_ACTIVATE_P1_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				if(wren)
					state <= S_WRITE_P1;
				else
					state <= S_READ_P1;
			end
			S_READ_P1:
			begin
				sdram_cmd <= SDRAM_CMD_READ;
				sdram_a[10] <= 1'b1;	//auto precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set column
				sdram_dqm <= 1'b0;
				gate_out <= 1'b0;
				state <= S_READ_P1_NOP1;
			end
			S_READ_P1_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b0;
				gate_out <= 1'b0;
				state <= S_READ_P1_NOP2;
			end
			S_READ_P1_NOP2:
			begin
				state <= S_READ_P1_DATA;
			end
			S_READ_P1_DATA:
			begin
				p1_from_mem <= sdram_dq;
				ready1 <= 1'b1;
				if(refresh_flag)
					state <= S_REFRESH;
				else
					state <= S_IDLE;
			end
			S_WRITE_P1:
			begin
				sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set col
				sdram_dqm <= 1'b0;
				gate_out <= 1'b1;
				data_out <= data_hold;
				state <= S_WRITE_P1_NOP1;
			end
			S_WRITE_P1_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				state <= S_WRITE_P1_NOP2;
			end
			S_WRITE_P1_NOP2:
			begin
				ready1 <= 1'b1;
				state <= S_IDLE;
			end
			S_ACTIVATE_P2:
			begin
				sdram_cmd <= SDRAM_CMD_ACTIVE;	//send activate command
				sdram_ba <= address_hold[0];	//set bank
				sdram_a[10:0] <= address_hold[11:1];	//set row
				sdram_dqm <= 1'b1;
				state <= S_ACTIVATE_P2_NOP;
			end
			S_ACTIVATE_P2_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				if(wren)
					state <= S_WRITE_P2;
				else
					state <= S_READ_P2;
			end
			S_READ_P2:
			begin
				sdram_cmd <= SDRAM_CMD_READ;
				sdram_a[10] <= 1'b1;	//auto precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set column
				sdram_dqm <= 1'b0;
				gate_out <= 1'b0;
				state <= S_READ_P2_NOP1;
			end
			S_READ_P2_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b0;
				gate_out <= 1'b0;
				state <= S_READ_P2_NOP2;
			end
			S_READ_P2_NOP2:
			begin
				state <= S_READ_P2_DATA;
			end
			S_READ_P2_DATA:
			begin
				p2_from_mem <= sdram_dq;
				ready2 <= 1'b1;
				if(refresh_flag)
					state <= S_REFRESH;
				else
					state <= S_IDLE;
			end
			S_WRITE_P2:
			begin
				sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9] <= 1'b0;
				sdram_a[8:0] <= address_hold[20:12];	//set col
				sdram_dqm <= 1'b0;
				gate_out <= 1'b1;
				data_out <= data_hold;
				state <= S_WRITE_P2_NOP1;
			end
			S_WRITE_P2_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				sdram_dqm <= 1'b1;
				gate_out <= 1'b0;
				state <= S_WRITE_P2_NOP2;
			end
			S_WRITE_P2_NOP2:
			begin
				ready2 <= 1'b1;
				state <= S_IDLE;
			end
			S_REFRESH:
			begin
				ready1 <= 1'b0;
				ready2 <= 1'b0;
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
				if(~(|init_refresh_count))
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
