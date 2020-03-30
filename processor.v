`include "ALU.v"
`include "PC.v"
`include "data-memory.v"
`include "instruction-memory.v"
`include "internal-registers.v"
`include "clock.v"

module processor (output[7:0] pc, output[15:0] resultALU, output reg[3:0] SREG);
	wire[5:0] opcode;
	reg[2:0] state, regNum;
	reg[7:0] immediateValue;
    wire clk;
    integer i;

	assign pc = pcCurrent;
	assign resultALU = {mulHighALU, resultALULow};

	assign opcode = instruction[15:10];

	//PC
	wire[7:0] pcNext;
	reg[7:0] pcCurrent, jumpLine;
	reg jump, hold;

	//GPR
	wire[7:0] regAData, regBData;
	reg[7:0] regCIn, mulHighIn;
	reg[2:0] regANum, regBNum, regCNum;
	reg readEn, writeEn;

	//ALU
	wire[7:0] mulHighALU, resultALULow;
	wire[3:0] aluSREG;
	reg[7:0] operandA, operandB;
	reg[3:0] aluFSL;

	//Instruction Memory
	wire[15:0] instruction;

	//Data Memory
	wire[7:0] memOut;
	reg[7:0] memIn;
	reg[6:0] lineNumber;
	reg memRead, memWrite;

	dataMemory dMEM (memOut, memIn, lineNumber, memRead, memWrite, clk);
	instructionMemory iMEM (instruction, pcCurrent);
	ALU alu (mulHighALU, resultALULow, aluSREG, operandA, operandB, aluFSL);
	GPRs registerFile (regAData, regBData, readEn, writeEn, regCIn, mulHighIn, regANum, regBNum, regCNum, clk);
	PC programCounter (pcNext, pcCurrent, jumpLine, jump, hold, clk);
    clock clkModule (clk);

	initial begin
		memRead=0;
		memWrite=0;
		lineNumber=0;
		readEn=0;
		writeEn=0;
		jump=0;
		hold=0;
		state=0;
        $dumpfile("processor.vcd");
        $dumpvars(0, processor);
        for (i=0;i<8;i=i+1) begin
            $dumpvars(0, processor.registerFile.GPR[i]);
        end
        #1000 $finish;
	end


	always @ (posedge clk) begin
		case(opcode[5:4])
			2'b00:  begin //ALU
				regANum = instruction[9:7];
				regBNum = instruction[6:4];
				regCNum = instruction[3:1];
				aluFSL = opcode[3:0];
				case(state)
					3'b000: begin      //read both operands from instruction
						hold=1;
						readEn=1;
						writeEn=0;
						state=state+1;
					end
					3'b001: begin      //set up ALU parameters
						readEn=0;
						operandA=regAData;
						operandB=regBData;
						state=state+1;
					end
					3'b010: begin      //allow ALU to process
						regCIn=resultALULow;
						mulHighIn=mulHighALU;
						state=state+1;
					end
					3'b011: begin        //write result to register
						writeEn=1;
						state=state+1;
					end
					3'b100: begin       //update flags
						writeEn=0;
						SREG=aluSREG;
						state=state+1;
					end
					3'b101: begin        //latency
						state=0;
						hold=0;
					end
					default: state=0;
				endcase
			end
			2'b01:  begin //Load - immediate, direct, indirect || Store
				case(opcode[3:2])
					2'b00: begin //immediate
						regCIn = instruction[10:3]; //can load from 0-255
						regCNum = instruction[2:0];
						case(state)
							3'b000: begin	//setup value to be loaded
								writeEn=0;
								readEn=0;
								hold=1;
								state=state+1;
							end
							3'b001: begin	//enable write to reg
								writeEn=1;
								state=state+1;
							end
							3'b010: begin	//disable write
								writeEn=0;
								state=state+1;
							end
							3'b011: begin	//latency
								state=0;
								hold=0;
							end
							default: state=0;
						endcase
					end
					2'b01: begin //direct
						regCNum = instruction[9:7];
						regANum = instruction[6:4];
						case(state)
							3'b000: begin	//setup
								writeEn=0;
								readEn=0;
								hold=1;
								state=state+1;
							end
							3'b001: begin
								readEn=1;
								state=state+1;
							end
							3'b010: begin
								regCIn=regAData;
								readEn=0;
								state=state+1;
							end
							3'b011: begin
								writeEn=1;
								state=state+1;
							end
							3'b100: begin
								writeEn=0;
								state=state+1;
							end
							3'b101: begin
								hold=0;
								state=0;
							end
							default: state=0;
						endcase
					end
					2'b10: begin //indirect
						regBNum = instruction[9:7];
						regCNum = instruction[6:4];
						case(state)
							3'b000: begin
								hold=1;
								writeEn=0;
								readEn=0;
								state=state+1;
							end
							3'b001: begin
								readEn=1;
								state=state+1;
							end
							3'b010: begin
								readEn=0;
								lineNumber=regBData[6:0];
								memRead=0;
								state=state+1;
							end
							3'b011: begin
								memRead=1;
								state=state+1;
							end
							3'b100: begin
								regCIn=memOut;
								memRead=0;
								state=state+1;
							end
							3'b101: begin
								writeEn=1;
								state=state+1;
							end
							3'b110: begin
								writeEn=0;
								state=state+1;
							end
							3'b111: begin
								hold=0;
								state=0;
							end
							default: state=0;
						endcase
					end
					2'b11: begin //store
						lineNumber=instruction[9:3];
						regANum=instruction[2:0];
						case(state)
							3'b000: begin
								writeEn=0;
								readEn=0;
								hold=1;
								memRead=0;
								memWrite=0;
								state=state+1;
							end
							3'b001: begin
								readEn=1;
								state=state+1;
							end
							3'b010: begin
								readEn=0;
								memIn=regAData;
								state=state+1;
							end
							3'b011: begin
								memWrite=1;
								state=state+1;
							end
							3'b100: begin
								memWrite=0;
								state=state+1;
							end
							3'b101: begin
								hold=0;
								state=0;
							end
							default: state=0;
						endcase
					end
				endcase
			end
			2'b10:  begin //Branch Instructions
			end
			2'b11:  begin //MOV
                memRead=0;
                memWrite=0;
                case(state)
                    3'b000: begin
                        hold=1;
                        lineNumber=instruction[13:7];
                        state=state+1;
                    end
                    3'b001: begin
                        memRead=1;
                        state=state+1;
                    end
                    3'b010: begin
                        memRead=0;
                        memIn=memOut;
                        state=state+1;
                    end
                    3'b011: begin
                        lineNumber=instruction[6:0];
                        state=state+1;
                    end
                    3'b100: begin
                        memWrite=1;
                        state=state+1;
                    end
                    3'b101: begin
                        memWrite=0;
                        state=state+1;
                    end
                    3'b110: begin
                        hold=0;
                        state=0;
                    end
                    default: state=0;
                endcase
			end
		endcase
		pcCurrent <= pcNext;
	end
endmodule