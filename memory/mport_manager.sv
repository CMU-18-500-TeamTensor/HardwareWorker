`default_nettype none

`include "memory/mem_handle.vh"

module mport_manager
  (input  logic clk, rst_l,
   mem_handle mh,

   // SDRAM interface
   output logic        SDRAM_pll_locked,
   input  logic        SDRAM_ready,
   output logic        SDRAM_as, SDRAM_rw,
   output logic [22:0] SDRAM_addr,
   output logic [15:0] SDRAM_data_write,
   input  logic [15:0] SDRAM_data_read,
   input  logic        SDRAM_done,

   // m9k interface
   output logic        m9k_w_en, m9k_r_en,
   output logic [14:0] m9k_addr,
   output logic [31:0] m9k_data_store,
   input  logic [31:0] m9k_data_load,
   input  logic        m9k_done);

  // Counter variable used when reading a block 
  logic [`CACHE_BITS:0] line_ctr, num_elems;

/*module cache(input               clk, w_en, write_through,
             input  logic [25:2] addr,
             input  logic [31:0] data_store,
             output logic [31:0] data_load,
             output logic        done, cache_hit,
             // Actual memory input/output
             input  logic [CACHE_BITS-1:2][31:0] line_read,
             output logic [CACHE_BITS-1:2][31:0] line_store,
             input  logic        mem_ready, mem_done,
             output logic        mem_w_en, mem_r_en,
             output logic [25:2] mem_addr);*/

  logic cache_hit;

  // Actual memory input/output
  logic [`CACHE_SIZE-1:0][31:0] line_read;
  logic [`CACHE_SIZE-1:0][31:0] line_store;
  logic        mem_ready, mem_done;
  logic        mem_w_line, mem_r_line, mem_w_one, mem_r_one;
  logic [`ADDR_SIZE-1:0] mem_addr;

  cache c(.clk, .rst_l, .w_en(mh.w_en), .r_en(mh.r_en), .write_through(mh.write_through), 
          .read_through(mh.read_through), .addr(mh.ptr), .data_store(mh.data_store),
          .data_load(mh.data_load), .done(mh.done), .cache_hit(cache_hit),
          .line_read, .line_store, .mem_ready, .mem_done, 
          .mem_w_line, .mem_r_line, .mem_w_one, .mem_r_one, .mem_addr);

  enum logic[3:0] {WAIT, M9K_LOOP, M9K_SERVICE, SDRAM_LOOP, SDRAM_SERVICE0,
                   SDRAM_SERVICE0I, SDRAM_SERVICE1, SHOW} state, nextState;

  // Internal logic
  always_comb begin
    SDRAM_pll_locked = 1;
    SDRAM_as = 0;
    SDRAM_rw = 0;
    SDRAM_addr = 23'b0;
    SDRAM_data_write = 16'b0;

    m9k_w_en = 0;
    m9k_r_en = 0;
    m9k_addr = 0;
    m9k_data_store = 32'd0;

    case(state)
      M9K_SERVICE: begin
        m9k_w_en = mem_w_line || mem_w_one;
        m9k_r_en = mem_r_line || mem_r_one;
        m9k_addr = mem_addr;
        m9k_data_store = line_store[line_ctr];
      end
      SDRAM_SERVICE0: begin
        SDRAM_as = 1;
        SDRAM_rw = mem_w_line || mem_w_one;
        SDRAM_addr = {mem_addr[21:`CACHE_BITS], line_ctr[`CACHE_BITS-1:0], 1'b0};
        SDRAM_data_write = line_store[line_ctr][15:0];
      end
      SDRAM_SERVICE1: begin
        SDRAM_as = 1;
        SDRAM_rw = mem_w_line || mem_w_one;
        SDRAM_addr = {mem_addr[21:`CACHE_BITS], line_ctr[`CACHE_BITS-1:0], 1'b1};
        SDRAM_data_write = line_store[line_ctr][31:16];
      end
    endcase
  end

  // Nextstate logic
  always_comb begin
  
    unique case(state)
      WAIT: begin
        if(mem_w_line || mem_r_line || mem_w_one || mem_r_one) begin
          if(mem_addr[`ADDR_SIZE-1])
            nextState = M9K_LOOP;
          else
            nextState = SDRAM_LOOP;
        end
        else
          nextState = WAIT;
      end
      M9K_LOOP: begin
        if(line_ctr == num_elems)
          nextState = SHOW;
        else
          nextState = M9K_SERVICE;
      end
      M9K_SERVICE: begin
        if(m9k_done)
          nextState = M9K_LOOP;
        else
          nextState = M9K_SERVICE;
      end
      SDRAM_LOOP: begin
        if(line_ctr == num_elems)
          nextState = SHOW;
        else
          nextState = SDRAM_SERVICE0;
      end
      SDRAM_SERVICE0: begin
        if(SDRAM_done) 
          nextState = SDRAM_SERVICE0I;
        else
          nextState = SDRAM_SERVICE0;
      end
      SDRAM_SERVICE0I: begin
        nextState = SDRAM_SERVICE1;
      end
      SDRAM_SERVICE1: begin
        if(SDRAM_done)
          nextState = SDRAM_LOOP;
        else
          nextState = SDRAM_SERVICE1;
      end
      SHOW: begin
        if(mem_w_line || mem_r_line || mem_w_one || mem_r_one)
          nextState = SHOW;
        else
          nextState = WAIT;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
      mem_done <= 0;

      line_read <= 0;
    end
    else begin
      case(state)
        WAIT: begin
          line_ctr <= 0;
          if(mem_r_line)
            num_elems <= `CACHE_SIZE;
          if(mem_w_line)
            num_elems <= `CACHE_SIZE;
          if(mem_w_one)
            num_elems <= 1;
          if(mem_r_one)
            num_elems <= 1;
        end
        M9K_SERVICE: begin
          if(nextState == M9K_LOOP) begin
            if(mem_r_line || mem_r_one)
              line_read[line_ctr] <= m9k_data_load;
            line_ctr <= line_ctr + 1;
          end
        end
        SDRAM_SERVICE0: begin
          if(nextState == SDRAM_SERVICE0I)
            line_read[line_ctr][15:0] <= SDRAM_data_read;
        end
        SDRAM_SERVICE1: begin
          if(nextState == SDRAM_LOOP) begin
            line_read[line_ctr][31:16] <= SDRAM_data_read;
            line_ctr <= line_ctr + 1;
          end
        end
        SHOW: begin
          if(nextState == SHOW)
            mem_done <= 1;
          else
            mem_done <= 0;
        end
      endcase

      state <= nextState;

    end
  end



endmodule : mport_manager
