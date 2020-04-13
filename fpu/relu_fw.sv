`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module ReLUForward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, START, START2, START3, START4, START5, START6,
                    LOOP, LOAD, WRITE, DONE} state, nextState;

  assign done = state == DONE;

  // Next State Logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? START : WAIT;
      START:
        nextState = (a.done) ? START2 : START;
      START2: begin
        if(r[1] == 1)
          nextState = START3;
        else
          nextState = START4;
      end
      START3: begin
        nextState = (d.done) ? LOOP : START3;
      end
      START4: begin
        nextState = (a.done && d.done) ? START5 : START4;
      end
      START5: begin
        nextState = (a.done && d.done) ? START6 : START5;
      end
      START6: begin
        nextState = (d.done) ? LOOP : START6;
      end
      LOOP: begin
        nextState = (d.ptr == d.region_end) ? DONE : LOAD;
      end
      LOAD: begin
        if(a.done) begin
          if(a.data_load[31])
            nextState = LOOP;
          else
            nextState = WRITE;
        end
        else
          nextState = LOAD;
      end
      WRITE: begin
        nextState = (d.done) ? LOOP : WRITE;
      end
    endcase
  end

  // FSM logic
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
        START: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) begin
            r[1] <= a.data_load;
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;
            r[3] <= 0;
          end
        end
        START2: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) r[2] <= a.data_load;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];

          if(a.done && d.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START3: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[2];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START4: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) r[3] <= a.data_load;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[2];

          if(a.done && d.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START5: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) r[2] <= a.data_load;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[3];

          if(a.done && d.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START6: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[2];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        LOOP: begin
          
        end
        LOAD: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) begin
            r[5] <= a.data_load;
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;
            if(a.data_load[31])
              d.ptr <= d.ptr + 1;
          end
        end
        WRITE: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[5];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
      endcase
    end
  end

endmodule: ReLUForward
