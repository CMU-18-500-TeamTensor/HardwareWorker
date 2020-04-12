`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module LinearWeightGradient
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, A1, A2, A3, A4, A5, LOAD1, WB1, CHECK1, LOADX, DONE} state, nextState;

  assign done = state == DONE;

  
  // Next State logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? A1 : WAIT;
      A1:
        nextState = (d.done) ? A2 : A1;
      A2:
        nextState = (a.done && c.done) ? A3 : A2;
      A3:
        nextState = (d.done) ? A4 : A3;
      A4:
        nextState = (d.done && c.done) ? A5 : A4;
      A5:
        nextState = (r[10] == r[21]) ? DONE : LOAD1;
      LOAD1:
        nextState = (a.done) ? WB1 : LOAD1;
      WB1:
        nextState = (d.done) ? CHECK1 : WB1;
      CHECK1:
        nextState = (r[11] == r[22]) ? LOADX : A5;
      LOADX:
        nextState = (c.done) ? A5 : LOADX;
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
        A1: begin
          a.ptr <= a.region_begin;
          c.ptr <= c.region_begin;
          d.ptr <= d.region_begin;
          
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= 32'd2;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;

            a.ptr <= a.ptr + 1; // 
            c.ptr <= c.ptr + 1;
          end
        end
        A2: begin
          c.r_en <= 1;
          c.avail <= 1;
 
          a.r_en <= 1;
          a.avail <= 1;

          if(c.done) r[21] <= c.data_load;
          if(a.done) r[22] <= a.data_load;

          if(a.done && c.done) begin
            r[10] <= 0;
            r[11] <= 0;
            r[12] <= 0;

            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
          end
        end
        A3: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[22];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end          
        end
        A4: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[21];

          c.r_en <= 1;
          c.avail <= 1;

          if(c.done) r[13] <= c.data_load;

          if(c.done && d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;

            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
          end
        end
        A5: begin
          
        end
        LOAD1: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            r[14] <= a.data_load;
            a.ptr <= a.ptr + 1;
            r[11] <= r[11] + 1;
          end
        end
        WB1: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[13] * r[14];

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
            r[12] <= r[12] + 1;
          end
        end
        CHECK1: begin
          if(r[11] == r[12]) r[11] <= 0;
        end
        LOADX: begin
          c.r_en <= 1;
          c.avail <= 1;

          if(c.done) begin
            r[13] <= c.data_load;
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
            r[10] <= r[10] + 1;
          end
        end
      endcase
      state <= nextState;
    end
  end

endmodule: LinearWeightGradient
