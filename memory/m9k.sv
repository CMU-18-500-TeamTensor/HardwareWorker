`default_nettype none


`include "memory/mem_handle.vh"


module m9k_controller(input               clk, rst_l, w_en, 
                      input  logic [14:0] addr,
                      input  logic [31:0] data_store,
                      output logic [31:0] data_load);

  logic [`M9K_SIZE-1:0][31:0] M;

  assign data_load = M[addr];

  int i;
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      M <= 0;
      M[0] <= 1;
      M[1] <= 5;
      M[2] <= 1;
      M[3] <= 2;
      M[4] <= 3;
      M[5] <= 4;
      M[6] <= 5;
      M[7] <= 1;
      M[8] <= 5;
      M[9] <= 6;
      M[10] <= 7;
      M[11] <= 8;
      M[12] <= 9;
      M[13] <= 10;
    end
    else begin
      if(w_en) begin
        // M9K store
        M[addr] <= data_store;
      end
      else begin
        // M9K read
      end
    end
  end

endmodule: m9k_controller



