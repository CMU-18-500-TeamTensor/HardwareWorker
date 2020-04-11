`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"


module FPUJobManager
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   op_id op,
   input  logic avail,
   output logic done,
   output logic [3:0] port_ctr);

  enum logic [5:0] {WAIT, LINEARFW, DONE} state, nextState;

 
  // Intermediate registers
  reg [31:0][31:0] r;


  // Linear Forward control FSM
  /*
    input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   inout reg[31:0][31:0] r
  */

  logic lfw_done;
  LinearForward lf(.clk, .rst_l, .a, .b, .c, .d, .go(state == LINEARFW), 
                   .done(lfw_done), .r);

  // Next state logic
  always_comb begin
    unique case(state)
      WAIT: begin
        if(avail && op == LINEAR_FW)
          nextState = LINEARFW;
        else
          nextState = WAIT;
      end
      LINEARFW: begin
        if(lfw_done)
          nextState = DONE;
        else
          nextState = LINEARFW;
      end
      DONE: begin
        if(avail)
          nextState = DONE;
        else
          nextState = WAIT;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
    end
    else begin
      if(nextState == WAIT)
        port_ctr <= port_ctr + 1;

      state <= nextState;
    end
  end

endmodule: FPUJobManager

