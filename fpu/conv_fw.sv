`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module ConvolutionForward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, START_LOAD1, START_LOAD2, START_LOAD3, START_LOAD4,
                    START_CALC, J_LOOP, I_LOOP, BETA_LOOP, ALPHA_LOOP, GAMMA_LOOP,
                    DELTA_LOOP_LOAD, DELTA_LOOP_CALC1, DELTA_LOOP_CALC2,
                    DELTA_LOOP_STORE, BIAS_LOOP_LOAD, BIAS_LOOP_CALCS,
                    BIAS_LOOP_STORE, DONE} state, nextState;

  assign done = state == DONE;



  // FSM and processing logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;

      a.w_en <= 0;
      a.r_en <= 0;
      a.avail <= 0;
      a.ptr <= 0;
      a.data_store <= 0;

      b.w_en <= 0;
      b.r_en <= 0;
      b.avail <= 0;
      b.ptr <= 0;
      b.data_store <= 0;

      c.w_en <= 0;
      c.r_en <= 0;
      c.avail <= 0;
      c.ptr <= 0;
      c.data_store <= 0;

      d.w_en <= 0;
      d.r_en <= 0;
      d.avail <= 0;
      d.ptr <= 0;
      d.data_store <= 0;

    end
    else begin
      case(state)
      endcase
    state <= nextState;
    end
  end

endmodule: ConvolutionForward
