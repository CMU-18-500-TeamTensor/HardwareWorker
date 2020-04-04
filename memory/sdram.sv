`default_nettype none

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



endmodule: sdram

