module m9k_controller(input               clk, w_en, 
                      input  logic [14:0] addr,
                      input  logic [31:0] data_store,
                      output logic [31:0] data_load);

  reg [14:0] M [31:0];

  always_ff @(posedge clk) begin
    if(w_en) begin
      // M9K store
      M[addr] <= data_store;
    end
    else begin
      // M9K read
      data_load <= M[addr];
    end
  end

endmodule: m9k_controller



