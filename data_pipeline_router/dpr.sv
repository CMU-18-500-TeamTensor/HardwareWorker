`default_nettype none

`include "model_manager/mmdefine.vh"
`include "memory/mem_handle.vh"


module DPR
  (input logic clk, rst_l,
   mem_handle pkt,
   input logic pkt_avail,
   output logic done,      // Tell the SPI controller that we're done parsing the packet
   
   // Model Manager Handshake
   output mm_state mm_o,
   output layer_opcode asn_opcode,
   output mem_handle_t dpr_pass,
   input mem_handle_t mm_pass,

   mem_handle mmu          // Basic connectivity to the memory architecture
   );

  enum logic {WAIT, PARSE, ASSIGN_MODEL, ASN_LAYER1, ASN_LAYER2, ASN_LAYERW1, ASN_LAYERW2, ASN_LAYERB1, ASN_LAYERB2, ASN_LAYERNW1, ASN_LAYERNW2} state, nextState;


  mem_handle sdram_all, sdram_avail, sdram_taken;
  mem_handle m9k_all, m9k_avail, m9k_taken;

  


  // Next State Logic
  always_comb begin
    
  end
  

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;

      sdram_all.region_begin <= 0;
      sdram_avail.region_begin <= 0;
      sdram_taken.region_begin <= 0;

      m9k_all.region_begin <= 0;
      m9k_avail.region_begin <= 0;
      m9k_taken.region_begin <= 0;
    end
    else begin
      case(state)
      
      endcase

      state <= nextState;
    end
  end

endmodule: DPR

