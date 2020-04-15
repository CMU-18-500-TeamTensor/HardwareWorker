module m9k_controller(input               clk, rst_l, w_en, 
                      input  logic [14:0] addr,
                      input  logic [31:0] data_store,
                      output logic [31:0] data_load);

  reg [32767:0] M [31:0];

  always_ff @(posedge clk) begin
    if(~rst_l) begin
      M <= 0;
      M[0] <= 1;
      M[1] <= 10;
      M[2] <= 1;
      M[3] <= 2;
      M[4] <= 3;
      M[5] <= 4;
      M[6] <= 5;
      M[7] <= 6;
      M[8] <= 7;
      M[9] <= 8;
      M[10] <= 9;
      M[11] <= 10;
    end
    else begin
      if(w_en) begin
        // M9K store
        M[addr] <= data_store;
      end
      else begin
        // M9K read
        data_load <= M[addr];
      end
    end
  end

endmodule: m9k_controller



