`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module LinearWeightGradient
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, A1, A2, A3, A4, A5, A6, A7, A8, LOAD1, EX1,
                    WB1, LOAD2, EX2, WB2, LOAD3, EX3, WB3, DONE} state, nextState;

  assign done = state == DONE;


endmodule: LinearWeightGradient
