`default_nettype none

`include "memory/mem_handle.vh"

`define NUM_MPORTS 5

module MMU
  (input logic clk, rst_l,
   mem_handle mh[`NUM_MPORTS-1:0]);

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


  /*
    input               clk, w_en,
    input  logic [14:0] addr,
    input  logic [31:0] data_store,
    ioutput logic [31:0] data_load
  */
  m9k_controller m9k(.clk, .rst_l, .w_en(m9k_w_en), .addr(m9k_addr), 
                     .data_store(m9k_data_store), .data_load(m9k_data_load));

  assign m9k_done = 1;

  FakeSDRAM sdram(.*);


  logic [`NUM_MPORTS:0]       mport_SDRAM_pll_locked;
  logic [`NUM_MPORTS:0]       mport_SDRAM_ready;
  logic [`NUM_MPORTS:0]       mport_SDRAM_as, mport_SDRAM_rw;
  logic [`NUM_MPORTS:0][22:0] mport_SDRAM_addr;
  logic [`NUM_MPORTS:0][15:0] mport_SDRAM_data_write;
  logic [`NUM_MPORTS:0][15:0] mport_SDRAM_data_read;
  logic [`NUM_MPORTS:0]       mport_SDRAM_done;

  // m9k interface
  logic [`NUM_MPORTS:0]       mport_m9k_w_en, mport_m9k_r_en;
  logic [`NUM_MPORTS:0][14:0] mport_m9k_addr;
  logic [`NUM_MPORTS:0][31:0] mport_m9k_data_store;
  logic [`NUM_MPORTS:0][31:0] mport_m9k_data_load;
  logic [`NUM_MPORTS:0]       mport_m9k_done;

  logic[7:0] m9k_port_ctr, sdram_port_ctr, num_ports;
  assign num_ports = `NUM_MPORTS;

  int j;
  always_comb begin
    for(j = 0; j < `NUM_MPORTS; j = j + 1) begin
      if(j == m9k_port_ctr) begin
        m9k_w_en = mport_m9k_w_en[j];
        m9k_r_en = mport_m9k_r_en[j];
        m9k_addr = mport_m9k_addr[j];
        m9k_data_store = mport_m9k_data_store[j];
        mport_m9k_data_load[j] = m9k_data_load;
        mport_m9k_done[j] = m9k_done;
      end
      else begin
        mport_m9k_data_load[j] = 0;
        mport_m9k_done[j] = 0;
      end

      if(j == sdram_port_ctr) begin
        SDRAM_pll_locked = mport_SDRAM_pll_locked[j];
        mport_SDRAM_ready[j] = SDRAM_ready;
        SDRAM_as = mport_SDRAM_as[j];
        SDRAM_rw = mport_SDRAM_rw[j];
        SDRAM_addr = mport_SDRAM_addr[j];
        SDRAM_data_write = mport_SDRAM_data_write[j];
        mport_SDRAM_data_read[j] = SDRAM_data_read;
        mport_SDRAM_done[j] = SDRAM_done;
      end
      else begin
        mport_SDRAM_ready[j] = 0;
        mport_SDRAM_data_read[j] = 0;
        mport_SDRAM_done[j] = 0;
      end 
    end    

  end

  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      m9k_port_ctr <= 0;
      sdram_port_ctr <= 0;
    end
    else begin
      if(m9k_port_ctr == num_ports - 1)
        m9k_port_ctr <= 0;
      else if(~mport_m9k_w_en[m9k_port_ctr] && ~mport_m9k_r_en[m9k_port_ctr])
        m9k_port_ctr <= m9k_port_ctr + 1;
      
      if(sdram_port_ctr == num_ports - 1)
        sdram_port_ctr <= 0;
      else if(~mport_SDRAM_as[sdram_port_ctr])
        sdram_port_ctr <= sdram_port_ctr + 1;
    end
  end

  genvar i;
  generate
  for(i = 0; i < `NUM_MPORTS; i = i + 1) begin : mport_inst
    mport_manager mp(.clk, .rst_l, .mh(mh[i]), .SDRAM_pll_locked(mport_SDRAM_pll_locked[i]),
                      .SDRAM_ready(mport_SDRAM_ready[i]), .SDRAM_as(mport_SDRAM_as[i]),
                      .SDRAM_rw(mport_SDRAM_rw[i]), .SDRAM_addr(mport_SDRAM_addr[i]),
                      .SDRAM_data_write(mport_SDRAM_data_write[i]),
                      .SDRAM_data_read(mport_SDRAM_data_read[i]), 
                      .SDRAM_done(mport_SDRAM_done[i]), .m9k_w_en(mport_m9k_w_en[i]),
                      .m9k_r_en(mport_m9k_r_en[i]), .m9k_addr(mport_m9k_addr[i]),
                      .m9k_data_store(mport_m9k_data_store[i]), 
                      .m9k_data_load(mport_m9k_data_load[i]), .m9k_done(mport_m9k_done[i]));
  end
  endgenerate

endmodule: MMU


module FakeSDRAM
  (input logic clk, rst_l,
   input  logic        SDRAM_as, SDRAM_rw,
   input  logic [22:0] SDRAM_addr,
   input  logic [15:0] SDRAM_data_write,
   output logic [15:0] SDRAM_data_read,
   output logic SDRAM_done);

  logic [`SDRAM_SIZE-1:0][15:0] M;

  logic [7:0] ctr;

  int i;
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      M <= 0;
      ctr <= 0;
      SDRAM_done <= 0;
      SDRAM_data_read <= 0;

      M[10] <= 2;
      M[11] <= 0;
      M[12] <= 5;
      M[13] <= 0;
      M[14] <= 5;
      M[15] <= 0;
      
      for(i = 0; i < 25; i = i + 1) begin
        M[16 + 2*i] <= i + 1;
        M[17 + 2*i] <= 0;
      end

      M[68] <= 1;
      M[69] <= 0;
      M[70] <= 5;
      M[71] <= 0;

      for(i = 0; i < 5; i = i + 1) begin
        M[72 + 2*i] <= i + 1;
        M[73 + 2*i] <= 0;
      end
      
    end
    else begin
      if(SDRAM_as) begin
        if(ctr == 3) begin
          if(SDRAM_rw) begin
            M[SDRAM_addr] <= SDRAM_data_write;
            ctr <= 0;
            SDRAM_done <= 1;
          end
          else begin
            SDRAM_data_read <= M[SDRAM_addr];
            ctr <= 0;
            SDRAM_done <= 1;
          end
        end
        else
          ctr <= ctr + 1;
      end
      else
        SDRAM_done <= 0;
    end
  end

endmodule: FakeSDRAM
