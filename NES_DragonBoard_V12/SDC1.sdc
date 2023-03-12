create_clock -period 20.0 [get_ports CLK_50MHZ]
derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -source PLL_inst|altpll_component|auto_generated|pll1|clk[2] -name mem_clk [get_ports sdram_clk]

set_false_path -from * -to [get_ports {LED* jp_clk* jp_latch* VGA_RED* VGA_GREEN* VGA_BLUE* VGA_HSYNC VGA_VSYNC AUDIO i2c_sda i2c_scl}]
set_false_path -from [get_ports {reset button* jp_data* i2c_sda}] -to *

# board delay + Tco(max) of external devices (memory)
set_input_delay -clock mem_clk -max 6.0 [get_ports {sdram_dq[*]}]

# board delay + Tco(min) of external devices
set_input_delay -clock mem_clk -min 2.5 [get_ports {sdram_dq[*]}]

# board delay + Tsu of external devices
set_output_delay -clock mem_clk -max 1.5 [get_ports {sdram_cke sdram_cs_n sdram_wre_n sdram_cas_n sdram_ras_n sdram_a* sdram_ba* sdram_dqm* sdram_dq[*]}]

# board delay - Th of external devices
set_output_delay -clock mem_clk -min -0.8 [get_ports {sdram_cke sdram_cs_n sdram_wre_n sdram_cas_n sdram_ras_n sdram_a* sdram_ba* sdram_dqm* sdram_dq[*]}]
