
`ifndef FPUDEFINE
`define FPUDEFINE

`include "memory/mem_handle.vh"

typedef enum logic [5:0] {LINEAR_FW, CONV_FW} op_id;

interface FPUJMInterface;

  mem_handle a(), b(), c(), d();

  op_id op;

endinterface

`endif

