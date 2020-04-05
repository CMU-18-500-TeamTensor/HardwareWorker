`default_nettype none

`include "fpu/fpu_defines.vh"
`include "memory/mem_handle.vh"

/*
 * FPU Bank
 * Currently only contains one FPU Job Manager. After the interim demo, the 
 * FPU Bank will be redefined to use an array of FPU Job Managers that iterate
 * over an array of ports.
*/
module FPUBank
  (input logic clk, rst_l,
   mem_handle a, b, c, d,
   op_id op,
   input  logic avail,
   output logic done);

  logic [3:0] fpu_jm_portctr;

  FPUJobManager fjm(.clk, .rst_l, .a, .b, .c, .d, .op, .avail, .done, .port_ctr(fpu_jm_portctr));

endmodule: FPUBank



/*
 * FPUBankTest
 * This test will perform a 
*/
module FPUBankTester;

  logic clk, rst_l;
  mem_handle a(), b(), c(), d();
  op_id op;
  logic avail;
  logic done;

  FPUBank fp(.*);

  logic [6:0][31:0]  c_m, d_m; // Output is 5 elements
  logic [4:0][31:0]  b_m;    // Input is 3 elements
  logic [17:0][31:0] a_m;    // Weight matrix is 5 rows by 3 columns

  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin

      // Input
      b_m[0] <= 32'd1;  // 1 dimension
      b_m[1] <= 32'd3;  // 3 elements
      b_m[2] <= 32'd3;
      b_m[3] <= 32'd4;
      b_m[4] <= 32'd5;

      // Bias
      c_m[0] <= 32'd1;  // 1 dimension
      c_m[1] <= 32'd5;  // 5 elements
      c_m[2] <= 32'd11;
      c_m[3] <= 32'd12;
      c_m[4] <= 32'd13;
      c_m[5] <= 32'd14;
      c_m[6] <= 32'd15;

      // Output
      d_m[0] <= 32'd0;  // 1 dimension
      d_m[1] <= 32'd0;  // 5 elements
      d_m[2] <= 32'd0;
      d_m[3] <= 32'd0;
      d_m[4] <= 32'd0;
      d_m[5] <= 32'd0;
      d_m[6] <= 32'd0;

      // Weight
      a_m[0] = 32'd1;  // 1 dimension
      a_m[1] = 32'd5;  // 5 rows
      a_m[2] = 32'd3;  // 3 columns
      a_m[3] = 32'd21;
      a_m[4] = 32'd22;
      a_m[5] = 32'd23;
      a_m[6] = 32'd24;
      a_m[7] = 32'd25;
      a_m[8] = 32'd26;
      a_m[9] = 32'd27;
      a_m[10] = 32'd28;
      a_m[11] = 32'd29;
      a_m[12] = 32'd30;
      a_m[13] = 32'd31;
      a_m[14] = 32'd32;
      a_m[15] = 32'd33;
      a_m[16] = 32'd34;
      a_m[17] = 32'd35;

      a.region_begin <= 23'd0;
      a.region_end <= 23'd0;
      //a.ptr <= 23'd0;
      //a.w_en <= 0;
      //a.r_en <= 0;
      a.write_through <= 0;
      a.read_through <= 0;
      a.data_load <= 0;
      a.done <= 0;

      b.region_begin <= 23'd0;
      b.region_end <= 23'd0;
      //b.ptr <= 23'd0;
      //b.w_en <= 0;
      //b.r_en <= 0;
      b.write_through <= 0;
      b.read_through <= 0;
      b.data_load <= 0;
      b.done <= 0;

      c.region_begin <= 23'd0;
      c.region_end <= 23'd0;
      //c.ptr <= 23'd0;
      //c.w_en <= 0;
      //c.r_en <= 0;
      c.write_through <= 0;
      c.read_through <= 0;
      c.data_load <= 0;
      c.done <= 0;

      d.region_begin <= 23'd0;
      d.region_end <= 23'd0;
      //d.ptr <= 23'd0;
      //d.w_en <= 0;
      //d.r_en <= 0;
      d.write_through <= 0;
      d.read_through <= 0;
      d.data_load <= 0;
      d.done <= 0;

    end
    else begin
      if(a.avail) begin
        if(a.w_en) begin
          a_m[a.ptr] <= a.data_store;
          a.done <= 1;
        end
        if(a.r_en) begin
          a.data_load <= a_m[a.ptr];
          a.done <= 1;
        end
      end
      else begin
        if(a.done) a.done <= 0;
      end

      if(b.avail) begin
        if(b.w_en) begin
          b_m[a.ptr] <= b.data_store;
          b.done <= 1;
        end
        if(b.r_en) begin
          b.data_load <= b_m[b.ptr];
          b.done <= 1;
        end
      end
      else begin
        if(b.done) b.done <= 0;
      end

      if(c.avail) begin
        if(c.w_en) begin
          c_m[c.ptr] <= c.data_store;
          c.done <= 1;
        end
        if(c.r_en) begin
          c.data_load <= c_m[c.ptr];
          c.done <= 1;
        end
      end
      else begin
        if(c.done) c.done <= 0;
      end

      if(d.avail) begin
        if(d.w_en) begin
          d_m[d.ptr] <= d.data_store;
          d.done <= 1;
        end
        if(d.r_en) begin
          d.data_load <= d_m[d.ptr];
          d.done <= 1;
        end
      end
      else begin
        if(d.done) d.done <= 0;
      end
    end
  end


  initial begin
    rst_l = 0;
    rst_l <= #1 1;
    clk = 0;
   
   forever #5 clk = ~clk;
  end


  int i;
  initial begin
    op <= NOOP;
    avail <= 0;
    #25;
    
    op <= LINEAR_FW;
    avail <= 1;

    for(i = 0; i < 165; i = i + 1) begin
      #10;
      $display("dm: %x, state = %s, d.ptr = %x", d_m, fp.fjm.lf.state, fp.fjm.d.ptr);
    end    

    $finish;

  end

endmodule: FPUBankTester

