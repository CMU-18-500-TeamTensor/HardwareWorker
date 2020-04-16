
`ifndef FPUDEFINE
`define FPUDEFINE

`include "memory/mem_handle.vh"

typedef enum logic [5:0] {NOOP, LINEAR_FW, LINEAR_BW, LINEAR_WGRAD, 
                          LINEAR_BGRAD, CONV_FW, CONV_BW, CONV_WGRAD, 
                          CONV_BGRAD, MAXPOOL_FW, MAXPOOL_BW, RELU_FW, 
                          RELU_BW, FLATTEN_FW, FLATTEN_BW, PARAM_UPDATE,
                          MSE_FW, MSE_BW} op_id;

interface FPUJMInterface;

  mem_handle a(), b(), c(), d();

  op_id op;

endinterface

`endif

