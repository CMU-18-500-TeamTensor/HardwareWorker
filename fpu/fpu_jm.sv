`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"


module FPUJobManager
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   op_id op,
   input  logic avail,
   output logic done,
   output logic [3:0] port_ctr);

  enum logic [5:0] {WAIT, LINEARFW, FLATTENBW, DONE} state, nextState;

 
  // Intermediate registers
  reg [31:0][31:0] r;


  // Linear Forward control FSM
  /*
    input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   inout reg[31:0][31:0] r
  */

  logic lfw_done, lbw_done, ffw_done, fbw_done;
  
  mem_handle lfw_a(), lfw_b(), lfw_c(), lfw_d();
  logic [31:0][31:0] lfw_r;
  LinearForward lf(.clk, .rst_l, .a(lfw_a), .b(lfw_b), .c(lfw_c), .d(lfw_d),
                   .go(state == LINEARFW), .done(lfw_done), .r(lfw_r));

  mem_handle fb_a(), fb_b(), fb_c(), fb_d();
  logic[31:0][31:0] fb_r;
  FlattenBackward fb(.clk, .rst_l, .a(fb_a), .b(fb_b), .c(fb_c), .d(fb_d),
                     .go(state == FLATTENBW), .done(fbw_done), .r(fb_r));


  // register / memory handle multiplexer
  always_comb begin
    case(state)
      LINEARFW: begin
        r = lfw_r;

        lfw_a.region_begin = a.region_begin;
        lfw_a.region_end = a.region_end;
        lfw_a.data_load  = a.data_load;
        lfw_a.done = a.done;
        a.w_en  = lfw_a.w_en;
        a.r_en  = lfw_a.r_en;
        a.avail = lfw_a.avail;
        a.data_store = lfw_a.data_store;
        a.ptr = lfw_a.ptr;

        lfw_b.region_begin = b.region_begin;
        lfw_b.region_end = b.region_end;
        lfw_b.data_load  = b.data_load;
        lfw_b.done = b.done;
        b.w_en  = lfw_b.w_en;
        b.r_en  = lfw_b.r_en;
        b.avail = lfw_b.avail;
        b.data_store = lfw_b.data_store;
        b.ptr = lfw_b.ptr;

        lfw_c.region_begin = c.region_begin;
        lfw_c.region_end = c.region_end;
        lfw_c.data_load  = c.data_load;
        lfw_c.done = c.done;
        c.w_en  = lfw_c.w_en;
        c.r_en  = lfw_c.r_en;
        c.avail = lfw_c.avail;
        c.data_store = lfw_c.data_store;
        c.ptr = lfw_c.ptr;

        lfw_d.region_begin = d.region_begin;
        lfw_d.region_end = d.region_end;
        lfw_d.data_load  = d.data_load;
        lfw_d.done = d.done;
        d.w_en  = lfw_d.w_en;
        d.r_en  = lfw_d.r_en;
        d.avail = lfw_d.avail;
        d.data_store = lfw_d.data_store;
        d.ptr = lfw_d.ptr;
      end
      FLATTENBW: begin
        r = fb_r;

        fb_a.region_begin = a.region_begin;
        fb_a.region_end = a.region_end;
        fb_a.data_load  = a.data_load;
        fb_a.done = a.done;
        a.w_en  = fb_a.w_en;
        a.r_en  = fb_a.r_en;
        a.avail = fb_a.avail;
        a.data_store = fb_a.data_store;
        a.ptr = fb_a.ptr;

        fb_b.region_begin = b.region_begin;
        fb_b.region_end = b.region_end;
        fb_b.data_load  = b.data_load;
        fb_b.done = b.done;
        b.w_en  = fb_b.w_en;
        b.r_en  = fb_b.r_en;
        b.avail = fb_b.avail;
        b.data_store = fb_b.data_store;
        b.ptr = fb_b.ptr;

        fb_c.region_begin = c.region_begin;
        fb_c.region_end = c.region_end;
        fb_c.data_load  = c.data_load;
        fb_c.done = c.done;
        c.w_en  = fb_c.w_en;
        c.r_en  = fb_c.r_en;
        c.avail = fb_c.avail;
        c.data_store = fb_c.data_store;
        c.ptr = fb_c.ptr;

        fb_d.region_begin = d.region_begin;
        fb_d.region_end = d.region_end;
        fb_d.data_load  = d.data_load;
        fb_d.done = d.done;
        d.w_en  = fb_d.w_en;
        d.r_en  = fb_d.r_en;
        d.avail = fb_d.avail;
        d.data_store = fb_d.data_store;
        d.ptr = fb_d.ptr;
      end
      default: begin
        r = 1024'd0;

        a.w_en  = 0;
        a.r_en  = 0;
        a.avail = 0;
        a.data_store = 32'd0;
        a.ptr = 0;

        b.w_en  = 0;
        b.r_en  = 0;
        b.avail = 0;
        b.data_store = 32'd0;
        b.ptr = 0;

        c.w_en  = 0;
        c.r_en  = 0;
        c.avail = 0;
        c.data_store = 32'd0;
        c.ptr = 0;

        d.w_en  = 0;
        d.r_en  = 0;
        d.avail = 0;
        d.data_store = 32'd0;
        d.ptr = 0;
      end
    endcase
  end

  // Next state logic
  always_comb begin
    unique case(state)
      WAIT: begin
        if(avail && op == LINEAR_FW)
          nextState = LINEARFW;
        else if(avail && op == FLATTEN_BW)
          nextState = FLATTENBW;
        else
          nextState = WAIT;
      end
      LINEARFW: begin
        if(lfw_done)
          nextState = DONE;
        else
          nextState = LINEARFW;
      end
      FLATTENBW: begin
        nextState = (fbw_done) ? DONE : FLATTENBW;
      end
      DONE: begin
        if(avail)
          nextState = DONE;
        else
          nextState = WAIT;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
    end
    else begin
      if(nextState == WAIT)
        port_ctr <= port_ctr + 1;

      state <= nextState;
    end
  end

endmodule: FPUJobManager

