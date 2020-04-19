`ifndef MEM_HANDLE
`define MEM_HANDLE

`define NUM_PORTS 5
//`define NUM_PORTS 6 // Uncomment for DPR

`define CACHE_BITS 3
`define CACHE_SIZE 8
`define ADDR_SIZE 23
`define DATA_SIZE 32

`define M9K_SIZE 1024
`define SDRAM_SIZE 4096

interface mem_handle;
  logic [`ADDR_SIZE-1:0] region_begin,
                         region_end,
                         ptr;
  logic                  w_en, r_en;
  logic                  avail, done;
  logic                  write_through, read_through;
  logic [`DATA_SIZE-1:0] data_store, data_load;
endinterface

typedef struct packed {
  logic [`ADDR_SIZE-1:0] region_begin,
                         region_end,
                         ptr;
  logic                  w_en, r_en;
  logic                  avail, done;
  logic                  write_through, read_through;
  logic [`DATA_SIZE-1:0] data;
} mem_handle_t;

`endif
