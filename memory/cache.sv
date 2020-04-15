`default_nettype none

`include "memory/mem_handle.vh"

module cache(input  logic        clk, rst_l, w_en, r_en, write_through, read_through,
             input  logic [`ADDR_SIZE-1:0] addr,
             input  logic [31:0] data_store,
             output logic [31:0] data_load,
             output logic        done, cache_hit,
             // Actual memory input/output
             input  logic [`CACHE_SIZE-1:0][31:0] line_read,
             output logic [`CACHE_SIZE-1:0][31:0] line_store,
             input  logic        mem_ready, mem_done,
             output logic        mem_w_line, mem_r_line, mem_w_one, mem_r_one,
             output logic [`ADDR_SIZE-1:0] mem_addr);

  logic [`CACHE_SIZE:0][31:0] M;

  logic [`ADDR_SIZE-1:`CACHE_BITS] line_addr;
  logic [`CACHE_BITS-1:0] item_addr;
  assign item_addr = addr[`CACHE_BITS-1:0];

  enum logic [5:0] {WAIT, W_MAKE_CACHE, R_MAKE_CACHE, LINE_FLUSH, LINE_INTER,
                     LINE_LOAD, R_THRU_MAKE, R_THRU_SHOW, W_THRU_MAKE, 
                     W_THRU_SHOW, SHOW} state, nextState;

  logic [`ADDR_SIZE-1:`CACHE_BITS] line_requested;
  assign line_requested = addr[`ADDR_SIZE-1:`CACHE_BITS];

  assign cache_hit = 0;

  logic cache_valid, cache_dirty;

  assign done = ((state == SHOW) ||  
                 (state == W_THRU_SHOW) || (state == R_THRU_SHOW));

  // nextState logic
  always_comb begin
    unique case(state)
      WAIT: begin
        if(w_en) begin
          if(write_through) begin
            if(cache_dirty)
              nextState = LINE_FLUSH;
            else
              nextState = W_THRU_MAKE;
          end
          else begin
            if(~cache_valid || (line_requested != line_addr)) begin
              if(cache_dirty)
                nextState = LINE_FLUSH;
              else
                nextState = LINE_LOAD;
            end
            else
              nextState = W_MAKE_CACHE;
          end
        end
        else if(r_en) begin
          if(read_through) begin
            if(cache_dirty)
              nextState = LINE_FLUSH;
            else
              nextState = R_THRU_MAKE;
          end
          else begin
            if(~cache_valid || (line_requested != line_addr)) begin
              if(cache_dirty)
                nextState = LINE_FLUSH;
              else
                nextState = LINE_LOAD;
            end
            else
              nextState = R_MAKE_CACHE;
          end
        end
        else
          nextState = WAIT;
      end
      W_MAKE_CACHE: begin
        nextState = SHOW;
      end
      R_MAKE_CACHE: begin
        nextState = SHOW;
      end
      SHOW: begin
        if(~w_en && ~r_en)
          nextState = WAIT;
        else
          nextState = SHOW;
      end
      LINE_FLUSH: begin
        if(mem_done) begin
          if(w_en) begin
            if(write_through)
              nextState = W_THRU_MAKE;
            else
              nextState = LINE_INTER;
          end
          else if(r_en) begin
            if(read_through)
              nextState = R_THRU_MAKE;
            else
              nextState = LINE_INTER;
          end
        end
        else
          nextState = LINE_FLUSH;
      end
      LINE_INTER: begin
        nextState = LINE_LOAD;
      end
      LINE_LOAD: begin
        if(mem_done) begin
          if(w_en)
            nextState = W_MAKE_CACHE;
          else if(r_en)
            nextState = R_MAKE_CACHE;
        end
        else
          nextState = LINE_LOAD;
      end
      R_THRU_MAKE: begin
        if(mem_done)
          nextState = R_THRU_SHOW;
        else
          nextState = R_THRU_MAKE;
      end
      W_THRU_MAKE: begin
        if(mem_done)
          nextState = W_THRU_SHOW;
        else
          nextState = W_THRU_MAKE;
      end
      R_THRU_SHOW: begin
        if(~r_en)
          nextState = WAIT;
        else
          nextState = R_THRU_SHOW;
      end
      W_THRU_SHOW: begin
        if(~w_en)
          nextState = WAIT;
        else
          nextState = W_THRU_SHOW;
      end
    endcase
  end

  // Cache memory logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
      cache_valid <= 0;
      M <= 0;
      cache_dirty <= 0;
      line_addr <= 0;

      mem_w_line <= 0;
      mem_w_one <= 0;
      mem_r_line <= 0;
      mem_r_one <= 0;

    end
    else begin
      case(state)
        LINE_FLUSH: begin
          line_store <= M;
          mem_w_line <= 1;
          mem_addr <= {line_addr, `CACHE_BITS'b0};

          if(mem_done) begin
            mem_w_line <= 0;
          end
        end
        LINE_INTER: begin
          mem_w_line <= 0;
          mem_r_line <= 0;
        end
        LINE_LOAD: begin
          mem_r_line <= 1;
          mem_addr <= addr;          
          cache_valid <= 1;
          line_addr <= line_requested;

          if(mem_done) begin
            M <= line_read;
            mem_r_line <= 0;
          end
        end
        W_MAKE_CACHE: begin
          M[item_addr] <= data_store;
          cache_dirty <= 1;
        end
        R_MAKE_CACHE: begin
          data_load <= M[item_addr];
        end
        W_THRU_MAKE: begin
          mem_w_one <= 1;
          line_store[0] <= M[item_addr];
          mem_addr <= addr;

          if(mem_done) begin
            mem_w_one <= 0;
          end
        end
        R_THRU_MAKE: begin
          mem_r_one <= 1;
          mem_addr <= addr;

          if(mem_done) begin
            data_load <= line_read[0];
            mem_r_one <= 0;
          end
        end
      endcase

      state <= nextState;
    end
  end

endmodule: cache
