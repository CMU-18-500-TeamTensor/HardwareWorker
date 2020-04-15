

module MMU();

  logic clk, rst_l;
  mem_handle mh();

  // SDRAM interface
  logic        SDRAM_pll_locked;
  logic        SDRAM_ready;
  logic        SDRAM_as, SDRAM_rw;
  logic [22:0] SDRAM_addr;
  logic [15:0] SDRAM_data_write;
  logic [15:0] SDRAM_data_read;
  logic        SDRAM_done;

  // m9k interface
  logic        m9k_w_en, m9k_r_en;
  logic [14:0] m9k_addr;
  logic [31:0] m9k_data_store;
  logic [31:0] m9k_data_load;
  logic        m9k_done;

  mport_manager mpm(.*);

endmodule: MMU
