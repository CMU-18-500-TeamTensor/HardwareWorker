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

  initial begin
    $display("%s, %d, %s", mm.state, mm.layer_scratch[0].region_begin, mmu.mport_inst[0].mp.c.state);
    rst_l <= 0;
    rst_l <= #1 1;
    clk <= 0;

    forever #5 clk <= ~clk;
  end

  initial begin
    forever @(posedge clk)
      $display("%s, %h, %s, %h, %s, %d, %d", mm.state,
               mmu.sdram.M[115:100], fpu.fjm.state, 
               mmu.mport_inst[0].mp.c.M, fpu.fjm.mseb.state,
               mmu.mport_inst[0].mp.mh.region_begin, mmu.mport_inst[0].mp.mh.ptr);
  end

  int i;
  initial begin
    dpr_pass.region_begin <= 0;
    dpr_pass.region_end <= 0;
    mm_o <= WAIT;
    asn_opcode <= SOFTMAX;

    @(posedge clk);
    mm_o <= ASN_MODEL;

    @(posedge clk);
    mm_o <= ASN_LAYER;
    asn_opcode <= LINEAR;

    @(posedge clk);
    mm_o <= ASN_SCRATCH;
    
    @(posedge clk);
    // Scratch space pointer
    dpr_pass.region_begin <= 42;
    dpr_pass.region_end <= 50;
    mm_o <= ASN_SGRAD;

    @(posedge clk);
    // Scratch gradient pointer
    dpr_pass.region_begin <= 50;
    dpr_pass.region_end <= 58;
    mm_o <= ASN_WEIGHT;

    @(posedge clk);
    // Weight pointer
    dpr_pass.region_begin <= 5;
    dpr_pass.region_end <= 34;
    mm_o <= ASN_WGRAD;

    @(posedge clk);
    // Weight gradient pointer
    dpr_pass.region_begin <= 58;
    dpr_pass.region_end <= 87;
    mm_o <= ASN_BIAS;

    @(posedge clk);
    // Bias pointer
    dpr_pass.region_begin <= 34;
    dpr_pass.region_end <= 42;
    mm_o <= ASN_BGRAD;

    @(posedge clk);
    // Bias gradient pointer
    dpr_pass.region_begin <= 87;
    dpr_pass.region_end <= 95;
    mm_o <= ASN_MODEL;
    asn_opcode <= RELU;

    @(posedge clk);
    mm_o <= ASN_LAYER;

    @(posedge clk);
    mm_o <= ASN_SCRATCH;

    @(posedge clk);
    // Scratch pointer
    dpr_pass.region_begin <= 95;
    dpr_pass.region_end <= 103;
    mm_o <= ASN_SGRAD;

    @(posedge clk);
    // Scratch gradient pointer
    dpr_pass.region_begin <= 103;
    dpr_pass.region_end <= 111;
    mm_o <= ASN_MODEL;
    asn_opcode <= MSE;

    @(posedge clk);
    mm_o <= ASN_LAYER;

    @(posedge clk);
    mm_o <= ASN_SCRATCH;

    @(posedge clk);
    // Scratch pointer
    dpr_pass.region_begin <= 111;
    dpr_pass.region_end <= 119;
    mm_o <= ASN_SGRAD;

    @(posedge clk);
    // Scratch gradient pointer
    dpr_pass.region_begin <= 119;
    dpr_pass.region_end <= 127;
    mm_o <= ASN_MODEL;


    @(posedge clk);
    mm_o <= WAIT;

    @(posedge clk);

    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    mm_o <= ASN_INPUT;
 
    @(posedge clk);
    // Input ptr
    dpr_pass.region_begin <= 0;
    dpr_pass.region_begin[`ADDR_SIZE-1] <= 1;
    dpr_pass.region_end <= 7;
    dpr_pass.region_end[`ADDR_SIZE-1] <= 1;
    mm_o <= ASN_OUTPUT;

    @(posedge clk);
    // Output ptr
    dpr_pass.region_begin <= 7;
    dpr_pass.region_begin[`ADDR_SIZE-1] <= 1;
    dpr_pass.region_end <= 14;
    dpr_pass.region_end[`ADDR_SIZE-1] <= 1;
    
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    
    for(i = 0; i < 300; i = i + 1)
      @(posedge clk);
    
    @(posedge mm.state);
    @(posedge clk);

    for(i = 0; i < 300; i = i + 1)
      @(posedge clk);
    @(posedge mm.state);
    
    for(i = 0; i < 100; i = i + 1)
      @(posedge clk);
    @(posedge mm.state);
    @(posedge mm.state);
    @(posedge mm.state);
    @(posedge mm.state);
    @(posedge mm.state);
    $finish;

  end

endmodule: top

