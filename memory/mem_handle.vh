

package MEM_HANDLE;

  typedef struct packed {
    logic [ADDR_SIZE-1:0] region_begin,
                          region_end,
                          ptr;
  } mem_handle;

endpackage: MEM_HANDLE

