`define ADDR_SIZE 23
`define DATA_SIZE 32

interface mem_handle;
  logic [`ADDR_SIZE-1:0] region_begin,
                         region_end,
                         ptr;
  logic                  w_en, r_en;
  logic                  avail, done;
  logic                  write_through, read_through;
  logic [`DATA_SIZE-1:0] data;
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
