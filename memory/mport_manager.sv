`default_nettype none

`ifndef MHANDLE
`include "mem_handle.vh"
`define MHANDLE
`endif

module mport_manager
  (input  logic        clk, w_en, r_en, write_through,
   input  logic [25:2] addr,
   input  logic [31:0] data_store,
   output logic [31:0] data_load,
   output logic        done,

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
   input  logic [31:0] m9k_data_load);


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

  cache c(.*);

endmodule : mport_manager
