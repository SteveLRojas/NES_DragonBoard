module button_debounce
	#(
		parameter INVERT_BUTTONS = 1'b1,
		parameter NUM_BUTTONS = 4,
		parameter CLK_DIV_BITS = 15	//25MHz
	)
	(
		input wire clk,
		input wire rst_in,
		input wire[NUM_BUTTONS - 1 : 0] button_in,
		output reg rst_out,
		output reg[NUM_BUTTONS - 1 : 0] button_out
	);
	
	reg[CLK_DIV_BITS - 1 : 0] clk_div;
	reg rst_s;
	reg rst_ff;
	reg button_disable;
	reg[3:0] button_count[NUM_BUTTONS - 1 : 0];
	reg[NUM_BUTTONS - 1 : 0] button_s;
	
	wire sample_pulse;
	wire button_max[NUM_BUTTONS - 1 : 0];
	wire button_min[NUM_BUTTONS - 1 : 0];
	
	assign sample_pulse = &clk_div;
	
	genvar d;
	generate
		for(d = 0; d < NUM_BUTTONS; d = d + 1)
		begin : min_max_block
			assign button_max[d] = &button_count[d];
			assign button_min[d] = ~|button_count[d];
		end
	endgenerate
	
	initial
	begin
		rst_s = 1'b1;
		rst_ff = 1'b1;
		rst_out = 1'b0;	//have rising edge at power on
	end
	
	always @(posedge clk)
	begin
		button_s <= button_in ^ {NUM_BUTTONS{INVERT_BUTTONS}};
		rst_s <= rst_in ^ INVERT_BUTTONS;
		rst_ff <= &button_s | rst_s;
		rst_out <= rst_ff;
	end
	
	always @(posedge clk or posedge rst_out)
	begin
		if(rst_out)
		begin
			clk_div <= CLK_DIV_BITS'('h0);
			button_disable <= 1'b1;
			
			for(integer d = 0; d < NUM_BUTTONS; d = d + 1)
			begin
				button_count[d] <= 4'h0;
				button_out[d] <= 1'b0;
			end
		end
		else
		begin
			clk_div <= clk_div + CLK_DIV_BITS'('h1);
			button_disable <= button_disable & |button_s;
			
			if(sample_pulse & ~button_disable)
			begin
				for(integer d = 0; d < NUM_BUTTONS; d = d + 1)
				begin
					if(button_s[d] & ~button_max[d])
					begin
						button_count[d] <= button_count[d] + 4'h1;
					end
					if(~button_s[d] & ~button_min[d])
					begin
						button_count[d] <= button_count[d] - 4'h1;
					end
					
					if(button_max[d])
						button_out[d] <= 1'b1;
					if(button_min[d])
						button_out[d] <= 1'b0;
				end
			end
		end
	end

endmodule
