
module ZeroRegion
  (input logic clk, rst_l,
   mem_handle a,
   input logic go,
   output logic done);

  reg [31:0] r;

  enum logic [2:0] {WAIT, WRITE, DONE} state, nextState;

  // Next State Logic
  always_comb begin
    unique case(state)
      WAIT: begin
        nextState = (go) ? WRITE : WAIT;
      end
      WRITE: begin
        nextState = (a.ptr == a.region_end) ? DONE : WRITE;
      end
      DONE: begin
        nextState = (~go) ? WAIT : DONE;
      end
    endcase
  end

  // FSM Logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
      
      a.ptr <= 0;
      a.w_en <= 0;
      a.r_en <= 0;
      a.avail <= 0;
      a.read_through <= 0;
      a.write_through <= 0;
    end
    else begin
      case(state)
        WAIT: begin
          a.ptr <= a.region_begin;
        end
        WRITE: begin
          a.w_en <= 1;
          a.avail <= 1;
          a.data_store <= 0;

          if(a.done && a.avail) begin
            a.ptr <= a.ptr + 1;
            a.avail <= 0;
            a.w_en <= 0;
          end
        end
        DONE: begin

        end
      endcase     

      state <= nextState;
    end
  end

endmodule: ZeroRegion

