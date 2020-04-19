`default_nettype none

`include "memory/mem_handle.vh"


module CopyRegion
  (input logic clk, rst_l,
   mem_handle a, d,
   input logic go,
   output logic done);
  
  reg[31:0] r;

  assign done = state == DONE;

  enum logic [2:0] {WAIT, READ, WRITE, DONE} state, nextState;

  // Next State Logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? READ : WAIT;
      READ:
        nextState = (a.done) ? WRITE : READ;
      WRITE: begin
        if(d.done) begin
          if(d.ptr == d.region_end - 1)
            nextState = DONE;
          else
            nextState = WRITE;
        end
        else
          nextState = WRITE;
      end
      DONE:
        nextState = (~go) ? WAIT : DONE;
    endcase
  end


  // FSM Logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;

      a.ptr <= 0;
      a.r_en <= 0;
      a.w_en <= 0;
      a.avail <= 0;
      a.read_through <= 0;
      a.write_through <= 0;

      d.ptr <= 0;
      d.r_en <= 0;
      d.w_en <= 0;
      d.avail <= 0;
      d.read_through <= 0;
      d.write_through <= 0;

    end
    else begin
      case(state)
        WAIT: begin
          a.ptr <= a.region_begin;

          d.ptr <= d.region_begin;
        end
        READ: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done && a.avail) begin
            r <= a.data_load;
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;
          end
        end
        WRITE: begin
          d.w_en  <= 1;
          d.avail <= 1;
          d.data_store <= r;
          d.write_through <= d.ptr == d.region_end-1;

          if(d.done && d.avail) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.write_through <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        DONE: begin

        end
      endcase


      state <= nextState;
    end
  end

endmodule: CopyRegion


