module I2C_EEPROM(input logic clk, rst, read_req, input logic[16:0] address, output logic ready, output logic[7:0] data, inout wire i2c_sda, i2c_scl);

	logic i2c_start_req;
	logic i2c_stop_req;
	logic i2c_write_req;
	logic i2c_read_req;
	logic i2c_ready;
	logic i2c_master_ack;
	//logic i2c_slave_ack;
	logic[7:0] data_from_master;

I2C_phy i2c_phy_inst(
		.clk(clk),
		.rst(rst),
		.start_req(i2c_start_req),
		.stop_req(i2c_stop_req),
		.write_req(i2c_write_req),
		.read_req(i2c_read_req),
		.ready(i2c_ready),
		.master_ack(i2c_master_ack),
		.slave_ack(),
		.data_from_master(data_from_master),
		.data_from_slave(data),
		.i2c_sda(i2c_sda),
		.i2c_scl(i2c_scl));

	enum logic[4:0]
	{
		S_START,
		S_START_WAIT,

		S_DEVICE_WRITE,
		S_DEVICE_WRITE_WAIT,
		S_ADDRESS_HIGH,
		S_ADDRESS_HIGH_WAIT,
		S_ADDRESS_LOW,
		S_ADDRESS_LOW_WAIT,

		S_REPEAT_START,
		S_REPEAT_START_WAIT,

		S_DEVICE_READ,
		S_DEVICE_READ_WAIT,

		S_DATA_READ,
		S_DATA_READ_WAIT,

		S_ADDRESS_COMP,
		S_STOP,
		S_STOP_WAIT,
		S_IDLE
	} state;

logic[16:0] address_counter;
logic prev_read_req;
logic read_flag;

	always_ff @(posedge clk)
	begin
		i2c_start_req <= 1'b0;
		i2c_stop_req <= 1'b0;
		i2c_write_req <= 1'b0;
		i2c_read_req <= 1'b0;
		ready <= 1'b0;
		if(rst)
		begin
			state <= S_IDLE;
			//address_counter <= 17'h00000;
			prev_read_req <= 1'b1;
			read_flag <= 1'b0;
		end
		else
		begin
			prev_read_req <= read_req;
			if(read_req & ~prev_read_req)
				read_flag <= 1'b1;
			case(state)
				S_START:
				begin
					i2c_start_req <= 1'b1;
					state <= S_START_WAIT;
				end
				S_START_WAIT:
				begin
					if(i2c_ready)
						state <= S_DEVICE_WRITE;
				end
				S_DEVICE_WRITE:
				begin
					data_from_master <= {4'hA, 2'b10, address[16], 1'b0};
					i2c_write_req <= 1'b1;
					state <= S_DEVICE_WRITE_WAIT;
				end
				S_DEVICE_WRITE_WAIT:
				begin
					if(i2c_ready)
						state <= S_ADDRESS_HIGH;
				end
				S_ADDRESS_HIGH:
				begin
					data_from_master <= address[15:8];
					i2c_write_req <= 1'b1;
					state <= S_ADDRESS_HIGH_WAIT;
				end
				S_ADDRESS_HIGH_WAIT:
				begin
					if(i2c_ready)
						state <= S_ADDRESS_LOW;
				end
				S_ADDRESS_LOW:
				begin
					data_from_master <= address[7:0];
					i2c_write_req <= 1'b1;
					state <= S_ADDRESS_LOW_WAIT;
				end
				S_ADDRESS_LOW_WAIT:
				begin
					if(i2c_ready)
						state <= S_REPEAT_START;
				end
				S_REPEAT_START:
				begin
					i2c_start_req <= 1'b1;
					state <= S_REPEAT_START_WAIT;
				end
				S_REPEAT_START_WAIT:
				begin
					if(i2c_ready)
						state <= S_DEVICE_READ;
				end
				S_DEVICE_READ:
				begin
					data_from_master <= {4'hA, 2'b10, address[16], 1'b1};
					i2c_write_req <= 1'b1;
					state <= S_DEVICE_READ_WAIT;
				end
				S_DEVICE_READ_WAIT:
				begin
					if(i2c_ready)
						state <= S_DATA_READ;
				end
				S_DATA_READ:
				begin
					i2c_read_req <= 1'b1;
					state <= S_DATA_READ_WAIT;
				end
				S_DATA_READ_WAIT:
				begin
					if(i2c_ready)
					begin
						address_counter <= address_counter + 17'h00001;
						ready <= 1'b1;
						state <= S_ADDRESS_COMP;
					end
				end
				S_ADDRESS_COMP:
				begin
					if(read_flag && (&address_counter))
						i2c_master_ack <= 1'b0;
					if(read_flag && address_counter == address && i2c_master_ack)
					begin
						read_flag <= 1'b0;
						state <= S_DATA_READ;
					end
					else if(read_flag || ~i2c_master_ack)
					begin
						state <= S_STOP;
					end
				end
				S_STOP:
				begin
					i2c_stop_req <= 1'b1;
					state <= S_STOP_WAIT;
				end
				S_STOP_WAIT:
				begin
					if(i2c_ready)
						state <= S_IDLE;
				end
				S_IDLE:
				begin
					if(read_flag)
					begin
						address_counter <= address;
						read_flag <= 1'b0;
						i2c_master_ack <= 1'b1;
						state <= S_START;
					end
				end
				default: ;
			endcase // state
		end
	end

endmodule : I2C_EEPROM
