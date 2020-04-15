`default_nettype none

`include "fpu/fpu_defines.vh"
`include "model_manager/mmdefine.vh"
`include "memory/mem_handle.vh"

module top();

  logic clk, rst_l;

  mem_handle mh[4:0]();


   // DPR<->MM handshake
   mm_state mm_o;
   layer_opcode asn_opcode;
   mem_handle_t dpr_pass;
   mem_handle_t mm_pass;

   // MM<->FPU handshake
   op_id fpu_op;
   logic fpu_avail;
   logic fpu_done;


  MMU mmu(.*);
  model_manager mm(.clk, .rst_l, .mm_o, .asn_opcode, .dpr_pass, .mm_pass, 
                   .a(mh[3]), .b(mh[2]), .c(mh[1]), .d(mh[0]), .fpu_op,
                   .fpu_avail, .fpu_done);
  FPUBank fpu(.clk, .rst_l, .a(mh[3]), .b(mh[2]), .c(mh[1]), .d(mh[0]),
              .op(fpu_op), .avail(fpu_avail), .done(fpu_done));


endmodule: top

