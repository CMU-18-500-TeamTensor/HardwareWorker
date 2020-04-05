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
   output logic        m9k_w_en, m9k_write_through,
   output logic [25:2] m9k_addr,
   output logic [31:0] m9k_data_store,
   input  logic [31:0] m9k_data_load,
   input  logic        m9k_done);

  // Counter variable used when reading a block 
  logic [`CACHE_BITS:2] line_ctr;

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
  logic [`CACHE_BITS-1:2][31:0] line_read;
  logic [`CACHE_BITS-1:2][31:0] line_store;
  logic        mem_ready, mem_done;
  logic        mem_w_en, mem_r_en;
  logic [25:2] mem_addr;

  cache c(.w_en(mh.w_en), .r_en(mh.r_en), .write_through(mh.write_through), 
          .read_through(mh.read_through), .addr(mh.ptr), .data_store(mh.data),
          .data_load(mh.data), .done(mh.done), .cache_hit(cache_hit),
          .line_read, .line_store, .line_read, .mem_ready, .mem_done, 
          .mem_w_en, .mem_r_en, .mem_addr);

  enum logic[3:0] {WAIT, SERVICE_CACHE, SERVICE_M9K_CM, SERVICE_M9K, 
                   SERVICE_SDRAM_CM, SERVICE_SDRAM0, SERVICE_SDRAM1,
                   SHOW} state, nextState;

  // Internal logic
  always_comb begin
    SDRAM_pll_locked = 1;
    SDRAM_as = 0;
    SDRAM_rw = 0;
    SDRAM_addr = 23'b0;
    SDRAM_data_write = 16'b0;

    unique case(state)
      SERVICE_CACHE: begin
        
      end
      SERVICE_SDRAM0: begin
      
      end
      SERVICE_SDRAM1: begin

      end
    endcase
  end

  // Nextstate logic
  always_comb begin
  
    unique case(state)
      WAIT: begin
        nextState = WAIT;
        //if(mh.w_en) nextState = SERVICE_CACHE;
        //else if(mh.r_en && ~mh.read_through) nextState = SERVICE_CACHE;
        //else if(mh.r_en && mh.read_through)  begin
        // Let's just get something working now and focus on the cache later.
        if(mh.w_en || mh.r_en) begin
          if(mh.ptr[`ADDR_SIZE-1]) begin
            nextState = SERVICE_M9K;
          end
          else begin
            nextState = SERVICE_SDRAM0;
          end
        end
      end
      SERVICE_CACHE: begin
        nextState = SERVICE_CACHE;
        if(~cache_hit) begin
          if(mh.ptr[`ADDR_SIZE-1]) begin
            if(mh.write_through || mh.read_through)
              nextState = SERVICE_M9K;
            else
              nextState = SERVICE_M9K_CM;
          end
          else begin
            if(mh.write_through || mh.read_through)
              nextState = SERVICE_SDRAM0;
            else
              nextState = SERVICE_SDRAM_CM;
          end
        end
        else nextState = SHOW;
      end
      SERVICE_M9K: begin
        if(m9k_done) nextState = SHOW;
        else nextState = SERVICE_M9K;
      end
      SERVICE_M9K_CM: begin
        if(m9k_done && line_ctr[`CACHE_BITS])
          nextState = SHOW;
        else
          nextState = SERVICE_M9K_CM;
      end
      SERVICE_SDRAM0: begin
        if(SDRAM_done) nextState = SERVICE_SDRAM1;
        else nextState = SERVICE_SDRAM0;
      end
      SERVICE_SDRAM1: begin
        if(SDRAM_done) nextState = SHOW;
        else nextState = SERVICE_SDRAM1;
      end
      SERVICE_SDRAM_CM: begin
        if(SDRAM_done && line_ctr[`CACHE_BITS])
          nextState = SHOW;
        else
          nextState = SERVICE_SDRAM_CM;
      end
      SHOW: begin
        // Show phase ends when the client signals the end of their
        // information need by deasserting the enable signals.
        if(~mh.w_en && ~mh.r_en) nextState = WAIT;
        else nextState = SHOW;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
    end
    else begin
      state <= nextState;
    end
  end



endmodule : mport_manager
