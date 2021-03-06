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

  enum logic [5:0] {WAIT, LINEARFW, LINEARBW, LINEARWGRAD, LINEARBGRAD,
                    FLATTENFW, FLATTENBW, CONVFW, CONVBW, CONVWGRAD, CONVBGRAD,
                    MAXPFW, MAXPBW, RELUFW, RELUBW, PUPDATE, MSEFW, MSEBW, DONE}
                    state, nextState;

 
  // Intermediate registers
  reg [31:0][31:0] r;


  // Control FSM handshakes look like this:
  /*
    input logic clk, rst_l,
   mem_handle a, b, c, d,
   input logic go,
   output logic done,
   inout reg[31:0][31:0] r
  */


  // Linear Forward
  mem_handle lfw_a(), lfw_b(), lfw_c(), lfw_d();
  logic [31:0][31:0] lfw_r;
  logic lfw_done;
  LinearForward lf(.clk, .rst_l, .a(lfw_a), .b(lfw_b), .c(lfw_c), .d(lfw_d),
                   .go(state == LINEARFW), .done(lfw_done), .r(lfw_r));

  // Linear Backward
  mem_handle lbw_a(), lbw_b(), lbw_c(), lbw_d();
  logic [31:0][31:0] lbw_r;
  logic lbw_done;
  LinearBackward lb(.clk, .rst_l, .a(lbw_a), .b(lbw_b), .c(lbw_c), .d(lbw_d),
                    .go(state == LINEARBW), .done(lbw_done), .r(lbw_r));

  // Linear Weight Gradient
  mem_handle lwg_a(), lwg_b(), lwg_c(), lwg_d();
  logic [31:0][31:0] lwg_r;
  logic lwg_done;
  LinearWeightGradient lwg(.clk, .rst_l, .a(lwg_a), .b(lwg_b), .c(lwg_c), .d(lwg_d), 
                           .go(state == LINEARWGRAD), .done(lwg_done), .r(lwg_r));

  // Linear Bias Gradient
  mem_handle lbg_a(), lbg_b(), lbg_c(), lbg_d();
  logic [31:0][31:0] lbg_r;
  logic lbg_done;
  LinearBiasGradient lbg(.clk, .rst_l, .a(lbg_a), .b(lbg_b), .c(lbg_c), .d(lbg_d),
                         .go(state == LINEARBGRAD), .done(lbg_done), .r(lbg_r));

  // Convolution Forward
  mem_handle cfw_a(), cfw_b(), cfw_c(), cfw_d();
  logic [31:0][31:0] cfw_r;
  logic cfw_done;
  ConvolutionForward cfw(.clk, .rst_l, .a(cfw_a), .b(cfw_b), .c(cfw_c), .d(cfw_d),
                         .go(state == CONVFW), .done(cfw_done), .r(cfw_r));

  // Convolution Backward
  mem_handle cbw_a(), cbw_b(), cbw_c(), cbw_d();
  logic [31:0][31:0] cbw_r;
  logic cbw_done;
  ConvolutionBackward cbw(.clk, .rst_l, .a(cbw_a), .b(cbw_b), .c(cbw_c), .d(cbw_d),
                          .go(state == CONVBW), .done(cbw_done), .r(cbw_r));

  // Convolution Weight Gradient
  mem_handle cwg_a(), cwg_b(), cwg_c(), cwg_d();
  logic [31:0][31:0] cwg_r;
  logic cwg_done;
  ConvolutionWeightGradient cwg(.clk, .rst_l, .a(cwg_a), .b(cwg_b), .c(cwg_c), .d(cwg_d),
                                .go(state == CONVWGRAD), .done(cwg_done), .r(cwg_r));

  // Convolution Bias Gradient
  mem_handle cbg_a(), cbg_b(), cbg_c(), cbg_d();
  logic [31:0][31:0] cbg_r;
  logic cbg_done;
  ConvolutionBiasGradient cbg(.clk, .rst_l, .a(cbg_a), .b(cbg_b), .c(cbg_c), .d(cbg_d),
                              .go(state == CONVBGRAD), .done(cbg_done), .r(cbg_r));

  // MaxPool Forward
  mem_handle mpf_a(), mpf_b(), mpf_c(), mpf_d();
  logic [31:0][31:0] mpf_r;
  logic mpf_done;
  MaxPoolForward mpf(.clk, .rst_l, .a(mpf_a), .b(mpf_b), .c(mpf_c), .d(mpf_d), 
                     .go(state == MAXPFW), .done(mpf_done), .r(mpf_r));

  // MaxPool Backward
  mem_handle mpb_a(), mpb_b(), mpb_c(), mpb_d();
  logic [31:0][31:0] mpb_r;
  logic mpb_done;
  MaxPoolBackward mpb(.clk, .rst_l, .a(mpb_a), .b(mpb_b), .c(mpb_c), .d(mpb_d),
                      .go(state == MAXPBW), .done(mpb_done), .r(mpb_r));

  // ReLU Forward
  mem_handle rfw_a(), rfw_b(), rfw_c(), rfw_d();
  logic [31:0][31:0] rfw_r;
  logic rfw_done;
  ReLUForward rfw(.clk, .rst_l, .a(rfw_a), .b(rfw_b), .c(rfw_c), .d(rfw_d),
                  .go(state == RELUFW), .done(rfw_done), .r(rfw_r));

  // ReLU Backward
  mem_handle rbw_a(), rbw_b(), rbw_c(), rbw_d();
  logic [31:0][31:0] rbw_r;
  logic rbw_done;
  ReLUBackward rbw(.clk, .rst_l, .a(rbw_a), .b(rbw_b), .c(rbw_c), .d(rbw_d),
                   .go(state == RELUBW), .done(rbw_done), .r(rbw_r));

  // Flatten Forward
  mem_handle ff_a(), ff_b(), ff_c(), ff_d();
  logic [31:0][31:0] ff_r;
  logic ff_done;
  FlattenForward ff(.clk, .rst_l, .a(ff_a), .b(ff_b), .c(ff_c), .d(ff_d),
                    .go(state == FLATTENFW), .done(ff_done), .r(ff_r));

  // Flatten Backward
  mem_handle fb_a(), fb_b(), fb_c(), fb_d();
  logic[31:0][31:0] fb_r;
  logic fbw_done;
  FlattenBackward fb(.clk, .rst_l, .a(fb_a), .b(fb_b), .c(fb_c), .d(fb_d),
                     .go(state == FLATTENBW), .done(fbw_done), .r(fb_r));

  // Parameter Update
  mem_handle pu_a(), pu_b(), pu_c(), pu_d();
  logic[31:0][31:0] pu_r;
  logic pu_done;
  ParamUpdate pu(.clk, .rst_l, .a(pu_a), .b(pu_b), .c(pu_c), .d(pu_d),
                     .go(state == PUPDATE), .done(pu_done), .r(pu_r));

  // MSE Forward
  mem_handle msef_a(), msef_b(), msef_c(), msef_d();
  logic[31:0][31:0] msef_r;
  logic msef_done;
  MSEForward msef(.clk, .rst_l, .a(msef_a), .b(msef_b), .c(msef_c), .d(msef_d),
                     .go(state == MSEFW), .done(msef_done), .r(msef_r));

  // MSE Backward
  mem_handle mseb_a(), mseb_b(), mseb_c(), mseb_d();
  logic[31:0][31:0] mseb_r;
  logic mseb_done;
  MSEBackward mseb(.clk, .rst_l, .a(mseb_a), .b(mseb_b), .c(mseb_c), .d(mseb_d),
                     .go(state == MSEBW), .done(mseb_done), .r(mseb_r));

  // register / memory handle multiplexer
  always_comb begin
    case(state)
      LINEARFW: begin
        r = lfw_r;
        done = lfw_done;

        lfw_a.region_begin = a.region_begin;
        lfw_a.region_end = a.region_end;
        lfw_a.data_load  = a.data_load;
        lfw_a.done = a.done;
        a.w_en  = lfw_a.w_en;
        a.r_en  = lfw_a.r_en;
        a.avail = lfw_a.avail;
        a.data_store = lfw_a.data_store;
        a.ptr = lfw_a.ptr;
        a.read_through <= lfw_a.read_through;
        a.write_through <= lfw_a.write_through;


        lfw_b.region_begin = b.region_begin;
        lfw_b.region_end = b.region_end;
        lfw_b.data_load  = b.data_load;
        lfw_b.done = b.done;
        b.w_en  = lfw_b.w_en;
        b.r_en  = lfw_b.r_en;
        b.avail = lfw_b.avail;
        b.data_store = lfw_b.data_store;
        b.ptr = lfw_b.ptr;
        b.read_through <= lfw_b.read_through;
        b.write_through <= lfw_b.write_through;

        lfw_c.region_begin = c.region_begin;
        lfw_c.region_end = c.region_end;
        lfw_c.data_load  = c.data_load;
        lfw_c.done = c.done;
        c.w_en  = lfw_c.w_en;
        c.r_en  = lfw_c.r_en;
        c.avail = lfw_c.avail;
        c.data_store = lfw_c.data_store;
        c.ptr = lfw_c.ptr;
        c.read_through <= lfw_c.read_through;
        c.write_through <= lfw_c.write_through;

        lfw_d.region_begin = d.region_begin;
        lfw_d.region_end = d.region_end;
        lfw_d.data_load  = d.data_load;
        lfw_d.done = d.done;
        d.w_en  = lfw_d.w_en;
        d.r_en  = lfw_d.r_en;
        d.avail = lfw_d.avail;
        d.data_store = lfw_d.data_store;
        d.ptr = lfw_d.ptr;
        d.read_through <= lfw_d.read_through;
        d.write_through <= lfw_d.write_through;
      end
      LINEARBW: begin
        r = lbw_r;
        done = lbw_done;

        lbw_a.region_begin = a.region_begin;
        lbw_a.region_end = a.region_end;
        lbw_a.data_load  = a.data_load;
        lbw_a.done = a.done;
        a.w_en  = lbw_a.w_en;
        a.r_en  = lbw_a.r_en;
        a.avail = lbw_a.avail;
        a.data_store = lbw_a.data_store;
        a.ptr = lbw_a.ptr;
        a.read_through <= lbw_a.read_through;
        a.write_through <= lbw_a.write_through;

        lbw_b.region_begin = b.region_begin;
        lbw_b.region_end = b.region_end;
        lbw_b.data_load  = b.data_load;
        lbw_b.done = b.done;
        b.w_en  = lbw_b.w_en;
        b.r_en  = lbw_b.r_en;
        b.avail = lbw_b.avail;
        b.data_store = lbw_b.data_store;
        b.ptr = lbw_b.ptr;
        b.read_through <= lbw_b.read_through;
        b.write_through <= lbw_b.write_through;

        lbw_c.region_begin = c.region_begin;
        lbw_c.region_end = c.region_end;
        lbw_c.data_load  = c.data_load;
        lbw_c.done = c.done;
        c.w_en  = lbw_c.w_en;
        c.r_en  = lbw_c.r_en;
        c.avail = lbw_c.avail;
        c.data_store = lbw_c.data_store;
        c.ptr = lbw_c.ptr;
        c.read_through <= lbw_c.read_through;
        c.write_through <= lbw_c.write_through;

        lbw_d.region_begin = d.region_begin;
        lbw_d.region_end = d.region_end;
        lbw_d.data_load  = d.data_load;
        lbw_d.done = d.done;
        d.w_en  = lbw_d.w_en;
        d.r_en  = lbw_d.r_en;
        d.avail = lbw_d.avail;
        d.data_store = lbw_d.data_store;
        d.ptr = lbw_d.ptr;
        d.read_through <= lbw_d.read_through;
        d.write_through <= lbw_d.write_through;
      end
      LINEARWGRAD: begin
        r = lwg_r;
        done = lwg_done;

        lwg_a.region_begin = a.region_begin;
        lwg_a.region_end = a.region_end;
        lwg_a.data_load  = a.data_load;
        lwg_a.done = a.done;
        a.w_en  = lwg_a.w_en;
        a.r_en  = lwg_a.r_en;
        a.avail = lwg_a.avail;
        a.data_store = lwg_a.data_store;
        a.ptr = lwg_a.ptr;
        a.read_through <= lwg_a.read_through;
        a.write_through <= lwg_a.write_through;

        lwg_b.region_begin = b.region_begin;
        lwg_b.region_end = b.region_end;
        lwg_b.data_load  = b.data_load;
        lwg_b.done = b.done;
        b.w_en  = lwg_b.w_en;
        b.r_en  = lwg_b.r_en;
        b.avail = lwg_b.avail;
        b.data_store = lwg_b.data_store;
        b.ptr = lwg_b.ptr;
        b.read_through <= lwg_b.read_through;
        b.write_through <= lwg_b.write_through;

        lwg_c.region_begin = c.region_begin;
        lwg_c.region_end = c.region_end;
        lwg_c.data_load  = c.data_load;
        lwg_c.done = c.done;
        c.w_en  = lwg_c.w_en;
        c.r_en  = lwg_c.r_en;
        c.avail = lwg_c.avail;
        c.data_store = lwg_c.data_store;
        c.ptr = lwg_c.ptr;
        c.read_through <= lwg_c.read_through;
        c.write_through <= lwg_c.write_through;

        lwg_d.region_begin = d.region_begin;
        lwg_d.region_end = d.region_end;
        lwg_d.data_load  = d.data_load;
        lwg_d.done = d.done;
        d.w_en  = lwg_d.w_en;
        d.r_en  = lwg_d.r_en;
        d.avail = lwg_d.avail;
        d.data_store = lwg_d.data_store;
        d.ptr = lwg_d.ptr;
        d.read_through <= lwg_d.read_through;
        d.write_through <= lwg_d.write_through;
      end
      LINEARBGRAD: begin
        r = lbg_r;
        done = lbg_done;

        lbg_a.region_begin = a.region_begin;
        lbg_a.region_end = a.region_end;
        lbg_a.data_load  = a.data_load;
        lbg_a.done = a.done;
        a.w_en  = lbg_a.w_en;
        a.r_en  = lbg_a.r_en;
        a.avail = lbg_a.avail;
        a.data_store = lbg_a.data_store;
        a.ptr = lbg_a.ptr;
        a.read_through <= lbg_a.read_through;
        a.write_through <= lbg_a.write_through;

        lbg_b.region_begin = b.region_begin;
        lbg_b.region_end = b.region_end;
        lbg_b.data_load  = b.data_load;
        lbg_b.done = b.done;
        b.w_en  = lbg_b.w_en;
        b.r_en  = lbg_b.r_en;
        b.avail = lbg_b.avail;
        b.data_store = lbg_b.data_store;
        b.ptr = lbg_b.ptr;
        b.read_through <= lbg_b.read_through;
        b.write_through <= lbg_b.write_through;

        lbg_c.region_begin = c.region_begin;
        lbg_c.region_end = c.region_end;
        lbg_c.data_load  = c.data_load;
        lbg_c.done = c.done;
        c.w_en  = lbg_c.w_en;
        c.r_en  = lbg_c.r_en;
        c.avail = lbg_c.avail;
        c.data_store = lbg_c.data_store;
        c.ptr = lbg_c.ptr;
        c.read_through <= lbg_c.read_through;
        c.write_through <= lbg_c.write_through;

        lbg_d.region_begin = d.region_begin;
        lbg_d.region_end = d.region_end;
        lbg_d.data_load  = d.data_load;
        lbg_d.done = d.done;
        d.w_en  = lbg_d.w_en;
        d.r_en  = lbg_d.r_en;
        d.avail = lbg_d.avail;
        d.data_store = lbg_d.data_store;
        d.ptr = lbg_d.ptr;
        d.read_through <= lbg_d.read_through;
        d.write_through <= lbg_d.write_through;
      end
      CONVFW: begin
        r = cfw_r;
        done = cfw_done;

        cfw_a.region_begin = a.region_begin;
        cfw_a.region_end = a.region_end;
        cfw_a.data_load  = a.data_load;
        cfw_a.done = a.done;
        a.w_en  = cfw_a.w_en;
        a.r_en  = cfw_a.r_en;
        a.avail = cfw_a.avail;
        a.data_store = cfw_a.data_store;
        a.ptr = cfw_a.ptr;

        cfw_b.region_begin = b.region_begin;
        cfw_b.region_end = b.region_end;
        cfw_b.data_load  = b.data_load;
        cfw_b.done = b.done;
        b.w_en  = cfw_b.w_en;
        b.r_en  = cfw_b.r_en;
        b.avail = cfw_b.avail;
        b.data_store = cfw_b.data_store;
        b.ptr = cfw_b.ptr;

        cfw_c.region_begin = c.region_begin;
        cfw_c.region_end = c.region_end;
        cfw_c.data_load  = c.data_load;
        cfw_c.done = c.done;
        c.w_en  = cfw_c.w_en;
        c.r_en  = cfw_c.r_en;
        c.avail = cfw_c.avail;
        c.data_store = cfw_c.data_store;
        c.ptr = cfw_c.ptr;

        cfw_d.region_begin = d.region_begin;
        cfw_d.region_end = d.region_end;
        cfw_d.data_load  = d.data_load;
        cfw_d.done = d.done;
        d.w_en  = cfw_d.w_en;
        d.r_en  = cfw_d.r_en;
        d.avail = cfw_d.avail;
        d.data_store = cfw_d.data_store;
        d.ptr = cfw_d.ptr;
      end
      CONVBW: begin
        r = cbw_r;

        cbw_a.region_begin = a.region_begin;
        cbw_a.region_end = a.region_end;
        cbw_a.data_load  = a.data_load;
        cbw_a.done = a.done;
        a.w_en  = cbw_a.w_en;
        a.r_en  = cbw_a.r_en;
        a.avail = cbw_a.avail;
        a.data_store = cbw_a.data_store;
        a.ptr = cbw_a.ptr;

        cbw_b.region_begin = b.region_begin;
        cbw_b.region_end = b.region_end;
        cbw_b.data_load  = b.data_load;
        cbw_b.done = b.done;
        b.w_en  = cbw_b.w_en;
        b.r_en  = cbw_b.r_en;
        b.avail = cbw_b.avail;
        b.data_store = cbw_b.data_store;
        b.ptr = cbw_b.ptr;

        cbw_c.region_begin = c.region_begin;
        cbw_c.region_end = c.region_end;
        cbw_c.data_load  = c.data_load;
        cbw_c.done = c.done;
        c.w_en  = cbw_c.w_en;
        c.r_en  = cbw_c.r_en;
        c.avail = cbw_c.avail;
        c.data_store = cbw_c.data_store;
        c.ptr = cbw_c.ptr;

        cbw_d.region_begin = d.region_begin;
        cbw_d.region_end = d.region_end;
        cbw_d.data_load  = d.data_load;
        cbw_d.done = d.done;
        d.w_en  = cbw_d.w_en;
        d.r_en  = cbw_d.r_en;
        d.avail = cbw_d.avail;
        d.data_store = cbw_d.data_store;
        d.ptr = cbw_d.ptr;
      end
      CONVWGRAD: begin
        r = cwg_r;

        cwg_a.region_begin = a.region_begin;
        cwg_a.region_end = a.region_end;
        cwg_a.data_load  = a.data_load;
        cwg_a.done = a.done;
        a.w_en  = cwg_a.w_en;
        a.r_en  = cwg_a.r_en;
        a.avail = cwg_a.avail;
        a.data_store = cwg_a.data_store;
        a.ptr = cwg_a.ptr;

        cwg_b.region_begin = b.region_begin;
        cwg_b.region_end = b.region_end;
        cwg_b.data_load  = b.data_load;
        cwg_b.done = b.done;
        b.w_en  = cwg_b.w_en;
        b.r_en  = cwg_b.r_en;
        b.avail = cwg_b.avail;
        b.data_store = cwg_b.data_store;
        b.ptr = cwg_b.ptr;

        cwg_c.region_begin = c.region_begin;
        cwg_c.region_end = c.region_end;
        cwg_c.data_load  = c.data_load;
        cwg_c.done = c.done;
        c.w_en  = cwg_c.w_en;
        c.r_en  = cwg_c.r_en;
        c.avail = cwg_c.avail;
        c.data_store = cwg_c.data_store;
        c.ptr = cwg_c.ptr;

        cwg_d.region_begin = d.region_begin;
        cwg_d.region_end = d.region_end;
        cwg_d.data_load  = d.data_load;
        cwg_d.done = d.done;
        d.w_en  = cwg_d.w_en;
        d.r_en  = cwg_d.r_en;
        d.avail = cwg_d.avail;
        d.data_store = cwg_d.data_store;
        d.ptr = cwg_d.ptr;
      end
      CONVBGRAD: begin
        r = cbg_r;

        cbg_a.region_begin = a.region_begin;
        cbg_a.region_end = a.region_end;
        cbg_a.data_load  = a.data_load;
        cbg_a.done = a.done;
        a.w_en  = cbg_a.w_en;
        a.r_en  = cbg_a.r_en;
        a.avail = cbg_a.avail;
        a.data_store = cbg_a.data_store;
        a.ptr = cbg_a.ptr;

        cbg_b.region_begin = b.region_begin;
        cbg_b.region_end = b.region_end;
        cbg_b.data_load  = b.data_load;
        cbg_b.done = b.done;
        b.w_en  = cbg_b.w_en;
        b.r_en  = cbg_b.r_en;
        b.avail = cbg_b.avail;
        b.data_store = cbg_b.data_store;
        b.ptr = cbg_b.ptr;

        cbg_c.region_begin = c.region_begin;
        cbg_c.region_end = c.region_end;
        cbg_c.data_load  = c.data_load;
        cbg_c.done = c.done;
        c.w_en  = cbg_c.w_en;
        c.r_en  = cbg_c.r_en;
        c.avail = cbg_c.avail;
        c.data_store = cbg_c.data_store;
        c.ptr = cbg_c.ptr;

        cbg_d.region_begin = d.region_begin;
        cbg_d.region_end = d.region_end;
        cbg_d.data_load  = d.data_load;
        cbg_d.done = d.done;
        d.w_en  = cbg_d.w_en;
        d.r_en  = cbg_d.r_en;
        d.avail = cbg_d.avail;
        d.data_store = cbg_d.data_store;
        d.ptr = cbg_d.ptr;
      end
      MAXPFW: begin
        r = mpf_r;

        mpf_a.region_begin = a.region_begin;
        mpf_a.region_end = a.region_end;
        mpf_a.data_load  = a.data_load;
        mpf_a.done = a.done;
        a.w_en  = mpf_a.w_en;
        a.r_en  = mpf_a.r_en;
        a.avail = mpf_a.avail;
        a.data_store = mpf_a.data_store;
        a.ptr = mpf_a.ptr;

        mpf_b.region_begin = b.region_begin;
        mpf_b.region_end = b.region_end;
        mpf_b.data_load  = b.data_load;
        mpf_b.done = b.done;
        b.w_en  = mpf_b.w_en;
        b.r_en  = mpf_b.r_en;
        b.avail = mpf_b.avail;
        b.data_store = mpf_b.data_store;
        b.ptr = mpf_b.ptr;

        mpf_c.region_begin = c.region_begin;
        mpf_c.region_end = c.region_end;
        mpf_c.data_load  = c.data_load;
        mpf_c.done = c.done;
        c.w_en  = mpf_c.w_en;
        c.r_en  = mpf_c.r_en;
        c.avail = mpf_c.avail;
        c.data_store = mpf_c.data_store;
        c.ptr = mpf_c.ptr;

        mpf_d.region_begin = d.region_begin;
        mpf_d.region_end = d.region_end;
        mpf_d.data_load  = d.data_load;
        mpf_d.done = d.done;
        d.w_en  = mpf_d.w_en;
        d.r_en  = mpf_d.r_en;
        d.avail = mpf_d.avail;
        d.data_store = mpf_d.data_store;
        d.ptr = mpf_d.ptr;
      end
      MAXPBW: begin
        r = lfw_r;

        mpb_a.region_begin = a.region_begin;
        mpb_a.region_end = a.region_end;
        mpb_a.data_load  = a.data_load;
        mpb_a.done = a.done;
        a.w_en  = mpb_a.w_en;
        a.r_en  = mpb_a.r_en;
        a.avail = mpb_a.avail;
        a.data_store = mpb_a.data_store;
        a.ptr = mpb_a.ptr;

        mpb_b.region_begin = b.region_begin;
        mpb_b.region_end = b.region_end;
        mpb_b.data_load  = b.data_load;
        mpb_b.done = b.done;
        b.w_en  = mpb_b.w_en;
        b.r_en  = mpb_b.r_en;
        b.avail = mpb_b.avail;
        b.data_store = mpb_b.data_store;
        b.ptr = mpb_b.ptr;

        mpb_c.region_begin = c.region_begin;
        mpb_c.region_end = c.region_end;
        mpb_c.data_load  = c.data_load;
        mpb_c.done = c.done;
        c.w_en  = mpb_c.w_en;
        c.r_en  = mpb_c.r_en;
        c.avail = mpb_c.avail;
        c.data_store = mpb_c.data_store;
        c.ptr = mpb_c.ptr;

        mpb_d.region_begin = d.region_begin;
        mpb_d.region_end = d.region_end;
        mpb_d.data_load  = d.data_load;
        mpb_d.done = d.done;
        d.w_en  = mpb_d.w_en;
        d.r_en  = mpb_d.r_en;
        d.avail = mpb_d.avail;
        d.data_store = mpb_d.data_store;
        d.ptr = mpb_d.ptr;
      end
      RELUFW: begin
        r = rfw_r;
        done = rfw_done;

        rfw_a.region_begin = a.region_begin;
        rfw_a.region_end = a.region_end;
        rfw_a.data_load  = a.data_load;
        rfw_a.done = a.done;
        a.w_en  = rfw_a.w_en;
        a.r_en  = rfw_a.r_en;
        a.avail = rfw_a.avail;
        a.data_store = rfw_a.data_store;
        a.ptr = rfw_a.ptr;
        a.read_through <= rfw_a.read_through;
        a.write_through <= rfw_a.write_through;

        rfw_b.region_begin = b.region_begin;
        rfw_b.region_end = b.region_end;
        rfw_b.data_load  = b.data_load;
        rfw_b.done = b.done;
        b.w_en  = rfw_b.w_en;
        b.r_en  = rfw_b.r_en;
        b.avail = rfw_b.avail;
        b.data_store = rfw_b.data_store;
        b.ptr = rfw_b.ptr;
        b.read_through <= rfw_b.read_through;
        b.write_through <= rfw_b.write_through;

        rfw_c.region_begin = c.region_begin;
        rfw_c.region_end = c.region_end;
        rfw_c.data_load  = c.data_load;
        rfw_c.done = c.done;
        c.w_en  = rfw_c.w_en;
        c.r_en  = rfw_c.r_en;
        c.avail = rfw_c.avail;
        c.data_store = rfw_c.data_store;
        c.ptr = rfw_c.ptr;
        c.read_through <= rfw_c.read_through;
        c.write_through <= rfw_c.write_through;

        rfw_d.region_begin = d.region_begin;
        rfw_d.region_end = d.region_end;
        rfw_d.data_load  = d.data_load;
        rfw_d.done = d.done;
        d.w_en  = rfw_d.w_en;
        d.r_en  = rfw_d.r_en;
        d.avail = rfw_d.avail;
        d.data_store = rfw_d.data_store;
        d.ptr = rfw_d.ptr;
        d.read_through <= rfw_d.read_through;
        d.write_through <= rfw_d.write_through;
      end
      RELUBW: begin
        r = rbw_r;
        done = rbw_done;

        rbw_a.region_begin = a.region_begin;
        rbw_a.region_end = a.region_end;
        rbw_a.data_load  = a.data_load;
        rbw_a.done = a.done;
        a.w_en  = rbw_a.w_en;
        a.r_en  = rbw_a.r_en;
        a.avail = rbw_a.avail;
        a.data_store = rbw_a.data_store;
        a.ptr = rbw_a.ptr;
        a.read_through <= rbw_a.read_through;
        a.write_through <= rbw_a.write_through;

        rbw_b.region_begin = b.region_begin;
        rbw_b.region_end = b.region_end;
        rbw_b.data_load  = b.data_load;
        rbw_b.done = b.done;
        b.w_en  = rbw_b.w_en;
        b.r_en  = rbw_b.r_en;
        b.avail = rbw_b.avail;
        b.data_store = rbw_b.data_store;
        b.ptr = rbw_b.ptr;
        b.read_through <= rbw_b.read_through;
        b.write_through <= rbw_b.write_through;

        rbw_c.region_begin = c.region_begin;
        rbw_c.region_end = c.region_end;
        rbw_c.data_load  = c.data_load;
        rbw_c.done = c.done;
        c.w_en  = rbw_c.w_en;
        c.r_en  = rbw_c.r_en;
        c.avail = rbw_c.avail;
        c.data_store = rbw_c.data_store;
        c.ptr = rbw_c.ptr;
        c.read_through <= rbw_c.read_through;
        c.write_through <= rbw_c.write_through;

        rbw_d.region_begin = d.region_begin;
        rbw_d.region_end = d.region_end;
        rbw_d.data_load  = d.data_load;
        rbw_d.done = d.done;
        d.w_en  = rbw_d.w_en;
        d.r_en  = rbw_d.r_en;
        d.avail = rbw_d.avail;
        d.data_store = rbw_d.data_store;
        d.ptr = rbw_d.ptr;
        d.read_through <= rbw_d.read_through;
        d.write_through <= rbw_d.write_through;
      end
      FLATTENFW: begin
        r = ff_r;

        ff_a.region_begin = a.region_begin;
        ff_a.region_end = a.region_end;
        ff_a.data_load  = a.data_load;
        ff_a.done = a.done;
        a.w_en  = ff_a.w_en;
        a.r_en  = ff_a.r_en;
        a.avail = ff_a.avail;
        a.data_store = ff_a.data_store;
        a.ptr = ff_a.ptr;

        ff_b.region_begin = b.region_begin;
        ff_b.region_end = b.region_end;
        ff_b.data_load  = b.data_load;
        ff_b.done = b.done;
        b.w_en  = ff_b.w_en;
        b.r_en  = ff_b.r_en;
        b.avail = ff_b.avail;
        b.data_store = ff_b.data_store;
        b.ptr = ff_b.ptr;

        ff_c.region_begin = c.region_begin;
        ff_c.region_end = c.region_end;
        ff_c.data_load  = c.data_load;
        ff_c.done = c.done;
        c.w_en  = ff_c.w_en;
        c.r_en  = ff_c.r_en;
        c.avail = ff_c.avail;
        c.data_store = ff_c.data_store;
        c.ptr = ff_c.ptr;

        ff_d.region_begin = d.region_begin;
        ff_d.region_end = d.region_end;
        ff_d.data_load  = d.data_load;
        ff_d.done = d.done;
        d.w_en  = ff_d.w_en;
        d.r_en  = ff_d.r_en;
        d.avail = ff_d.avail;
        d.data_store = ff_d.data_store;
        d.ptr = ff_d.ptr;
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
      PUPDATE: begin
        r = pu_r;
        done = pu_done;

        pu_a.region_begin = a.region_begin;
        pu_a.region_end = a.region_end;
        pu_a.data_load  = a.data_load;
        pu_a.done = a.done;
        a.w_en  = pu_a.w_en;
        a.r_en  = pu_a.r_en;
        a.avail = pu_a.avail;
        a.data_store = pu_a.data_store;
        a.ptr = pu_a.ptr;
        a.read_through <= pu_a.read_through;
        a.write_through <= pu_a.write_through;

        pu_b.region_begin = b.region_begin;
        pu_b.region_end = b.region_end;
        pu_b.data_load  = b.data_load;
        pu_b.done = b.done;
        b.w_en  = pu_b.w_en;
        b.r_en  = pu_b.r_en;
        b.avail = pu_b.avail;
        b.data_store = pu_b.data_store;
        b.ptr = pu_b.ptr;
        b.read_through <= pu_b.read_through;
        b.write_through <= pu_b.write_through;

        pu_c.region_begin = c.region_begin;
        pu_c.region_end = c.region_end;
        pu_c.data_load  = c.data_load;
        pu_c.done = c.done;
        c.w_en  = pu_c.w_en;
        c.r_en  = pu_c.r_en;
        c.avail = pu_c.avail;
        c.data_store = pu_c.data_store;
        c.ptr = pu_c.ptr;
        c.read_through <= pu_c.read_through;
        c.write_through <= pu_c.write_through;

        pu_d.region_begin = d.region_begin;
        pu_d.region_end = d.region_end;
        pu_d.data_load  = d.data_load;
        pu_d.done = d.done;
        d.w_en  = pu_d.w_en;
        d.r_en  = pu_d.r_en;
        d.avail = pu_d.avail;
        d.data_store = pu_d.data_store;
        d.ptr = pu_d.ptr;
        d.read_through <= pu_d.read_through;
        d.write_through <= pu_d.write_through;
      end
      MSEFW: begin
        r = msef_r;
        done = msef_done;

        msef_a.region_begin = a.region_begin;
        msef_a.region_end = a.region_end;
        msef_a.data_load  = a.data_load;
        msef_a.done = a.done;
        a.w_en  = msef_a.w_en;
        a.r_en  = msef_a.r_en;
        a.avail = msef_a.avail;
        a.data_store = msef_a.data_store;
        a.ptr = msef_a.ptr;
        a.read_through <= msef_a.read_through;
        a.write_through <= msef_a.write_through;

        msef_b.region_begin = b.region_begin;
        msef_b.region_end = b.region_end;
        msef_b.data_load  = b.data_load;
        msef_b.done = b.done;
        b.w_en  = msef_b.w_en;
        b.r_en  = msef_b.r_en;
        b.avail = msef_b.avail;
        b.data_store = msef_b.data_store;
        b.ptr = msef_b.ptr;
        b.read_through <= msef_b.read_through;
        b.write_through <= msef_b.write_through;

        msef_c.region_begin = c.region_begin;
        msef_c.region_end = c.region_end;
        msef_c.data_load  = c.data_load;
        msef_c.done = c.done;
        c.w_en  = msef_c.w_en;
        c.r_en  = msef_c.r_en;
        c.avail = msef_c.avail;
        c.data_store = msef_c.data_store;
        c.ptr = msef_c.ptr;
        c.read_through <= msef_c.read_through;
        c.write_through <= msef_c.write_through;

        msef_d.region_begin = d.region_begin;
        msef_d.region_end = d.region_end;
        msef_d.data_load  = d.data_load;
        msef_d.done = d.done;
        d.w_en  = msef_d.w_en;
        d.r_en  = msef_d.r_en;
        d.avail = msef_d.avail;
        d.data_store = msef_d.data_store;
        d.ptr = msef_d.ptr;
        d.read_through <= msef_d.read_through;
        d.write_through <= msef_d.write_through;
      end
      MSEBW: begin
        r = mseb_r;
        done = mseb_done;

        mseb_a.region_begin = a.region_begin;
        mseb_a.region_end = a.region_end;
        mseb_a.data_load  = a.data_load;
        mseb_a.done = a.done;
        a.w_en  = mseb_a.w_en;
        a.r_en  = mseb_a.r_en;
        a.avail = mseb_a.avail;
        a.data_store = mseb_a.data_store;
        a.ptr = mseb_a.ptr;
        a.read_through <= mseb_a.read_through;
        a.write_through <= mseb_a.write_through;

        mseb_b.region_begin = b.region_begin;
        mseb_b.region_end = b.region_end;
        mseb_b.data_load  = b.data_load;
        mseb_b.done = b.done;
        b.w_en  = mseb_b.w_en;
        b.r_en  = mseb_b.r_en;
        b.avail = mseb_b.avail;
        b.data_store = mseb_b.data_store;
        b.ptr = mseb_b.ptr;
        b.read_through <= mseb_b.read_through;
        b.write_through <= mseb_b.write_through;

        mseb_c.region_begin = c.region_begin;
        mseb_c.region_end = c.region_end;
        mseb_c.data_load  = c.data_load;
        mseb_c.done = c.done;
        c.w_en  = mseb_c.w_en;
        c.r_en  = mseb_c.r_en;
        c.avail = mseb_c.avail;
        c.data_store = mseb_c.data_store;
        c.ptr = mseb_c.ptr;
        c.read_through <= mseb_c.read_through;
        c.write_through <= mseb_c.write_through;

        mseb_d.region_begin = d.region_begin;
        mseb_d.region_end = d.region_end;
        mseb_d.data_load  = d.data_load;
        mseb_d.done = d.done;
        d.w_en  = mseb_d.w_en;
        d.r_en  = mseb_d.r_en;
        d.avail = mseb_d.avail;
        d.data_store = mseb_d.data_store;
        d.ptr = mseb_d.ptr;
        d.read_through <= mseb_d.read_through;
        d.write_through <= mseb_d.write_through;
      end
      default: begin
        r = 1024'd0;
        done = 0;

        a.w_en  = 0;
        a.r_en  = 0;
        a.avail = 0;
        a.data_store = 32'd0;
        a.ptr = 0;
        a.read_through = 0;
        a.write_through = 0;

        b.w_en  = 0;
        b.r_en  = 0;
        b.avail = 0;
        b.data_store = 32'd0;
        b.ptr = 0;
        b.read_through = 0;
        b.write_through = 0;

        c.w_en  = 0;
        c.r_en  = 0;
        c.avail = 0;
        c.data_store = 32'd0;
        c.ptr = 0;
        c.read_through = 0;
        c.write_through = 0;

        d.w_en  = 0;
        d.r_en  = 0;
        d.avail = 0;
        d.data_store = 32'd0;
        d.ptr = 0;
        d.read_through = 0;
        d.write_through = 0;
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
        else if(avail && op == LINEAR_BW)
          nextState = LINEARBW;
        else if(avail && op == LINEAR_WGRAD)
          nextState = LINEARWGRAD;
        else if(avail && op == LINEAR_BGRAD)
          nextState = LINEARBGRAD;
        else if(avail && op == RELU_FW)
          nextState = RELUFW;
        else if(avail && op == RELU_BW)
          nextState = RELUBW;
        else if(avail && op == PARAM_UPDATE)
          nextState = PUPDATE;
        else if(avail && op == MSE_FW)
          nextState = MSEFW;
        else if(avail && op == MSE_BW)
          nextState = MSEBW;
        else
          nextState = WAIT;
      end
      LINEARFW: begin
        if(lfw_done)
          nextState = DONE;
        else
          nextState = LINEARFW;
      end
      LINEARBW: begin
        if(lbw_done)
          nextState = DONE;
        else
          nextState = LINEARBW;
      end
      LINEARWGRAD: begin
        if(lwg_done)
          nextState = DONE;
        else
          nextState = LINEARWGRAD;
      end
      LINEARBGRAD: begin
        if(lbg_done)
          nextState = DONE;
        else
          nextState = LINEARBGRAD;
      end
      RELUFW: begin
        if(rfw_done)
          nextState = DONE;
        else
          nextState = RELUFW;
      end
      RELUBW: begin
        if(rbw_done)
          nextState = DONE;
        else
          nextState = RELUBW;
      end
      FLATTENBW: begin
        nextState = (fbw_done) ? DONE : FLATTENBW;
      end
      PUPDATE: begin
        if(pu_done)
          nextState = DONE;
        else
          nextState = PUPDATE;
      end
      MSEFW: begin
        if(msef_done)
          nextState = DONE;
        else
          nextState = MSEFW;
      end
      MSEBW: begin
        if(mseb_done)
          nextState = DONE;
        else
          nextState = MSEBW;
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

