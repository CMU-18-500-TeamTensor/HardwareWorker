`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

module ConvolutionBackward
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   output reg[31:0][31:0] r);


  enum logic [4:0] {WAIT, START, START1, START2, START3, START4, START5,
                    START6, START7, START8, BETA_LOOP, ALPHA_LOOP, J_LOOP,
                    I_LOOP, CI_LOOP, CI_EXTRA, CO_LOOP, CO_LOAD1, CO_LOAD2,
                    CO_WB, DONE} state, nextState;

  assign done = state == DONE;

  // Next State Logic
  always_comb begin
    unique case(state) 
      WAIT: 
        nextState = (go) ? START : WAIT;
      START:
        nextState = (go) ? START1 : START;
      START1:
        nextState = (c.done && d.done) ? START2 : START1;
      START2:
        nextState = (b.done && c.done) ? START3 : START2;
      START3:
        nextState = (b.done && c.done) ? START4 : START3;
      START4: 
        nextState = (b.done) ? START5 : START4;
      START5:
        nextState = (b.done && d.done) ? START6 : START5;
      START6:
        nextState = (b.done && d.done) ? START7 : START6;
      START7:
        nextState = (b.done && d.done) ? START8 : START7;
      START8:
        nextState = (b.done) ? BETA_LOOP : START8;
      BETA_LOOP:
        nextState = (r[1] == r[14]) ? DONE : ALPHA_LOOP;
      ALPHA_LOOP:
        nextState = (r[2] == r[13]) ? BETA_LOOP : J_LOOP;
      J_LOOP:
        nextState = (r[3] == r[18]) ? ALPHA_LOOP : I_LOOP;
      I_LOOP:
        nextState = (r[5] == r[16]) ? J_LOOP : CI_LOOP;
      CI_LOOP:
        nextState = ((r[5] == r[16]) || (r[23][31]) || (r[24][31]) ||
                     (r[23] >= r[20]) || (r[24] >= r[19])) ? I_LOOP : CI_EXTRA;
      CI_EXTRA:
        nextState = CO_LOOP;
      CO_LOOP:
        nextState = (r[6] == r[15]) ? CI_LOOP : CO_LOAD1;
      CO_LOAD1:
        nextState = (a.done && b.done) ? CO_LOAD2 : CO_LOAD1;
      CO_LOAD2:
        nextState = (d.done) ? CO_WB : CO_LOAD2;
      CO_WB:
        nextState = (d.done) ? CO_LOOP : CO_WB;
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
          if(go) begin
            a.ptr <= a.region_begin + 4;
            b.ptr <= b.region_begin;
            c.ptr <= c.region_begin + 1;
            d.ptr <= d.region_begin;
          end
        end
        START1: begin
          c.r_en <= 1;
          c.avail <= 1;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= 32'd3;

          if(c.done) r[17] <= c.data_load;
   
          if(c.done && d.done) begin
            c.r_en <= 0;
            c.avail <= 0;
            d.w_en <= 0;
            d.avail <= 0;

            b.ptr <= b.ptr + 1;
            c.ptr <= c.ptr + 1;
            d.ptr <= d.ptr + 1;
          end
        end
        START2: begin
          b.r_en <= 1;
          b.avail <= 1;

          c.r_en <= 1;
          c.avail <= 1;

          if(b.done) r[11] <= b.data_load;
          if(c.done) r[19] <= c.data_load;

          if(b.done && c.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;

            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
          end
        end
        START3: begin
          b.r_en <= 1;
          b.avail <= 1;
        
          c.r_en <= 1;
          c.avail <= 1;

          if(b.done) r[13] <= b.data_load;
          if(c.done) r[20] <= c.data_load;

          if(b.done && c.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;
            
            c.r_en <= 0;
            c.avail <= 0;
            c.ptr <= c.ptr + 1;
          end
        end
        START4: begin
          b.r_en <= 1;
          b.avail <= 1;

          if(b.done) r[14] <= b.data_load;

          if(b.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 2;
          end
        end
        START5: begin
          b.r_en <= 1;
          b.avail <= 1;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[17];

          if(b.done) r[15] <= b.data_load;

          if(b.done && d.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;

            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START6: begin
          b.r_en <= 1;
          b.avail <= 1;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[19];

          if(b.done) r[16] <= b.data_load;

          if(b.done && d.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;
           
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;
          end
        end
        START7: begin
          b.r_en <= 1;
          b.avail <= 1;

          d.w_en <= 1;
          d.avail <= 1;
          d.data_store <= r[20];

          if(b.done) r[17] <= b.data_load;

          if(b.done && d.done) begin
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;
           
            d.w_en <= 0;
            d.avail <= 0;
            d.ptr <= d.ptr + 1;

            r[10] <= r[19] * r[16];
          end
        end
        START8: begin
          b.r_en <= 1;
          b.avail <= 1;

          if(b.done) begin
            r[18] <= b.data_load;
            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;

            r[1] <= 0;
          end
        end
        BETA_LOOP: begin
          if(r[1] != r[14]) begin
            r[2] <= 0;
            r[21] <= (r[1] * r[11]) - (r[18] >> 1);
          end
        end
        ALPHA_LOOP: begin
          if(r[2] == r[13])
            r[1] <= r[1] + 1;
          else begin
            r[3] <= 0;
            r[22] <= (r[2] * r[11]) - (r[17] >> 1);
            r[28] <= a.ptr;
          end
        end
        J_LOOP: begin
          if(r[3] == r[18])
            r[2] <= r[2] + 1;
          else begin
            r[4] <= 0;
            r[23] <= r[21] + r[3];
          end
        end
        I_LOOP: begin
          if(r[5] == r[16])
            r[3] <= r[3] + 1;
          else begin
            r[5] <= 0;
            r[24] <= r[22] + r[4];
            r[25] <= r[23] * r[10];
          end
        end
        CI_LOOP: begin
          if((r[5] == r[16]) || (r[23][31]) || (r[24][31]) ||
             (r[23] >= r[20]) || (r[24] >= r[19]))
            r[4] <= r[4] + 1;
          else begin
            r[6] <= 0;
            r[26] <= r[24] * r[16];
          end
        end
        CI_EXTRA: begin
          r[27] <= r[5] + r[25] + r[26];
          a.ptr <= r[28];
        end
        CO_LOOP: begin
          if(r[6] == r[15]) r[5] <= r[5] + 1;
        end
        CO_LOAD1: begin
          a.r_en <= 1;
          a.avail <= 1;

          b.r_en <= 1;
          b.avail <= 1;

          if(a.done) r[7] <= a.data_load;
          if(b.done) r[8] <= b.data_load;

          if(a.done && b.done) begin
            a.r_en <= 0;
            a.avail <= 0;
            a.ptr <= a.ptr + 1;

            b.r_en <= 0;
            b.avail <= 0;
            b.ptr <= b.ptr + 1;

            d.ptr <= d.region_begin + r[27];
          end
        end
        CO_LOAD2: begin
          d.r_en <= 1;
          d.avail <= 1;
          d.read_through <= 1;
 
          if(d.done) begin
            r[9] <= r[7] * r[8];
            r[30] <= d.data_load;

            d.r_en <= 0;
            d.avail <= 0;
            d.read_through <= 0;
          end
        end
        CO_WB: begin
          d.w_en <= 1;
          d.avail <= 1;
          d.write_through <= 1;
          d.data_store <= r[30] + r[9];

          if(d.done) begin
            r[6] <= r[6] + 1;

            d.w_en <= 0;
            d.avail <= 0;
            d.write_through <= 0;
          end
        end
      endcase
      state <= nextState;
    end
  end

endmodule: ConvolutionBackward
