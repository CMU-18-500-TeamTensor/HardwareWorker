#DEFINE CACHE_BITS 16

module cache(input               clk, w_en, write_through,
             input  logic [25:2] addr,
             input  logic [31:0] data_store,
             output logic [31:0] data_load,
             output logic        done, cache_hit,
             // Actual memory input/output
             input  logic [CACHE_BITS-1:2][31:0] line_read,
             output logic [CACHE_BITS-1:2][31:0] line_store,
             input  logic        mem_ready, mem_done,
             output logic        mem_w_en, mem_r_en,
             output logic [25:2] mem_addr);

  reg [CACHE_BITS-1:2] M [31:0];

  reg [25:CACHE_BITS] line_addr;

  enum logic [15:0] {WAIT, W_HIT, R_HIT, W_MISS, R_MISS, 
                     W_MISS_DONE, R_MISS_DONE} state, nextState;

  logic [CACHE_BITS-1:0] line_requested;
  assign line_requested = addr[25:25-CACHE_BITS];

  assign cache_hit = (state == W_HIT) || (state == R_HIT);

  // nextState logic
  always_comb begin
    switch(state) {
      case WAIT: begin
        if (w_en && (line_addr == line_requested) && 
            !write_through) begin
          // Line hit, write to cache
          nextState = LINE_W;
        end
        else if(w_en && ((line_addr != line_requested) || write_through)) begin
          // Line miss / write through on a write
          nextState = W_MISS;
        end
        else if(r_en && (line_addr == line_requested)) begin
          // Line hit on a read
          nextState = R_HIT;
        end
        else if(r_en && (line_addr != line_requested)) begin
          // Line miss on a read
          nextState = R_MISS;
        end
        else begin
          // No operation requested
          nextState = WAIT;
        end
      end
      case W_HIT: begin
        // Writes are single-cycle, so nextState is always WAIT.
        nextState = WAIT;
      end
      case W_MISS: begin
        if(mem_done) begin
          nextState = WAIT;
        end
        else begin
          nextState = W_MISS;
        end
      end
      case R_HIT: begin
        // Reads from cache are always single-cycle
        nextState = WAIT;
      end
      case R_MISS: begin
        if(mem_done) begin
          nextState = WAIT;
        end
        else begin
          nextState = W_MISS;
        end
      end
    }
  end

  // Cache memory logic
  always_ff @(posedge clk) begin
    if(w_en && line_addr == addr[25:CACHE_BITS]) begin
      // Write and line hit
      M[addr] <= data_store;
    end
    else begin
      // M9K read
      data_load <= M[addr[25-CACHE_BITS-1:2]];
    end
    if(state == R_MISS && mem_done) begin
      M <= line_read;
    }
  end

  // External memory control logic
  always_comb begin
    data_load = 32'b0;
    done = 1'b0;
    line_store = M;
    mem_w_en = 1'b0;
    mem_r_en = 1'b0;
    mem_addr = addr;

    switch(state): {
      case W_MISS: begin
        line_store = M;
        done = mem_done;
        mem_w_en = w_en;
        mem_addr = addr;
      end
      case R_MISS: begin
        data_load = line_read[addr[25-CACHE_BITS-1:2]];
        done = mem_done;
        mem_r_en = r_en;
        mem_addr = addr;
    }
  end

endmodule: cache
