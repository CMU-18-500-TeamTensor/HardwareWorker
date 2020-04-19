`default_nettype none

`include "fpu/fpu_defines.vh"
`include "model_manager/mmdefine.vh"
`include "memory/mem_handle.vh"

module top();

  logic clk, rst_l;

  mem_handle mh[5:0]();


  // DPR signals
  mem_handle pkt,
  logic pkt_avail,
  logic dpr_done,

  // DPR<->MM handshake
  mm_state mm_o;
  layer_opcode asn_opcode;
  mem_handle_t dpr_pass;
  mem_handle_t mm_pass;

  // MM<->FPU handshake
  op_id fpu_op;
  logic fpu_avail;
  logic fpu_done;


  DPR dpr(.clk, .rst_l, .pkt, .pkt_avail, .done(dpr_done), .mm_o, .asn_opcode, .dpr_pass, .mm_pass, .mmu(mh[5]));

  MMU mmu(.*);
  model_manager mm(.clk, .rst_l, .mm_o, .asn_opcode, .dpr_pass, .mm_pass, 
                   .a(mh[3]), .b(mh[2]), .c(mh[1]), .d(mh[0]), .fpu_op,
                   .fpu_avail, .fpu_done);
  FPUBank fpu(.clk, .rst_l, .a(mh[3]), .b(mh[2]), .c(mh[1]), .d(mh[0]),
              .op(fpu_op), .avail(fpu_avail), .done(fpu_done));


  // Fake packet memory that pretends to be the SPI interface
  logic [24:0][31:0] fake_pkt;

  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin

      // Assign model packet
      fake_pkt <= 800'h00000000000000030000000300000002000000010000000300000001000000090000000800000007000000060000000500000004000000030000000200000001000000030000000300000002000000010000000200000015000000000000000000000005;
      pkt.region_begin <= 0;
      pkt.region_end <= 25;
      pkt.data_load <= 0;
      pkt.done <= 0;
    end
    else begin
      if(pkt.r_en) begin
        pkt.data_load <= fake_pkt[pkt.ptr];
        pkt.done <= 0;
      end
      else
        pkt.done = 0;
    end
  end

  initial begin
    rst_l <= 0;
    rst_l <= #1 1;
    clk <= 0;

    forever #5 clk <= ~clk;
  end

  initial begin
    forever @(posedge clk)
      $display("%s", mm.state);
  end

  int i;
  initial begin
    pkt_avail <= 0;
    @(posedge clk);
    @(posedge clk);

    pkt_avail <= 1;
    

    @(posedge dpr_done);

    $finish;
  end

endmodule: top

