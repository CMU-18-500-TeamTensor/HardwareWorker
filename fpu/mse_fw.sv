`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module MSEForward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);

  enum logic [4:0] {WAIT, START, START2, START3, LOOP, EX1, READ,
                    EX2, EX3, WRITE, DONE} state, nextState;

  assign done = state == DONE;


  // Next state logic
  always_comb begin
    unique case(state)
      WAIT:
        nextState = (go) ? START : WAIT;
      START:
        nextState = START2;
      START2:
        nextState = (d.done) ? START3 : START2;
      START3:
        nextState = (d.done) ? LOOP : START3;
      LOOP:
        nextState = (a.ptr == a.region_end) ? WRITE : READ;
      READ:
        nextState = (a.done && b.done) ? EX1 : READ;
      EX1:
        nextState = EX2;
      EX2:
        nextState = EX3;
      EX3:
        nextState = LOOP;
      WRITE:
        nextState = (d.done) ? DONE : WRITE;
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
          a.ptr <= a.region_begin + 2;  // a now points at data
          b.ptr <= b.region_begin + 2;  // b now points at data
          d.ptr <= d.region_begin;
        end
        START2: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= 1;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
          end
        end
        START3: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= 1;
        
          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            r[1] <= 0;
          end
        end
        READ: begin
          a.r_en <= 1;
          a.avail <= 1;

          if(a.done) r[2] <= a.data_load;

          b.r_en <= 1;
          b.avail <= 1;

          if(b.done) r[3] <= b.data_load;

          if(a.done && b.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;
          end
        end
        EX1: begin
          r[4] <= r[2] - r[3];
        end
        EX2: begin
          r[4] <= r[4] * r[4];
        end
        EX3: begin
          r[1] <= r[1] + r[4];
        end
        WRITE: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[1];
          d.write_through <= 1;

          if(d.done) begin
            d.w_en <= 0;
            d.avail <= 0;
            d.write_through <= 0;
          end
        end
      endcase

      state <= nextState;
    end
  end


endmodule: MSEForward
