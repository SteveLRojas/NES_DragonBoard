transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/PPU_gen2.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/nes_top.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/sprdma.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/rp2a03.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/cpu.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_triangle.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_pulse.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_noise.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_mixer.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_length_counter.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_frame_counter.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_envelope_generator.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_div.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cart {E:/NES_DragonBoard_V10/cart/cart_02.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/vram.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/wram.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/PLL0.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/CHR_RAM.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/db {E:/NES_DragonBoard_V10/db/pll0_altpll.v}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/eeprom.sv}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/SDRAM_SP8_I.sv}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/I2C_phy.sv}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/joypad.sv}

vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cart {E:/NES_DragonBoard_V10/cart/cart_02.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_div.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_envelope_generator.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_frame_counter.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_length_counter.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_mixer.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_noise.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_pulse.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu/apu {E:/NES_DragonBoard_V10/cpu/apu/apu_triangle.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/cpu.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/jp.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/rp2a03.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10/cpu {E:/NES_DragonBoard_V10/cpu/sprdma.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/CHR_RAM.v}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/eeprom.sv}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/I2C_phy.sv}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/nes_top.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/PLL0.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/PPU_gen2.v}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/sdr.sv}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/SDRAM_SP8_I.sv}
vlog -sv -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/testbench.sv}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/vram.v}
vlog -vlog01compat -work work +incdir+E:/NES_DragonBoard_V10 {E:/NES_DragonBoard_V10/wram.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  Testbench_sdram

add wave *
view structure
view signals
run 1 us
