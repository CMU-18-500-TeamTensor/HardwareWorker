`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"



module LinearBackward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, A1, A2, A3, A4, A5, STOREX, LOAD1, EX1, DONE} state, nextState;

  assign done = state == DONE;

  // Next State logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? A1 : WAIT;
      A1:
        nextState = (d.done) ? A2 : A1;
      A2:
        nextState = (a.done) ? A3 : A2;
      A3:
        nextState = (b.done) ? A4 : A3;
      A4:
        nextState = (d.done) ? A5 : A4;
      A5: begin
        if(r[10] == r[21]) nextState = DONE;
        else if(r[11] == r[22]) nextState = STOREX;
        else nextState = LOAD1;
      end
      STOREX:
        nextState = (d.done) ? A5 : STOREX;
      LOAD1:
        nextState = (a.done && d.done) ? EX1 : LOAD1;
      EX1:
        nextState = A5;
    endcase
  end


  // FSM logic
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
        A1: begin
          d.ptr <= d.region_begin;
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= 32'd1;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;

            a.ptr <= a.region_begin + 1;
            b.ptr <= b.region_begin + 1;
          end
        end
        A2: begin
          a.r_en <= 1;
          a.avail <= 1;
          
          if(a.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;  // a now points at data
            r[22] <= a.data_load;

            b.ptr <= b.ptr + 1;
          end
        end
        A3: begin
          b.r_en <= 1;
          b.avail <= 1;

          if(b.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;  // b now points at data
            r[21] <= b.data_load;
          end
        end
        A4: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[21];

          r[10] <= 0;
          r[11] <= 0;
          r[12] <= 0;
          r[23] <= 0;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;  // d now points at data
          end
        end
        A5: begin
          
        end
        STOREX: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[23];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;

            r[11] <= 0;
            r[10] <= r[10] + 1;
            r[23] <= 0;
          end
        end
        LOAD1: begin
          a.r_en <= 1;
          a.avail <= 1;

          b.r_en <= 1;
          b.avail <= 1;

          if(a.done) r[1] <= a.data_load;
          if(b.done) r[2] <= b.data_load;

          if(a.done && b.done) begin
            a.ptr <= a.ptr + 1;
            b.ptr <= b.ptr + 1;

            r[11] <= r[11] + 1;
            r[12] <= r[12] + 1;
          end
        end
        EX1: begin
          r[23] <= r[23] + (r[1] * r[2]);
        end
      endcase    


      state <= nextState;
    end
  end

endmodule: LinearBackward
