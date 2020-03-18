// DESIGN SPECIFIC
`define ALU_BUS_WITH 		16
`define ALU_AMM_ADDR_WITH 	8
`define ALU_AMM_DATA_WITH	8  

`define RESET         		 0
`define IDLE					 2
`define FETCH_DATA    		 4
`define PROCESARE				 6 
`define OPERATII	          8
`define AFISARE		       10


`define ADD 'h0
`define AND 'h1
`define OR  'h2
`define XOR 'h3
`define NOT 'h4
`define INC 'h5
`define DEC 'h6 
`define NEG 'h7
`define SHR 'h8
`define SHL 'h9
/**

== Input packets ==

Header beat
+-----------------+--------------+---------------+------------------+
| reserved[15:12] | opcode[11:8] | reserved[7:6] | nof_operands[5:0]|
+-----------------+--------------+---------------+------------------+

Payload beat
+-----------------+----------+----------------------+
| reserved[15:10] | mod[9:8] | operands/address[7:0]|
+-----------------+----------+----------------------+

== Output packets ==

Header beat

+----------------+----------+-------------+
| reserved[15:5] | error[4] | opcode[3:0] |
+----------------+----------+-------------+

Payload beat

+-----------------+--------------+
| reserved[15:12] | result[11:0] |
+-----------------+--------------+

*/

module alu(
	 // Output interface
    output[`ALU_BUS_WITH - 1:0] data_out,
	 output 							  valid_out,
	 output 							  cmd_out,

	 //Input interface
	 input [`ALU_BUS_WITH - 1:0] data_in,
	 input 							  valid_in,
	 input 							  cmd_in,
	 
	 // AMM interface
	 output 									 amm_read,
	 output[`ALU_AMM_ADDR_WITH - 1:0] amm_address,
	 input [`ALU_AMM_DATA_WITH - 1:0] amm_readdata,
	 input 									 amm_waitrequest,
	 input[1:0] 							 amm_response,
	 
	 
	 //clock and reset interface
	 input clk,
	 input rst_n
    );
	
	// TODO: Implement Not-so-simple ALU
	//memorie
	reg amm_read_reg = 0;
	reg[`ALU_AMM_ADDR_WITH - 1:0] amm_address_reg = 0;
	
	reg[3:0] opcode=0;
	reg[1:0] mod[62:0];  //vector pentru nr de moduri ale fiecarui operatii
	reg error = 0;
	reg[11:0] result = 0;
	reg[11:0] resultNext = 0;
	reg[`ALU_BUS_WITH - 1:0] data_out_reg = 0;

	
	reg[7:0] operands[62:0]; //vector cu nr maxim de operanzi
	reg[7:0] nr_Operands = 0;
	reg[7:0] operand_in = 0;
	reg[7:0] operand_in_next = 0;
	reg[7:0] operand_proc = 0;
	reg[7:0] operand_proc_next = 0;
	reg[7:0] operand_cal = 0;
	reg[7:0] operand_cal_next = 0;
	
	reg valid_out_reg = 0;
	reg cmd_out_reg = 0;
	reg[7:0] i = 0;
	
	//stari
	reg[3:0] state = `RESET;
	reg[3:0] next_state = `RESET;
	
	//initializez fiecare mod si operand cu 0
	initial begin
		for(i = 0; i < 63; i = i + 1) begin
			mod[i] = 0;
			operands[i] = 0;
		
		end
		
	end
	
	always @ (posedge clk)
	begin
		if(rst_n == 0)
			state <= `RESET;
			
		state <= next_state;
		result <= resultNext;
		operand_in <= operand_in_next;
		operand_proc <= operand_proc_next;
		operand_cal <= operand_cal_next;
		
	end
	
	always @(*)
	begin
	
	amm_read_reg = 0;
	amm_address_reg = 0;
	
	data_out_reg = 0;
	cmd_out_reg = 0;
	valid_out_reg = 0;
	
	case(state)
	
		`RESET: begin
			resultNext = 0;
			error = 0;
			opcode = 0;
			nr_Operands = 0;
			operand_in_next = 0;
			operand_proc_next = 0;
			operand_cal_next = 0;	
			
			for(i = 0; i < 63; i = i + 1) begin
				mod[i] = 0;
				operands[i] = 0;
		
			end
			
			next_state = `IDLE;
			
		end
		
		//incarcarea headerului
		`IDLE: begin
			if(valid_in == 1 && cmd_in == 1) begin
					opcode = data_in[11:8];
					nr_Operands = data_in[5:0];
					
					
					//tratam eventualele erori care vin de la operatii in fct de nr de operanzi
					if(nr_Operands == 0 					 ||
					(opcode== 4 && nr_Operands != 1)  ||
					(opcode == 5 && nr_Operands != 1) ||
					(opcode == 6 && nr_Operands != 1) ||
					(opcode == 7 && nr_Operands != 1) ||
					(opcode == 8 && nr_Operands != 2) ||
					(opcode == 9 && nr_Operands != 2)) 
					begin  
						error = 1;
						next_state = `AFISARE;
						
					end
					else begin
						next_state = `FETCH_DATA;
						
					end
					
			end
			else begin
				next_state = `IDLE;
				
			end
			
		end
		
		//incarcarea payloadului
		`FETCH_DATA: begin
			if(valid_in == 1) begin
					mod[operand_in_next] = data_in[9:8];
					operands[operand_in_next] = data_in[7:0];
					operand_in_next = operand_in + 1;
					
					next_state = `FETCH_DATA;
					
			end
			else if(operand_in == nr_Operands) begin 
				next_state = `PROCESARE; 
				
			end
			else begin
				next_state = `FETCH_DATA;
				
			end
			
		end
		
		//verificarea modului de adresare: imediata/indirecta
		`PROCESARE: begin
			if(operand_proc == nr_Operands) begin
				next_state = `OPERATII;
				
			end
			else begin
				if(mod[operand_proc] == 2'b01) begin
					amm_read_reg = 1;
					amm_address_reg = operands[operand_proc];
					
					next_state = `PROCESARE + 1;
					
				end
				else begin
					operand_proc_next = operand_proc + 1;
					
					next_state = `PROCESARE;
					
				end
				
			end
			
		end
		
		//procesare pentru modul indirect
		`PROCESARE + 1: begin
			if(amm_waitrequest == 0 && amm_response == 2'b00) begin
				operands[operand_proc] = amm_readdata;
				
				operand_proc_next = operand_proc + 1;
				next_state = `PROCESARE;
				
			end
			else if(amm_waitrequest == 0 && amm_response != 2'b00) begin 
				error = 1; 
				next_state = `AFISARE;
				
			end
			else begin
				amm_read_reg = 1;
				amm_address_reg = operands[operand_proc];
				
				next_state = `PROCESARE + 1;
				
			end
		
		end	
		
		
		//realizarea tuturor operatiilor
		`OPERATII: begin
			if(operand_cal == nr_Operands) begin
				next_state = `AFISARE;
				
			end
			else begin
				case(opcode)
					`ADD: begin
						resultNext = result + operands[operand_cal];
						operand_cal_next = operand_cal + 1;
						
						next_state = `OPERATII;
					
					end
					
					`AND: begin
						if(operand_cal == 0) begin
							resultNext[7:0] = operands[0];
							
							operand_cal_next = 1;
							
						end
						else begin
							resultNext[7:0] = result[7:0] & operands[operand_cal];
							
							operand_cal_next = operand_cal + 1;
						
						end
						
						next_state = `OPERATII;
						
					end
					
					`OR: begin
						resultNext[7:0] = result[7:0] | operands[operand_cal];
						operand_cal_next = operand_cal + 1;
						
						next_state = `OPERATII;
						
					end
					
					`XOR: begin
						resultNext[7:0] = result[7:0] ^ operands[operand_cal];
						operand_cal_next = operand_cal + 1;
						
						next_state = `OPERATII;
						
					end
					
					`NOT: begin						
						resultNext[7:0] = ~operands[operand_cal];
						
						operand_cal_next = operand_cal + 1;
						
					end
					
					`INC: begin						
						resultNext[7:0] = operands[operand_cal] + 1;
						
						operand_cal_next = operand_cal + 1;
						
					end
					
					`DEC: begin						
						resultNext[7:0] = operands[operand_cal] - 1;
						
						operand_cal_next = operand_cal + 1;
						
					end
					
					`NEG: begin						
						resultNext[7:0] = -operands[operand_cal];
						
						operand_cal_next = operand_cal + 1;
						
					end
					
					`SHR: begin						
						resultNext[7:0] = operands[operand_cal] >> operands[operand_cal + 1];
						
						operand_cal_next = operand_cal + 2;
						
					end
					
					`SHL: begin					
						resultNext[7:0] = operands[operand_cal] << operands[operand_cal + 1];
						
						operand_cal_next = operand_cal + 2;
						
					end
			
			endcase
			
			end
		
		end
		
		//afisare header
		`AFISARE: begin
			valid_out_reg = 1;
			cmd_out_reg = 1;
			
			data_out_reg = {11'b0, error, opcode};
			
			next_state = `AFISARE + 1;
		
		end
		
		
		//afisare payload
		`AFISARE + 1: begin
			valid_out_reg = 1;
			
			if(error) begin
				data_out_reg = {4'b0, 12'hBAD};
				
			end
			else begin
				data_out_reg = {4'b0, result};
				
			end
			
			next_state = `RESET;
			
		end
	
	endcase
	
	end
	
	assign amm_read = amm_read_reg;
	assign amm_address = amm_address_reg;
	
	assign data_out = data_out_reg;
	assign valid_out = valid_out_reg;
	assign cmd_out = cmd_out_reg;
	
endmodule
