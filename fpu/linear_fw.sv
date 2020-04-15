`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"



module LinearForward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, A1, A2, A3, A4, A5, A6, A7, A8, LOAD1, EX1, 
                    WB1, LOAD2, EX2, WB2, LOAD3, EX3, WB3, DONE} state, nextState;

  assign done = state == DONE;


  // nextState logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? A1 : WAIT;
      A1:
        nextState = (c.done) ? A2 : A1;
      A2:
        nextState = (d.done) ? A3 : A2;
      A3:
        nextState = (c.done) ? A4 : A3;
      A4:
        nextState = (d.done) ? A5 : A4;
      A5:
        nextState = A6;
      A6:
        nextState = (a.done) ? A7 : A6;
      A7:
        nextState = (a.done && b.done) ? A8 : A7;
      A8: begin
        if(r[4] == r[1] && r[3] < r[2] - 1)
          nextState = LOAD1;
        else if(r[4] == r[1] && r[3] == r[2] - 1)
          nextState = LOAD2;
        else
          nextState = LOAD3;
      end
      LOAD1:
        nextState = (c.done && b.done && d.done) ? EX1 : LOAD1;
      EX1:
        nextState = WB1;
      WB1:
        nextState = A8; //nextState = (d.done) ? A8 : WB1;
      LOAD2:
        nextState = (c.done && d.done) ? EX2 : LOAD2;
      EX2:
        nextState = WB2;
      WB2:
        nextState = (d.done) ? DONE : WB2;
      LOAD3:
        nextState = (a.done && d.done) ? EX3 : LOAD3;
      EX3:
        nextState = WB3;
      WB3:
        nextState = (d.done) ? A8 : WB3;
      DONE:
        nextState = (go) ? DONE : WAIT;
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
        A1: begin
          a.ptr <= a.region_begin;
          b.ptr <= b.region_begin;
          c.ptr <= c.region_begin;
          c.r_en <= 1;
          c.avail <= 1;
      
          if(c.done) begin
            r[1] <= c.data_load;
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
          end
        end
        A2: begin
          d.ptr <= d.region_begin;
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];
          
          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        A3: begin
          c.r_en <= 1;
          c.avail <= 1;
          
          if(c.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
            r[1] <= c.data_load;
          end
        end
        A4: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        A5: begin
          a.ptr <= a.ptr + 1;
        end
        A6: begin
          a.r_en <= 1;
          a.avail <= 1;
          
          if(a.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;
            b.ptr <= b.ptr + 1;
          end
        end
        A7: begin
          a.r_en <= 1;
          a.avail <= 1;
          b.r_en <= 1;
          b.avail <= 1;
          
          r[3] <= 0;
          r[4] <= 0;
          r[5] <= 0;

          if(a.done) r[2] <= a.data_load;
          if(b.done) r[7] <= b.data_load;

          if(a.done && b.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;
          end
        end
        A8: begin
          
        end
        LOAD1: begin
          c.r_en <= 1;
          c.avail <= 1;

          b.r_en <= 1;
          b.avail <= 1;

          d.r_en <= 1;
          d.avail <= 1;

          if(c.done) r[8] <= c.data_load;
          if(b.done) r[7] <= b.data_load;
          if(d.done) r[5] <= d.data_load;

          if(c.done && b.done && d.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;

            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;

            d.r_en <= 0;
            d.avail <= 0;
          end
        end
        EX1: begin
          r[5] <= r[5] + r[8];
        end
        WB1: begin
          //d.w_en <= 1;
          //d.avail <= 1;
          //d.data_store <= r[5];

          //if(d.done) begin
            d.ptr <= d.region_begin + 2;
            r[4] <= 0;
            r[3] <= r[3] + 1;
            r[5] <= 0;
          //end
        end
        LOAD2: begin
          c.r_en <= 1;
          c.avail <= 1;
   
          d.r_en <= 1;
          d.avail <= 1;

          if(c.done) r[8] <= c.data_load;
          if(d.done) r[5] <= d.data_load;

          if(c.done && d.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;

            d.r_en <= 0;
            d.avail <= 0;
          end
        end
        EX2: begin
          r[5] <= r[5] + r[8];
        end
        WB2: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.write_through <= 1;
          d.data_store <= r[5];

          if(d.done) begin
            d.write_through <= 0;
            d.w_en <= 0;
            d.avail <= 0;
          end
        end
        LOAD3: begin
          a.r_en <= 1;
          a.avail <= 1;
          d.r_en <= 1;
          d.avail <= 1;

          if(a.done) r[8] <= a.data_load;
          if(d.done) r[5] <= d.data_load;

          if(a.done && d.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            d.r_en <= 0;
            d.avail <= 0;
          end
        end
        EX3: begin
          r[5] <= r[5] + (r[8] * r[7]);
        end
        WB3: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[5];
          
          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
            r[4] <= r[4] + 1;
          end
        end
      endcase

      state <= nextState;
    end
  end

endmodule: LinearForward

