`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module FlattenBackward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);

  enum logic [5:0] {WAIT, START, START2, START3, START4, START5,
                    LOOP, LOOP_R, LOOP_W, DONE} state, nextState;


  // Next State logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? START : WAIT;
      START:
        nextState = (d.done) ? START2 : START;
      START2:
        nextState = (a.done && c.done) ? START3 : START2;
      START3:
        nextState = (c.done && d.done) ? START4 : START3;
      START4:
        nextState = (c.done && d.done) ? START5 : START4;
      START5:
        nextState = (d.done) ? LOOP : START5;
      LOOP:
        nextState = (r[5] == r[2]) ? DONE : LOOP_R;
      LOOP_R:
        nextState = (a.done) ? LOOP_W : LOOP_R;
      LOOP_W:
        nextState = (d.done) ? LOOP : LOOP_W;
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
        START: begin
          d.ptr <= d.region_begin;
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= 32'd3;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
        
            a.ptr <= a.region_begin + 1;
            c.ptr <= c.region_begin + 1;
          end
        end
        START2: begin
          c.r_en <= 1;
          c.avail <= 1;

          a.r_en <= 1;
          a.avail <= 1;

          if(c.done) r[1] <= c.data_load;
          if(a.done) r[2] <= a.data_load;

          if(a.done && c.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;

            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;  // a now points at data
          end
        end
        START3: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];

          c.r_en <= 1;
          c.avail <= 1;
          
          if(c.done) r[3] <= c.data_load;
        
          if(c.done && d.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;

            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START4: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[3];

          c.r_en <= 1;
          c.avail <= 1;
        
          if(c.done) r[1] <= c.data_load;

          if(c.done && d.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;  // c now points at data
            
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START5: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
            r[5] <= 0;
          end
        end
        LOOP: begin
          if(r[5] != r[2]) r[5] <= r[5] + 1;
        end
        LOOP_R: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;
            r[1] <= a.data_load;
          end
        end
        LOOP_W: begin
          d.w_en <= 1;
          d.avail <= 0;
          d.data_store <= r[1];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
      endcase

      state <= nextState;
    end
  end


endmodule: FlattenBackward


