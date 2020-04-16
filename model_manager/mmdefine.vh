`ifndef MM_DEFINE
`define MM_DEFINE


typedef enum logic [5:0] {WAIT, ASN_MODEL, ASN_LAYER, ASN_SCRATCH, ASN_SGRAD, 
                          ASN_WEIGHT, ASN_WGRAD, ASN_BIAS, ASN_BGRAD, ASN_INPUT, 
                          ASN_OUTPUT, GET_OUTPUT} mm_state;

typedef enum logic [5:0] {LINEAR, CONV, FLATTEN, MAXPOOL, RELU, SOFTMAX, MSE} layer_opcode;


`endif
