

module mport_manager
  (input  logic        clk, w_en, r_en, write_through,
   input  logic [25:2] addr,
   input  logic [31:0] data_store,
   output logic [31:0] data_read,
   output logic        done,

   );


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

  /*
  module m9k_controller(input               clk, w_en,
                      input  logic [14:2] addr,
                      input  logic [31:0] data_store,
                      output logic [31:0] data_load);
  */

  
  /*
  module sdram
  (input logic clk, rst_l, pll_locked,
   input  logic [3:0]  KEY,
   input  logic        CLOCK_50, DRAM_CLK,
   output logic        DRAM_CKE, DRAM_CAS_N, DRAM_CS_N, DRAM_LDQM, 
                       DRAM_UDQM, DRAM_RAS_N, DRAM_WE_N,
   output logic [12:0] DRAM_ADDR,
   output logic [1:0]  DRAM_BA,
   inout  wire  [15:0] DRAM_DQ,
   output logic        ready,
   input  logic        as, rw,
   input  logic [22:0] addr,
   input  logic [15:0] data_write,
   output logic [15:0] data_read,
   output logic        done);
  */

  cache c();

  sdram sdram_c();
  
  M9KController m9k_c();

endmodule : mport_manager
