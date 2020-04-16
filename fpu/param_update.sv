`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module ParamUpdate
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, START, LOAD, WRITE, DONE} state, nextState;

  assign done = state == DONE;


  // Next State logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? START : WAIT;
      START:
        nextState = (a.done) ? LOAD : START;
      LOAD:
        nextState = (a.done && d.done) ? WRITE : LOAD;
      WRITE: begin
        if(d.done) begin
          if(d.ptr == d.region_end - 1)
            nextState = DONE;
          else
            nextState = LOAD;
        end
        else
          nextState = WRITE;
      end
      DONE:
        nextState = (~go) ? WAIT : DONE;
    endcase
  end

  // FSM and processing logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
      r <= 0;

      a.w_en <= 0;
      a.r_en <= 0;
      a.avail <= 0;
      a.ptr <= 0;
      a.data_store <= 0;
      a.read_through <= 0;
      a.write_through <= 0;

      b.w_en <= 0;
      b.r_en <= 0;
      b.avail <= 0;
      b.ptr <= 0;
      b.data_store <= 0;
      b.read_through <= 0;
      b.write_through <= 0;

      c.w_en <= 0;
      c.r_en <= 0;
      c.avail <= 0;
      c.ptr <= 0;
      c.data_store <= 0;
      c.read_through <= 0;
      c.write_through <= 0;

      d.w_en <= 0;
      d.r_en <= 0;
      d.avail <= 0;
      d.ptr <= 0;
      d.data_store <= 0;
      d.read_through <= 0;
      d.write_through <= 0;
    end
    else begin
      case(state)
       START: begin
         a.ptr <= a.region_begin;
         d.ptr <= d.region_begin;

         a.r_en <= 1;
         a.avail <= 1;

         if(a.done) begin
           r[10] <= a.data_load;
           a.r_en <= 0;
           a.avail <= 0;
           a.ptr <= a.ptr + a.data_load;
           d.ptr <= d.ptr + d.data_load;
   
           r[20] <= 1; // learning rate
         end
       end
       LOAD: begin
         a.r_en <= 1;
         a.avail <= 1;

         if(a.done) r[1] <= a.data_load;
         
         d.r_en <= 1;
         d.avail <= 1;

         if(d.done) r[2] <= d.data_load;

         if(a.done && d.done) begin
           a.r_en <= 0;
           a.avail <= 0;
           a.ptr <= a.ptr + 1;

           d.r_en <= 0;
           d.avail <= 0;
         end
       end
       WRITE: begin
         d.w_en <= 1;
         d.avail <= 1;

         d.data_store = (r[20] * r[1]) + r[2];

         if(d.done) begin
           d.ptr <= d.ptr + 1;
         end
       end
      endcase

      state <= nextState;
    end
  end

endmodule: ParamUpdate
