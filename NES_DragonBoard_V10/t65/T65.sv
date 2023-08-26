// ****
// T65(b) core. In an effort to merge and maintain bug fixes ....
//
// Ver 313 WoS January 2015
//   Fixed issue that NMI has to be first if issued the same time as a BRK instruction is latched in
//   Now all Lorenz CPU tests on FPGAARCADE C64 core (sources used: SVN version 1021) are OK! :D :D :D
//   This is just a starting point to go for optimizations and detailed fixes (the Lorenz test can't find)
//
// Ver 312 WoS January 2015
//   Undoc opcode timing fixes for $B3 (LAX iy) and $BB (LAS ay)
//   Added comments in MCode section to find handling of individual opcodes more easily
//   All "basic" Lorenz instruction test (individual functional checks, CPUTIMING check) work now with 
//       actual FPGAARCADE C64 core (sources used: SVN version 1021).
//
// Ver 305, 306, 307, 308, 309, 310, 311 WoS January 2015
//   Undoc opcode fixes (now all Lorenz test on instruction functionality working, except timing issues on $B3 and $BB):
//     SAX opcode
//     SHA opcode
//     SHX opcode
//     SHY opcode
//     SHS opcode
//     LAS opcode
//     alternate SBC opcode
//     fixed NOP with immediate param (caused Lorenz trap test to fail)
//     IRQ and NMI timing fixes (in conjuction with branches)
//
// Ver 304 WoS December 2014
//   Undoc opcode fixes:
//     ARR opcode
//     ANE/XAA opcode
//   Corrected issue with NMI/IRQ prio (when asserted the same time)
//
// Ver 303 ost(ML) July 2014
//   (Sorry for some scratchpad comments that may make little sense)
//   Mods and some 6502 undocumented instructions.
//   Not correct opcodes acc. to Lorenz tests (incomplete list):
//     NOPN    (nop)
//     NOPZX   (nop + byte 172)
//     NOPAX   (nop + word da  ...  da:  byte 0)
//     ASOZ    (byte $07 + byte 172)
//
// Ver 303,302 WoS April 2014
//     Bugfixes for NMI from foft
//     Bugfix for BRK command (and its special flag)
//
// Ver 300,301 WoS January 2014
//     More merging
//     Bugfixes by ehenciak added, started tidyup *bust*
//
// MikeJ March 2005
//      Latest version from www.fpgaarcade.com (original www.opencores.org)
// ****
//
// 65xx compatible microprocessor core
//
// FPGAARCADE SVN: $Id: T65.vhd 1347 2015-05-27 20:07:34Z wolfgang.scherr $
//
// Copyright (c) 2002...2015
//               Daniel Wallner (jesus <at> opencores <dot> org)
//               Mike Johnson   (mikej <at> fpgaarcade <dot> com)
//               Wolfgang Scherr (WoS <at> pin4 <dot> at>
//               Morten Leikvoll ()
//
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author(s), but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.
//
// ////- IMPORTANT NOTES ////-
//
// Limitations:
//   65C02 and 65C816 modes are incomplete (and definitely untested after all 6502 undoc fixes)
//      65C02 supported : inc, dec, phx, plx, phy, ply
//      65D02 missing : bra, ora, lda, cmp, sbc, tsb*2, trb*2, stz*2, bit*2, wai, stp, jmp, bbr*8, bbs*8
//   Some interface signals behave incorrect
//   NMI interrupt handling not nice, needs further rework (to cycle-based encoding).
//
// Usage:
//   The enable signal allows clock gating / throttling without using the ready signal.
//   Set it to constant '1' when using the Clk input as the CPU clock directly.
//
//   TAKE CARE you route the DO signal back to the DI signal while R_W_n='0',
//   otherwise some undocumented opcodes won't work correctly.
//   EXAMPLE:
//      CPU : entity work.T65
//          port map (
//              R_W_n   => cpu_rwn_s,
//              [....all other ports....]
//              DI      => cpu_din_s,
//              DO      => cpu_dout_s
//          );
//      cpu_din_s <= cpu_dout_s when cpu_rwn_s='0' else 
//                   [....other sources from peripherals and memories...]
//
// ////- IMPORTANT NOTES ////-
// Translated and modified by Esteban (Steve) Looser-Rojas AKA Dragomir.
// WW10 2022
// looserr2@illinois.edu
module T65(
		input logic[1:0] Mode,  // "00" => 6502, "01" => 65C02, "10" => 65C816
		input logic BCD_en,     // '0' => 2A03/2A07, '1' => others

		input logic Res_n,
		input logic Clk,
		input logic Enable,

		output logic[23:0] A,
		input logic[7:0] DI,
		output logic[7:0] DO,

		input logic Rdy,
		input logic Abort_n,
		input logic IRQ_n,
		input logic NMI_n,
		input logic SO_n,
		output logic R_W_n,
		output logic Sync,
		output logic EF,
		output logic MF,
		output logic XF,
		output logic ML_n,
		output logic VP_n,
		output logic VDA,
		output logic VPA,

		//DEBUG   : out T_t65_dbg;
		output logic NMI_ack
	);
    
	// *** From T65_Pack.vhd ***
	localparam Flag_C = 3'h0;
	localparam Flag_Z = 3'h1;
	localparam Flag_I = 3'h2;
	localparam Flag_D = 3'h3;
	localparam Flag_B = 3'h4;
	localparam Flag_1 = 3'h5;
	localparam Flag_V = 3'h6;
	localparam Flag_N = 3'h7;

	typedef enum logic[2:0] {Cycle_sync, Cycle_1, Cycle_2, Cycle_3, Cycle_4, Cycle_5, Cycle_6, Cycle_7} T_Lcycle;

	typedef enum logic[3:0] 
	{
		Set_BusA_To_DI,
		Set_BusA_To_ABC,
		Set_BusA_To_X,
		Set_BusA_To_Y,
		Set_BusA_To_S,
		Set_BusA_To_P,
		Set_BusA_To_DA,
		Set_BusA_To_DAO,
		Set_BusA_To_DAX,
		Set_BusA_To_AAX,
		Set_BusA_To_DONTCARE
	} T_Set_BusA_To;

	typedef enum logic[1:0] 
	{
		Set_Addr_To_SP,
		Set_Addr_To_ZPG,
		Set_Addr_To_PBR,
		Set_Addr_To_BA
	} T_Set_Addr_To;

	typedef enum logic[3:0] 
	{
		Write_Data_DL,
		Write_Data_ABC,
		Write_Data_X,
		Write_Data_Y,
		Write_Data_S,
		Write_Data_P,
		Write_Data_PCL,
		Write_Data_PCH,
		Write_Data_AX,
		Write_Data_AXB,
		Write_Data_XB,
		Write_Data_YB,
		Write_Data_DONTCARE
	} T_Write_Data;

	typedef enum logic[4:0]
	{
		ALU_OP_OR,  //"0000"
		ALU_OP_AND,  //"0001"
		ALU_OP_EOR,  //"0010"
		ALU_OP_ADC,  //"0011"
		ALU_OP_EQ1,  //"0100" EQ1 does not change N,Z flags, EQ2/3 does.
		ALU_OP_EQ2,  //"0101" Not sure yet whats the difference between EQ2&3. They seem to do the same ALU op
		ALU_OP_CMP,  //"0110"
		ALU_OP_SBC,  //"0111"
		ALU_OP_ASL,  //"1000"
		ALU_OP_ROL,  //"1001"
		ALU_OP_LSR,  //"1010"
		ALU_OP_ROR,  //"1011"
		ALU_OP_BIT,  //"1100"
		//    ALU_OP_EQ3,  //"1101"
		ALU_OP_DEC,  //"1110"
		ALU_OP_INC,  //"1111"
		ALU_OP_ARR,
		ALU_OP_ANC,
		ALU_OP_SAX,
		ALU_OP_XAA
		//    ALU_OP_UNDEF//"----"//may be replaced with any?
	} T_ALU_OP;

	typedef struct
	{
		logic[7:0] I;   // instruction
		logic[7:0] A;   // A reg
		logic[7:0] X;   // X reg
		logic[7:0] Y;   // Y reg
		logic[7:0] S;   // stack pointer
		logic[7:0] P;   // processor flags
	} T_t65_dbg;
	// *** End T65_Pack.vhd ***

    // *** From T65 architecture ***
    // Registers
	logic[15:0] ABC, X, Y;
	logic[7:0] P, AD, DL;
	logic[7:0] PwithB;  //ML:New way to push P with correct B state to stack
	logic[7:0] BAH;
	logic[8:0] BAL;
	logic[7:0] PBR;
	logic[7:0] DBR;
	logic[15:0] PC;
	logic[15:0] S;
	logic EF_i;
	logic MF_i;
	logic XF_i;

	logic[7:0] IR;
	logic[2:0] MCycle;

	logic[1:0] Mode_r;
	logic BCD_en_r;
	T_ALU_OP ALU_Op_r;
	T_Write_Data Write_Data_r;
	T_Set_Addr_To Set_Addr_To_r;
	logic[8:0] PCAdder;

	logic RstCycle;
	logic IRQCycle;
	logic NMICycle;

	logic SO_n_o;
	logic IRQ_n_o;
	logic NMI_n_o;
	logic NMIAct;

	logic Break;
    
    initial
    begin
        P = 8'h00;
        AD = 8'h00;
        DL = 8'h00;
    end

	// ALU signals
	logic[7:0] BusA;
	logic[7:0] BusA_r;
	logic[7:0] BusB;
	logic[7:0] BusB_r;
	logic[7:0] ALU_Q;
	logic[7:0] P_Out;

	// Micro code outputs
	T_Lcycle LCycle;
	T_ALU_OP ALU_Op;
	T_Set_BusA_To Set_BusA_To;
	T_Set_Addr_To Set_Addr_To;
	T_Write_Data Write_Data;
	logic[1:0] Jump;
	logic[1:0] BAAdd;
	logic BreakAtNA;
	logic ADAdd;
	logic AddY;
	logic PCAdd;
	logic Inc_S;
	logic Dec_S;
	logic LDA;
	logic LDP;
	logic LDX;
	logic LDY;
	logic LDS;
	logic LDDI;
	logic LDALU;
	logic LDAD;
	logic LDBAL;
	logic LDBAH;
	logic SaveP;
	logic Write;

	logic Res_n_i;
	logic Res_n_d;

	logic really_rdy;
	logic WRn_i;

	logic NMI_entered;

	assign NMI_ack = NMIAct;

	// gate Rdy with read/write to make an "OK, it's really OK to stop the processor"
	assign really_rdy = Rdy | ~WRn_i;
	assign Sync = (MCycle == 3'b000);
	assign EF = EF_i;
	assign MF = MF_i;
	assign XF = XF_i;
	assign R_W_n = WRn_i;
	assign ML_n = ~((IR[7:6] != 2'b10) && (IR[2:1] == 2'b11) && (MCycle[2:1] != 2'b00));
	assign VP_n = ~((IRQCycle == 1'b1) && ((MCycle == 3'b101) || (MCycle == 3'b110)));
	assign VDA = (Set_Addr_To_r != Set_Addr_To_PBR);
	assign VPA = ~Jump[1];

	// debugging signals
	//DEBUG.I <= IR;
	//DEBUG.A <= ABC(7 downto 0);
	//DEBUG.X <= X(7 downto 0);
	//DEBUG.Y <= Y(7 downto 0);
	//DEBUG.S <= std_logic_vector(S(7 downto 0));
	//DEBUG.P <= P;

	T65_MCode mcode(
		//inputs
		.Mode(Mode_r),
		.IR(IR),
		.MCycle(MCycle),
		.P(P),
		//outputs
		.LCycle(LCycle),
		.ALU_Op(ALU_Op),
		.Set_BusA_To(Set_BusA_To),
		.Set_Addr_To(Set_Addr_To),
		.Write_Data(Write_Data),
		.Jump(Jump),
		.BAAdd(BAAdd),
		.BreakAtNA(BreakAtNA),
		.ADAdd(ADAdd),
		.AddY(AddY),
		.PCAdd(PCAdd),
		.Inc_S(Inc_S),
		.Dec_S(Dec_S),
		.LDA(LDA),
		.LDP(LDP),
		.LDX(LDX),
		.LDY(LDY),
		.LDS(LDS),
		.LDDI(LDDI),
		.LDALU(LDALU),
		.LDAD(LDAD),
		.LDBAL(LDBAL),
		.LDBAH(LDBAH),
		.SaveP(SaveP),
		.Write(Write));

	T65_ALU alu(
		.Mode(Mode_r),
		.BCD_en(BCD_en_r),
		.Op(ALU_Op_r),
		.BusA(BusA_r),
		.BusB(BusB),
		.P_In(P),
		.P_Out(P_Out),
		.Q(ALU_Q));

	// the 65xx design requires at least two clock cycles before
	// starting its reset sequence (according to datasheet)
	always_ff @(posedge Clk or negedge Res_n)
		begin
		if(~Res_n)
		begin
			Res_n_i <= 1'b0;
			Res_n_d <= 1'b0;
		end
		else
		begin
			Res_n_i <= Res_n_d;
			Res_n_d <= 1'b1;
		end
	end

	always_ff @(posedge Clk or negedge Res_n_i)
	begin
		if(~Res_n_i)
		begin
			PC <= 16'h0000;	// Program Counter
			IR <= 8'h00;
			S <= 16'h0000;	// Dummy
			PBR <= 8'h00;
			DBR <= 8'h00;

			Mode_r <= 2'b00;
			BCD_en_r <= 1'b1;
			ALU_Op_r <= ALU_OP_BIT;
			Write_Data_r <= Write_Data_DL;
			Set_Addr_To_r <= Set_Addr_To_PBR;

			WRn_i <= 1'b1;
			EF_i <= 1'b1;
			MF_i <= 1'b1;
			XF_i <= 1'b1;
		end
		else
		begin
			if(Enable)
			begin
				if(really_rdy)
				begin
					WRn_i <= ~Write | RstCycle;

					PBR <= 8'hFF;	// Dummy
					DBR <= 8'hFF;	// Dummy
					EF_i <= 1'b0;	// Dummy
					MF_i <= 1'b0;	// Dummy
					XF_i <= 1'b0;	// Dummy

					if(MCycle == 3'b000)
					begin
						Mode_r <= Mode;
						BCD_en_r <= BCD_en;

						if(~IRQCycle & ~NMICycle)
							PC <= PC + 16'h0001;

						if(IRQCycle | NMICycle)
							IR <= 8'h00;
						else
							IR <= DI;

						if(LDS)	// LAS won't work properly if not limited to machine cycle 0
						begin
							S[7:0] <= ALU_Q[7:0];
						end
					end

					ALU_Op_r <= ALU_Op;
					Write_Data_r <= Write_Data;
					if(Break)
						Set_Addr_To_r <= Set_Addr_To_PBR;
					else
						Set_Addr_To_r <= Set_Addr_To;

					if(Inc_S)
						S <= S + 8'h01;
					if(Dec_S & (RstCycle | (Mode == 2'b00)))	// 6502 only?
						S <= S - 8'h01;

					if(IR == 8'h00 && MCycle == 3'b001 && !IRQCycle && !NMICycle)
						PC <= PC + 16'h0001;
					//
					// jump control logic
					//
					case(Jump)
						2'b01: PC <= PC + 16'h0001;
						2'b10: PC <= {DI, DL};
						2'b11:
						begin
							if(PCAdder[8])
							begin
								if(~DL[7])
									PC[15:8] <= PC[15:8] + 8'h01;
								else
									PC[15:8] <= PC[15:8] - 8'h01;
							end
							PC[7:0] <= PCAdder[7:0];
						end
						default: ;
					endcase
				end
			end
		end
	end

	assign PCAdder = PCAdd ? ({1'b0, PC[7:0]} + {DL[7], DL}) : {1'b0, PC[7:0]};

    logic[7:0] tmpP;    //Lets try to handle loading P at mcycle=0 and set/clk flags at same cycle
	always @(posedge Clk or negedge Res_n_i)	//TODO: Fix missing signals from reset list
	begin
		if(~Res_n_i)
		begin
			P <= 8'h00;	// ensure we have nothing set on reset
		end
		else
		begin
			tmpP <= P;
			if(Enable)
			begin
				if(really_rdy)
				begin
					if(MCycle == 3'b000)
					begin
						if(LDA)
							ABC[7:0] <= ALU_Q;
						if(LDX)
							X[7:0] <= ALU_Q;
						if(LDY)
							Y[7:0] <= ALU_Q;
						if(LDA || LDX || LDY)
							tmpP <= P_Out;
					end
					
					if(SaveP)
						tmpP <= P_Out;
					if(LDP)
						tmpP <= ALU_Q;

					if(IR[4:0] == 5'b11000)
					begin
						case(IR[7:5])
							3'b000: tmpP[Flag_C] <= 1'b0;	//0x18(clc)
							3'b001: tmpP[Flag_C] <= 1'b1;	//0x38(sec)
							3'b010: tmpP[Flag_I] <= 1'b0;	//0x58(cli)
							3'b011: tmpP[Flag_I] <= 1'b1;	//0x78(sei)
							3'b101: tmpP[Flag_V] <= 1'b0;	//0xb8(clv)
							3'b110: tmpP[Flag_D] <= 1'b0;	//0xd8(cld)
							3'b111: tmpP[Flag_D] <= 1'b1;	//0xf8(sed)
							default: ;
						endcase // IR[7:5]
					end

					tmpP[Flag_B] <= 1'b1;
					if(IR == 8'h00 && MCycle == 3'b100 && !RstCycle)
					begin
						//This should happen after P has been pushed to stack
						tmpP[Flag_I] <= 1'b1;
					end
					if(RstCycle)
					begin
						tmpP[Flag_I] <= 1'b1;
						tmpP[Flag_D] <= 1'b0;
					end
					tmpP[Flag_1] <= 1'b1;

					P <= tmpP;	//new way (EL: of what?)

					if(IR[4:0] != 5'b10000 || Jump != 2'b01)
					begin
						IRQ_n_o <= IRQ_n;	// delay interrupts during branches (checked with Lorenz test and real 6510), not best way yet, though - but works...
					end
				end

				// detect nmi even if not rdy
				if(IR[4] != 5'b10000 || Jump != 2'b01)
				begin
					NMI_n_o <= NMI_n;	// delay interrupts during branches (checked with Lorenz test and real 6510) not best way yet, though - but works...
				end
			end
			// act immediately on SO pin change
			// The signal is sampled on the trailing edge of phi1 and must be externally synchronized (from datasheet)
			SO_n_o <= SO_n;
			if(SO_n_o && !SO_n)
				P[Flag_V] <= 1'b1;
		end
	end

//////////////////////////////////////////////////////////////////////////-
//
// Buses
//
//////////////////////////////////////////////////////////////////////////-

	always @(posedge Clk or negedge Res_n_i)
	begin
		if(~Res_n_i)
		begin
			BusA_r <= 8'h00;
			BusB <= 8'h00;
			BusB_r <= 8'h00;
			AD <= 8'h00;
			BAL <= 9'h000;
			BAH <= 8'h00;
			DL <= 8'h00;
		end
		else
		begin
			if(Enable)
			begin
				NMI_entered <= 1'b0;
				if(really_rdy)
				begin
					BusA_r <= BusA;
					BusB <= DI;

					// not really nice, but no better way found yet !
					if(Set_Addr_To_r == Set_Addr_To_PBR || Set_Addr_To_r == Set_Addr_To_ZPG)
						BusB_r <= DI[7:0] + 8'h01;	// required for SHA

					case(BAAdd)
						2'b01:
						begin
							// BA inc
							AD <= AD + 8'h01;
							BAL <= BAL + 8'h01;
						end
						2'b10:
						begin
							// BA Add
							BAL <= {1'b0, BAL[7:0]} + {1'b0, BusA};
						end
						2'b11:
						begin
							// BA Adj
							if(BAL[8])
								BAH <= BAH + 8'h01;
						end
						default: ;
					endcase // BAAdd

					// modified to use Y register as well
					if(ADAdd)
					begin
						if(AddY)
							AD <= AD + Y[7:0];
						else
							AD <= AD + X[7:0];
					end

					if(IR == 8'h00)
					begin
						BAL <= 9'h001;
						BAH <= 8'h01;
						if(RstCycle)
						begin
							BAL[2:0] <= 3'b100;
						end
						else if(NMICycle || (NMIAct && MCycle == 3'b100) || (NMI_entered))
						begin
							BAL[2:0] <= 3'b010;
							if(MCycle == 3'b100)
								NMI_entered <= 1'b1;
						end
						else
						begin
							BAL[2:0] <= 3'b110;
						end
						if(Set_Addr_To_r == Set_Addr_To_BA)
							BAL[0] <= 1'b1;
					end

					if(LDDI)
						DL <= DI;
					if(LDALU)
						DL <= ALU_Q;
					if(LDAD)
						AD <= DI;
					if(LDBAL)
						BAL[7:0] <= DI;
					if(LDBAH)
						BAH <= DI;
				end
			end
		end
	end

	always_comb
	begin
		Break = (BreakAtNA & ~BAL[8]) | (PCAdd & ~PCAdder[8]);

		case(Set_BusA_To)
			Set_BusA_To_DI: BusA = DI;
			Set_BusA_To_ABC: BusA = ABC[7:0];
			Set_BusA_To_X: BusA = X[7:0];
			Set_BusA_To_Y: BusA = Y[7:0];
			Set_BusA_To_S: BusA = S[7:0];
			Set_BusA_To_P: BusA = P;
			Set_BusA_To_DA: BusA = ABC[7:0] & DI;
			Set_BusA_To_DAO: BusA = (ABC[7:0] | 8'hEE) & DI;	//ee for OAL instruction. constant may be different on other platforms.TODO:Move to generics
			Set_BusA_To_DAX: BusA = (ABC[7:0] | 8'hEE) & DI & X[7:0];	//XAA, ee for OAL instruction. constant may be different on other platforms.TODO:Move to generics
			Set_BusA_To_AAX: BusA = ABC[7:0] & X[7:0];	//SAX, SHA
			Set_BusA_To_DONTCARE: BusA = 8'hxx;	//Can probably remove this
			default: BusA = 8'hxx;
		endcase

		case(Set_Addr_To_r)
			Set_Addr_To_SP: A = {16'h0001, S[7:0]};
			Set_Addr_To_ZPG: A = {DBR, 8'h00, AD};
			Set_Addr_To_BA: A = {8'h00, BAH, BAL[7:0]};
			Set_Addr_To_PBR: A = {PBR, PC[15:8], PCAdder[7:0]};
			default: A =  24'hxxxxxx;
		endcase // Set_Addr_To_r

		// This is the P that gets pushed on stack with correct B flag. I'm not sure if NMI also clears B, but I guess it does.
		PwithB = (IRQCycle | NMICycle) ? (P & 8'hEF) : P;

		case(Write_Data_r)
			Write_Data_DL: DO = DL;
			Write_Data_ABC: DO = ABC[7:0];
			Write_Data_X: DO = X[7:0];
			Write_Data_Y: DO = Y[7:0];
			Write_Data_S: DO = S[7:0];
			Write_Data_P: DO = PwithB;
			Write_Data_PCL: DO = PC[7:0];
			Write_Data_PCH: DO = PC[15:8];
			Write_Data_AX: DO = ABC[7:0] & X[7:0];
			Write_Data_AXB: DO = ABC[7:0] & X[7:0] & BusB_r[7:0];	// no better way found yet...
			Write_Data_XB: DO = X[7:0] & BusB_r[7:0];	// no better way found yet...
			Write_Data_YB: DO = Y[7:0] & BusB_r[7:0];	// no better way found yet...
			Write_Data_DONTCARE: DO = 8'hxx;	//Can probably remove this
			default:  DO = 8'hxx;
		endcase // Write_Data_r
	end

////////////////////////////////////////////////////////////////////////-
//
// Main state machine
//
////////////////////////////////////////////////////////////////////////-

	always @(posedge Clk or negedge Res_n_i)
	begin
		if(~Res_n_i)
		begin
			MCycle <= 3'b001;
			RstCycle <= 1'b1;
			IRQCycle <= 1'b0;
			NMICycle <= 1'b0;
			NMIAct <= 1'b0;
		end
		else
		begin
			if(Enable)
			begin
				if(really_rdy)
				begin
					if(MCycle == LCycle || Break)
					begin
						MCycle <= 3'b000;
						RstCycle <= 1'b0;
						IRQCycle <= 1'b0;
						NMICycle <= 1'b0;
						if(NMIAct && IR != 2'b00)	// delay NMI further if we just executed a BRK
						begin
							NMICycle <= 1'b1;
							NMIAct <= 1'b0;	// reset NMI edge detector if we start processing the NMI
						end
						else if(~IRQ_n_o & ~P[Flag_I])
						begin
							IRQCycle <= 1'b1;
						end
					end
					else
					begin
						MCycle <= MCycle + 3'b001;
					end
				end

				//detect NMI even if not rdy
				if(NMI_n_o && (!NMI_n && (IR[4:0] != 5'b10000 || Jump != 2'b01)))// branches have influence on NMI start (not best way yet, though - but works...)
					NMIAct <= 1'b1;
				// we entered NMI during BRK instruction
				if(NMI_entered)
					NMIAct <= 1'b0;
			end
		end
	end
endmodule //T65
