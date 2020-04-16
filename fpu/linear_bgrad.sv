`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module LinearBiasGradient
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, LOAD, WRITE, DONE} state, nextState;

  assign done = state == DONE;

  // Next State logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? LOAD : WAIT;
      LOAD:
        nextState = (a.done) ? WRITE : LOAD;
      WRITE: begin
        if(d.done) begin
          if(d.ptr == d.region_end) nextState = DONE;
          else nextState = LOAD;
        end
        else nextState = WRITE;
      end
      DONE:
        nextState = (~go) ? WAIT : DONE;
    endcase
  end


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
        WAIT: begin
          if(nextState == LOAD) begin
            a.ptr <= a.region_begin;
            d.ptr <= d.region_begin;
          end
        end
        LOAD: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            r[1] <= a.data_load;
            a.ptr <= a.ptr + 1;
          end
        end
        WRITE: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];
          d.write_through <= d.ptr == d.region_end-1;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
            d.write_through <= 0;
          end
        end
      endcase
      state <= nextState;
    end
  end

endmodule: LinearBiasGradient
