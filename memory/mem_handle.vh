

package MEM_HANDLE;

  typedef struct packed {
    logic [ADDR_SIZE-1:0] region_begin,
                          region_end,
                          ptr;
    logic                 w_en, r_en;
    logic                 avail, done;
    logic [DATA_SIZE-1:0] data;
  } mem_handle;

endpackage: MEM_HANDLE

