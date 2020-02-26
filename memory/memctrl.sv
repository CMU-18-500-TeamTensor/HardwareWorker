`default_nettype none


module MemController
  (input  logic [3:0] KEY,
   input  logic CLOCK_50,
	output logic DRAM_CLK, DRAM_CKE, DRAM_CAS_N, DRAM_CS_N, DRAM_LDQM, DRAM_UDQM, DRAM_RAS_N, DRAM_WE_N,
	output logic [12:0] DRAM_ADDR,
	output logic [1:0]  DRAM_BA,
	inout  logic [15:0] DRAM_DQ,
	output logic ready,
	input logic [9:0] SW,
   output logic [9:0] LEDR,
   output logic [6:0] HEX0, HEX1, HEX2, HEX3);
	
  logic [31:0] COUNTER;
	
  logic reset_n, clock;
  assign reset_n = KEY[3];
  assign clock = DRAM_CLK;
	
  // Instantiate fast cl0x
  logic peripheral_clock, cpu_clock, pll_locked;
  clkgenerator clkgenInst(
    .rst(~reset_n),
    .refclk(CLOCK_50), 
    .outclk_0(DRAM_CLK),
    .outclk_1(peripheral_clock),
    .outclk_2(cpu_clock),
    .locked(pll_locked)
  );
  
  
  
  // Tri-state driver logic for the DQ wires
  logic [15:0] dq;
  logic dq_write;
  assign DRAM_DQ = (dq_write) ? dq : 16'bzzzzzzzzzzzzzzzz;
  
  logic init_go;
  logic init_done;
  logic init_DRAM_CLK, init_DRAM_CKE, init_DRAM_CAS_N, init_DRAM_CS_N, init_DRAM_LDQM, init_DRAM_UDQM, init_DRAM_RAS_N, init_DRAM_WE_N;
  logic [12:0] init_DRAM_ADDR; 
  logic [1:0]  init_DRAM_BA;
  
  InitializerFSM initfsm(.*);
  
  
  // Naive Read FSM (Naive works fine for prelab)
  logic read_go;
  logic [21:0] read_addr;
  logic read_done;
  logic read_DRAM_CLK, read_DRAM_CKE, read_DRAM_CAS_N, read_DRAM_CS_N, read_DRAM_LDQM, read_DRAM_UDQM, read_DRAM_RAS_N, read_DRAM_WE_N;
  logic [12:0] read_DRAM_ADDR;
  logic [1:0]  read_DRAM_BA;
  logic [15:0] read_DRAM_DQ;
  assign read_DRAM_DQ = DRAM_DQ;
  logic [15:0] read_data;
  
  NaiveReadFSM naivereadfsm(.*);
  
  // Naive Write FSM (Naive works fine for prelab)
  logic write_go;
  logic [21:0] write_addr;
  logic write_done, write_en;
  logic write_DRAM_CLK, write_DRAM_CKE, write_DRAM_CAS_N, write_DRAM_CS_N, write_DRAM_LDQM, write_DRAM_UDQM, write_DRAM_RAS_N, write_DRAM_WE_N;
  logic [12:0] write_DRAM_ADDR; 
  logic [1:0]  write_DRAM_BA;
  logic [15:0] write_DRAM_DQ;
  assign dq = write_DRAM_DQ;
  assign dq_write = write_en;
  logic [15:0] write_data;
	
  NaiveWriteFSM naivewritefsm(.*);
  
  
  
  // Wire up the testbench
  logic [21:0] addr_out;
  logic [15:0] data_out;
  logic we_out, re_out;
  logic [15:0] data_in;
  logic data_in_valid;
  logic phase_ready;
  logic done;
  logic phase0_start, phase1_start, phase2_start, phase3_start;
  logic [6:0] HEX0_D, HEX1_D, HEX2_D, HEX3_D;
  assign HEX0 = HEX0_D;
  assign HEX1 = HEX1_D;
  assign HEX2 = HEX2_D;
  assign HEX3 = HEX3_D;
  
  SDRAM_if_tb tb(.*);

  enum logic [15:0] {UNINIT, INITIALIZING, READY, READING, WRITING} state, nextState;

  logic [31:0] cycle_counter, counter;

  // NextState logic
  always_comb begin
    case(state)
	   UNINIT: begin
	     nextState = (pll_locked) ? INITIALIZING : UNINIT;
		end
		INITIALIZING: begin
	     nextState = (init_done) ? READY : INITIALIZING;
		end
		READY: begin
	     nextState = (re_out) ? READING : ((we_out) ? WRITING : READY);
		end
		READING: begin
		  nextState = (read_done) ? READY : READING;
		end
		WRITING: begin
	     nextState = (write_done) ? READY : WRITING;
		end
	 endcase
  end
  
  // Internal Combinational logic
  always_comb begin
    write_go = 0;
	 read_go = 0;
	 init_go = 0;
	 phase_ready = 0;
	 data_in = 16'd0;
	 data_in_valid = 0;
	 case(state)
	   UNINIT: begin
	     init_go = (nextState == INITIALIZING) ? 1 : 0;
		end
		INITIALIZING: begin
	     // Hecka hacky, but the idea is that we activate go for >=1 cc, and it isn't
		  // active when done is active, because at that point the FSM is in the START
		  // state and ready to go into another loop
	     init_go = 0;
		end
		READY: begin
		  phase_ready = 1;
		end
		READING: begin
		  // Hecka hacky, but the idea is that we activate go for >=1 cc, and it isn't
		  // active when done is active, because at that point the FSM is in the START
		  // state and ready to go into another loop
	     read_go = ~read_done;
		  
		  if(read_done) begin
			 data_in = read_data;
			 data_in_valid = 1;
		  end
		end
		WRITING: begin
	     // Hecka hacky, but the idea is that we activate go for >=1 cc, and it isn't
		  // active when done is active, because at that point the FSM is in the START
		  // state and ready to go into another loop
	     write_go = ~write_done;
		end
	 endcase
  end

  // DRAM output logic
  // Note that this is in an always_comb block, but it is still at the output of
  // a register because that's the way I wired up the outputs in the submodules.
  always_comb begin
    case(state)
	   UNINIT: begin
		  // Issue an invalid command
		  DRAM_CKE = 0;
		  
		  // Kind of like a NOP, but shouldn't be processed because the clock is
		  // not enabled.
		  DRAM_CAS_N <= 1;
		  DRAM_CS_N  <= 0;
		  DRAM_RAS_N <= 1;
		  DRAM_WE_N  <= 1;
		  DRAM_LDQM = 0;
		  DRAM_UDQM = 0;
		  DRAM_ADDR = 13'd0;
		  DRAM_BA = 2'd0;
		end
		INITIALIZING: begin
		  // Assign to DRAM_XXX the outputs of the respective
		  // submodule
        DRAM_CKE = init_DRAM_CKE;
		  DRAM_CAS_N = init_DRAM_CAS_N;
		  DRAM_CS_N = init_DRAM_CS_N;
		  DRAM_LDQM = init_DRAM_LDQM;
		  DRAM_UDQM = init_DRAM_UDQM;
		  DRAM_RAS_N = init_DRAM_RAS_N;
		  DRAM_WE_N = init_DRAM_WE_N;
		  DRAM_ADDR = init_DRAM_ADDR;
		  DRAM_BA = init_DRAM_BA;
		end
		READY: begin
		  // TODO: Issue a NOP command
		  DRAM_CAS_N <= 1;
		  DRAM_CS_N  <= 0;
		  DRAM_RAS_N <= 1;
		  DRAM_WE_N  <= 1;
		  DRAM_CKE = 1;
		  DRAM_LDQM = 0;
		  DRAM_UDQM = 0;
		  DRAM_ADDR = 13'd0;
		  DRAM_BA = 2'd0;
		end
		READING: begin
		  // Assign to DRAM_XXX the outputs of the respective
		  // submodule
		  
		  DRAM_CKE = read_DRAM_CKE;
		  DRAM_CAS_N = read_DRAM_CAS_N;
		  DRAM_CS_N = read_DRAM_CS_N;
		  DRAM_LDQM = read_DRAM_LDQM;
		  DRAM_UDQM = read_DRAM_UDQM;
		  DRAM_RAS_N = read_DRAM_RAS_N;
		  DRAM_WE_N = read_DRAM_WE_N;
		  DRAM_ADDR = read_DRAM_ADDR;
		  DRAM_BA = read_DRAM_BA;
		end
		WRITING: begin
		  // Assign to DRAM_XXX the outputs of the respective
		  // submodule
		  
		  DRAM_CKE = write_DRAM_CKE;
		  DRAM_CAS_N = write_DRAM_CAS_N;
		  DRAM_CS_N = write_DRAM_CS_N;
		  DRAM_LDQM = write_DRAM_LDQM;
		  DRAM_UDQM = write_DRAM_UDQM;
		  DRAM_RAS_N = write_DRAM_RAS_N;
		  DRAM_WE_N = write_DRAM_WE_N;
		  DRAM_ADDR = write_DRAM_ADDR;
		  DRAM_BA = write_DRAM_BA;
		end
	 endcase
  end
  
  // Procedural internal logic
  always_ff @(negedge reset_n, posedge DRAM_CLK) begin
    if(~reset_n) begin
      write_addr <= 22'd0;
		read_addr <= 22'd0;
		write_data <= 16'd0;
    end
    else begin
		case(state)
	     UNINIT: begin
	     
		  end
		  INITIALIZING: begin
	     
		  end
		  READY: begin
		    if(nextState == WRITING) begin
			   write_addr <= addr_out;
				write_data <= data_out;
		    end
			 if(nextState == READING) begin
			   read_addr <= addr_out;
			 end
		  end
		  READING: begin
		    
	  	  end
	 	  WRITING: begin
	       
		  end
	   endcase
    end
  end
  
  // FSM logic
  always_ff @(negedge reset_n, posedge DRAM_CLK) begin
    if(~reset_n) begin
      state <= UNINIT;
		COUNTER <= 0;
    end
    else begin
      state <= nextState;
		COUNTER <= COUNTER + 1;
    end
  end

endmodule: MemController

/*module MemController_test;

  logic clock, reset_n;

  logic [3:0] KEY;                                                                              // Input
  logic CLOCK_50;                                                                               // Input
  logic DRAM_CLK, DRAM_CKE, DRAM_CAS_N, DRAM_CS_N, DRAM_LDQM, DRAM_UDQM, DRAM_RAS_N, DRAM_WE_N; // Output
  logic [12:0] DRAM_ADDR;                                                                       // Output
  logic [1:0]  DRAM_BA;                                                                         // Output
  logic [15:0] DRAM_DQ;                                                                         // Inout
  logic ready;                                                                                  // Output
  logic [9:0] SW;                                                                               // Input
  logic [3:0] LEDG;                                                                             // Output
  logic [6:0] HEX0_D, HEX1_D, HEX2_D, HEX3_D;                                                   // Output

  MemController mc(.*);

  assign CLOCK_50 = clock;
  
  initial begin
    reset_n = 0;
	 reset_n <= #1 1;
	 clock = 0;
	 
	 forever #5 clock = ~clock;
  end
  
  initial begin
    int i;
	 SW = 10'd0;
	 
	 for(i = 0; i < 1000; i = i + 1) @(posedge clock);
	 
	 $finish;
  end
	
endmodule: MemController_test*/



module InitializerFSM
  (input logic clock, reset_n, init_go,
   output logic init_done,
	output logic init_DRAM_CLK, init_DRAM_CKE, init_DRAM_CAS_N, init_DRAM_CS_N, init_DRAM_LDQM, init_DRAM_UDQM, init_DRAM_RAS_N, init_DRAM_WE_N,
	output logic [12:0] init_DRAM_ADDR, 
	output logic [1:0]  init_DRAM_BA);

  enum logic [15:0] {START, GO, WAIT_NOP, PRECHARGE, WAIT_tRP, AUTO_REFRESH, AUTO_REFRESH_NOP, MRSC, MRSC_NOP, DONE} state, nextState;
  
  logic [31:0] counter, cycleCounter;
  
  // NextState logic
  always_comb begin
    case(state)
		START: begin
		  nextState = (init_go) ? GO : START;
		end
		GO: begin
		  nextState = WAIT_NOP;
		end
		WAIT_NOP: begin
		  nextState = (cycleCounter == 32'd10000) ? PRECHARGE : WAIT_NOP;
		end
		PRECHARGE: begin
		  nextState = WAIT_tRP;
		end
		WAIT_tRP: begin
		  nextState = (cycleCounter == 32'd1) ? AUTO_REFRESH : WAIT_tRP;
		end
		AUTO_REFRESH: begin
		  nextState = AUTO_REFRESH_NOP;
		end
		AUTO_REFRESH_NOP: begin
		  nextState = (cycleCounter == 32'd7) ? ((counter == 32'd8) ? MRSC : AUTO_REFRESH) : AUTO_REFRESH_NOP;
		end
		MRSC: begin
		  nextState = MRSC_NOP;
		end
		MRSC_NOP: begin
		  nextState = DONE;
		end
		DONE: begin
		  nextState = START;
		end
	 endcase
  end

  // Procedural Output/Counter Logic
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
	   cycleCounter <= 0;
		init_done <= 0;
	 end
	 else begin
		init_DRAM_LDQM <= 0;
		init_DRAM_UDQM <= 0;
		init_DRAM_CKE <= 1;
		case(state)
		  START: begin
			 init_done <= 0;
			 init_DRAM_CKE <= 0;
		  end
		  GO: begin
			  init_DRAM_CKE <= 1;
			  cycleCounter <= 32'd0;
			end
			WAIT_NOP: begin
			  cycleCounter <= (cycleCounter + 32'd1);
			  init_DRAM_CAS_N <= 1;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 1;
			  init_DRAM_WE_N  <= 1;
			end
			PRECHARGE: begin
			  init_DRAM_CAS_N <= 1;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 0;
			  init_DRAM_WE_N  <= 0;
			  init_DRAM_ADDR[10] <= 1;
			  cycleCounter <= 32'd0; // We will be sending NOP for next 
			end
			WAIT_tRP: begin
			  cycleCounter <= cycleCounter + 1;
			  counter <= 0;
			  init_DRAM_CAS_N <= 1;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 1;
			  init_DRAM_WE_N  <= 1;
			end
			AUTO_REFRESH: begin
			  cycleCounter <= 0;
			  counter <= counter + 1;
			  init_DRAM_CAS_N <= 0;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 0;
			  init_DRAM_WE_N  <= 1;
			end
			AUTO_REFRESH_NOP: begin
			  cycleCounter <= cycleCounter + 1;
			  init_DRAM_CAS_N <= 1;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 1;
			  init_DRAM_WE_N  <= 1;
			end
			MRSC: begin
			  init_DRAM_CAS_N <= 0;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 0;
			  init_DRAM_WE_N  <= 0;
			  {init_DRAM_BA, init_DRAM_ADDR} <= 15'b000000000100000;
			end
			MRSC_NOP: begin
			  init_DRAM_CAS_N <= 1;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 1;
			  init_DRAM_WE_N  <= 1;
			end
			DONE: begin
			  init_DRAM_CAS_N <= 1;
			  init_DRAM_CS_N  <= 0;
			  init_DRAM_RAS_N <= 1;
			  init_DRAM_WE_N  <= 1;
			  init_done <= 1;
			end
		 endcase
	 end
  end
  
  // FSM logic
  always_ff @(negedge reset_n, posedge clock) begin
    if(~reset_n) begin
      state <= START;
    end
    else begin
      state <= nextState;
    end
  end
  
endmodule: InitializerFSM

/*module InitializerFSM_test;

  logic clock, reset_n, init_go;
  logic init_done;
  logic init_DRAM_CLK, init_DRAM_CKE, init_DRAM_CAS_N, init_DRAM_CS_N, init_DRAM_LDQM, init_DRAM_UDQM, init_DRAM_RAS_N, init_DRAM_WE_N;
  logic [12:0] init_DRAM_ADDR;
  logic [1:0]  init_DRAM_BA;

  InitializerFSM initfsm(.*);
  
  initial begin
    reset_n <= 0;
	 reset_n <= #1 1;
	 clock <= 0;
	 
	 forever #5 clock <= ~clock;
  end
  
  initial begin
    init_go = 0;
	 @(posedge clock);
	 @(posedge clock);
	 @(posedge clock);
  
    init_go <= 1;
	 @(posedge clock);
	 init_go <= 0;
	 
	 @(posedge init_done);
	 @(posedge clock);
	 @(posedge clock);
	 @(posedge clock);
	 $finish;
  end

endmodule: InitializerFSM_test*/

// Called a "naive" read FSM because it will actiate one row, read one column for it, precharge the bank, and exit.
// This is an easy FSM with deterministic behavior. Hence the state cascade.
module NaiveReadFSM
  (input logic clock, reset_n, read_go,
   input  logic [21:0] read_addr,
   output logic read_done,
	output logic read_DRAM_CLK, read_DRAM_CKE, read_DRAM_CAS_N, read_DRAM_CS_N, read_DRAM_LDQM, read_DRAM_UDQM, read_DRAM_RAS_N, read_DRAM_WE_N,
	output logic [12:0] read_DRAM_ADDR, 
	output logic [1:0]  read_DRAM_BA,
	input  logic [15:0] read_DRAM_DQ,
	output logic [15:0] read_data);
  
  enum logic [15:0] {START, ACTIVATE, ACT_NOP, READ, R_NOP1, R_NOP2, PRECHARGE, PRE_NOP1, PRE_NOP2, DONE} state, nextState;
  
  // Variables to store the row and column addresses, since we can't assume they'll be on
  // the addr input for the entire execution period 
  logic [11:0] row_addr;
  logic [9:0]  col_addr;
  
  // Next State logic
  always_comb begin
    case(state)
	   START:     nextState = (read_go) ? ACTIVATE : START;
		ACTIVATE:  nextState = ACT_NOP;
		ACT_NOP:   nextState = READ;
		READ:      nextState = R_NOP1;
		R_NOP1:    nextState = R_NOP2;
		R_NOP2:    nextState = PRECHARGE;
		PRECHARGE: nextState = PRE_NOP1;
		PRE_NOP1:  nextState = PRE_NOP2;
		PRE_NOP2:  nextState = DONE;
		DONE:      nextState = START;
	 endcase
  end
  
  // Procedural Output logic
  always_ff @(negedge reset_n, posedge clock) begin
    if(~reset_n) begin
	   read_DRAM_BA <= 2'b00;
	   read_DRAM_LDQM <= 0;
	   read_DRAM_UDQM <= 0;
	   read_DRAM_CKE <= 1;
		read_data <= 16'd0;
	 end
	 else begin
    read_DRAM_BA <= 2'b00;
	 read_DRAM_LDQM <= 0;
	 read_DRAM_UDQM <= 0;
	 read_DRAM_CKE <= 1;
	 case(state)
	   START: begin
		  read_done <= 0;
		  read_data <= 16'd0;
		  // Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		  
		  // Special case: we need to nab the row and column in this state
		  {row_addr, col_addr} <= read_addr;
		end
		ACTIVATE: begin
		  // Output a Bank Activate op
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 0;
		  read_DRAM_WE_N  <= 1;
		  
		  // Output the row as the address
		  read_DRAM_ADDR <= {1'b0, row_addr};
		end
		ACT_NOP: begin
		  // Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		end
		READ: begin
		  // Output a READ command
		  read_DRAM_CAS_N <= 0;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  
		  // Output the column as the address
		  read_DRAM_ADDR <= {3'b000, col_addr};
		end
		R_NOP1: begin
		  // Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		end
		R_NOP2: begin
		  // Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		  
		  
		end
		PRECHARGE: begin
		  // Output a PRECHARGE command
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 0;
		  read_DRAM_WE_N  <= 0;
		  // Addr is a "Don't Care"
		  // Bank is already set to correct value
		  
		  // Data has arrived at DRAM_DQ -- load it into a register
		  read_data <= read_DRAM_DQ;
		end
		PRE_NOP1: begin
		  // Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		end
		PRE_NOP2: begin
		  // Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		  
		end
		DONE: begin
		// Output a NOP
		  read_DRAM_CAS_N <= 1;
		  read_DRAM_CS_N  <= 0;
		  read_DRAM_RAS_N <= 1;
		  read_DRAM_WE_N  <= 1;
		  // Addr is a "Don't Care"
		  
		  read_done <= 1;
		end
	 endcase
	 end
  end
  
  
  
  // FSM logic
  always_ff @(negedge reset_n, posedge clock) begin
    if(~reset_n) begin
	   state <= START;
	 end
	 else begin
	   state <= nextState;
	 end
  end
  
endmodule: NaiveReadFSM

/*module NaiveReadFSM_test;

  logic clock, reset_n, read_go;
  logic read_done;
  logic [21:0] read_addr;
  logic read_DRAM_CLK, read_DRAM_CKE, read_DRAM_CAS_N, read_DRAM_CS_N, read_DRAM_LDQM, read_DRAM_UDQM, read_DRAM_RAS_N, read_DRAM_WE_N;
  logic [12:0] read_DRAM_ADDR;
  logic [1:0]  read_DRAM_BA;

  NaiveReadFSM naivereadfsm(.*);
  
  initial begin
    reset_n <= 0;
	 reset_n <= #1 1;
	 clock <= 0;
	 
	 forever #5 clock <= ~clock;
  end
  
  initial begin
    read_go = 0;
	 read_addr <= 22'b1101010101010101010101;
	 @(posedge clock);
	 @(posedge clock);
	 @(posedge clock);
  
    read_go <= 1;
	 @(posedge clock);
	 read_go <= 0;
	 
	 @(posedge read_done);
	 @(posedge clock);
	 @(posedge clock);
	 @(posedge clock);
	 $finish;
  end

endmodule: NaiveReadFSM_test*/

// Called a "naive" write FSM because it will activate one row, write one column to it, precharge the bank, and exit.
// This is an easy FSM with deterministic behavior. Hence the state cascade.
module NaiveWriteFSM
  (input logic clock, reset_n, write_go,
   input  logic [21:0] write_addr,
   output logic write_done, write_en,
	output logic write_DRAM_CLK, write_DRAM_CKE, write_DRAM_CAS_N, write_DRAM_CS_N, write_DRAM_LDQM, write_DRAM_UDQM, write_DRAM_RAS_N, write_DRAM_WE_N,
	output logic [12:0] write_DRAM_ADDR, 
	output logic [1:0]  write_DRAM_BA,
	output logic [15:0] write_DRAM_DQ,
	input  logic [15:0] write_data);
  
  enum logic [15:0] {START, ACTIVATE, ACT_NOP, WRITE, WRITE_NOP, PRECHARGE, PRE_NOP1, PRE_NOP2, DONE} state, nextState;
  
  // Variables to store the row and column addresses, since we can't assume they'll be on
  // the addr input for the entire execution period 
  logic [11:0] row_addr;
  logic [9:0]  col_addr;
  
  // Next State logic
  always_comb begin
    case(state)
	   START:     nextState = (write_go) ? ACTIVATE : START;
		ACTIVATE:  nextState = ACT_NOP;
		ACT_NOP:   nextState = WRITE;
		WRITE:     nextState = WRITE_NOP;
		WRITE_NOP: nextState = PRECHARGE;
		PRECHARGE: nextState = PRE_NOP1;
		PRE_NOP1:  nextState = PRE_NOP2;
		PRE_NOP2:  nextState = DONE;
		DONE:      nextState = START;
	 endcase
  end
  
  // Procedural Output logic
  always_ff @(negedge reset_n, posedge clock) begin
    if(~reset_n) begin
	   write_DRAM_BA <= 2'b00;
		write_DRAM_LDQM <= 0;
		write_DRAM_UDQM <= 0;
		write_DRAM_CKE <= 1;
		write_done <= 0;
		write_en <= 0;
	 end
	 else begin
		 write_DRAM_BA <= 2'b00;
		 write_DRAM_LDQM <= 0;
		 write_DRAM_UDQM <= 0;
		 write_DRAM_CKE <= 1;
		 case(state)
			START: begin
			  write_done <= 0;
			  // Output a NOP
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 1;
			  // Addr is a "Don't Care"
			  
			  // Special case: we need to nab the row and column in this state
			  {row_addr, col_addr} <= write_addr;
			  write_en <= 0;
			end
			ACTIVATE: begin
			  // Output a Bank Activate op
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 0;
			  write_DRAM_WE_N  <= 1;
			  
			  // Output the row as the address
			  write_DRAM_ADDR <= {1'b0, row_addr};
			end
			ACT_NOP: begin
			  // Output a NOP
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 1;
			  // Addr is a "Don't Care"
			end
			WRITE: begin
			  // Output a READ command
			  write_DRAM_CAS_N <= 0;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 0;
			  
			  write_en <= 1; // Telling the 3-state drivers we're writing
			  write_DRAM_DQ <= write_data;
			  
			  // Output the column as the address
			  write_DRAM_ADDR <= {3'b000, col_addr};
			end
			WRITE_NOP: begin
			  // Output a NOP
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 1;
			  // Addr is a "Don't Care"
			  
			  write_en <= 0; // Telling the 3-state drivers we're done writing
			end
			PRECHARGE: begin
			  // Output a PRECHARGE command
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 0;
			  write_DRAM_WE_N  <= 0;
			  // Addr is a "Don't Care"
			  // Bank is already set to correct value
			end
			PRE_NOP1: begin
			  // Output a NOP
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 1;
			  // Addr is a "Don't Care"
			end
			PRE_NOP2: begin
			  // Output a NOP
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 1;
			  // Addr is a "Don't Care"
			end
			DONE: begin
			// Output a NOP
			  write_DRAM_CAS_N <= 1;
			  write_DRAM_CS_N  <= 0;
			  write_DRAM_RAS_N <= 1;
			  write_DRAM_WE_N  <= 1;
			  // Addr is a "Don't Care"
			  
			  write_done <= 1;
			end
		 endcase
	 end
  end
  
  // FSM logic
  always_ff @(negedge reset_n, posedge clock) begin
    if(~reset_n) begin
	   state <= START;
	 end
	 else begin
	   state <= nextState;
	 end
  end
  
endmodule: NaiveWriteFSM

/*module NaiveWriteFSM_test;

  logic clock, reset_n, write_go;
  logic write_done;
  logic [21:0] write_addr;
  logic write_DRAM_CLK, write_DRAM_CKE, write_DRAM_CAS_N, write_DRAM_CS_N, write_DRAM_LDQM, write_DRAM_UDQM, write_DRAM_RAS_N, write_DRAM_WE_N;
  logic [12:0] write_DRAM_ADDR;
  logic [1:0]  write_DRAM_BA;

  NaiveWriteFSM naivewritefsm(.*);
  
  initial begin
    reset_n <= 0;
	 reset_n <= #1 1;
	 clock <= 0;
	 
	 forever #5 clock <= ~clock;
  end
  
  initial begin
    write_go = 0;
	 write_addr <= 22'b1101010101010101010101;
	 @(posedge clock);
	 @(posedge clock);
	 @(posedge clock);
  
    write_go <= 1;
	 @(posedge clock);
	 write_go <= 0;
	 
	 @(posedge write_done);
	 @(posedge clock);
	 @(posedge clock);
	 @(posedge clock);
	 $finish;
  end

endmodule: NaiveWriteFSM_test*/

