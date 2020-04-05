`default_nettype none

`include "model_manager/mmdefine.vh"
`include "memory/mem_handle.vh"

module model_manager
  (input logic   clk, rst_l,

   // DPR<->MM handshake
   input logic asn_model, asn_layer, asn_scratch, asn_weight, asn_wgrad, asn_bias, asn_bgrad,
   input layer_opcode asn_opcode,
   input mem_handle_t dpr_pass,
   output mem_handle_t mm_pass
   );

  enum logic [5:0] {UNASSIGNED, ASN_MODEL, ASN_LAYER, ASN_SCRATCH, 
                    ASN_WEIGHT, ASN_WGRAD, ASN_BIAS, ASN_BGRAD,
                    ASSIGNED} state, nextState;

  logic [15:0]      model_id;

  mem_handle_t        model_ptr, sample_ptr;
  logic [15:0][7:0]   layer_opcodes;
  mem_handle_t [15:0] layer_scratch, layer_weights, layer_wgrad, layer_bias,
                      layer_bgrad;

  logic [3:0] layer_ctr;

  // Next State logic
  always_comb begin
    unique case(state)
      UNASSIGNED: begin
        nextState = (asn_model) ? ASN_MODEL : UNASSIGNED;
      end
      ASN_MODEL: begin
        nextState = (asn_layer) ? ASN_LAYER: ASN_MODEL;
      end
      ASN_LAYER: begin
        nextState = (asn_scratch) ? ASN_SCRATCH : ASN_LAYER;
      end
      ASN_SCRATCH: begin
        // FLATTEN is the only layer that doesn't require extra space to store
        // gradient info
        if(asn_opcode == FLATTEN)
          nextState = ASN_LAYER;
        else
          nextState = (asn_weight) ? ASN_WEIGHT: ASN_SCRATCH;
      end
      ASN_WEIGHT: begin
        nextState = (asn_wgrad) ? ASN_WGRAD: ASN_WEIGHT;
      end
      ASN_WGRAD: begin
        nextState = (asn_bias) ? ASN_BIAS : ASN_WGRAD;
      end
      ASN_BIAS: begin
        nextState = (asn_bgrad) ? ASN_BGRAD : ASN_BIAS;
      end
      ASN_BGRAD: begin
        nextState = (asn_layer) ? ASN_LAYER : ASN_BGRAD;
      end
      ASSIGNED: begin
        nextState = ASSIGNED;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= UNASSIGNED;
    end
    else begin

      case(state)
        UNASSIGNED: begin
          layer_ctr <= 4'b1111; // -1, will overflow on increment
        end
        ASN_MODEL: begin
          model_ptr <= dpr_pass;
        end
        ASN_LAYER: begin
          layer_opcodes[layer_ctr] <= asn_opcode;
        end
        ASN_SCRATCH: begin
          layer_scratch[layer_ctr] <= dpr_pass;
       
          if(nextState == ASN_LAYER)
            layer_ctr <= layer_ctr + 1;
        end
        ASN_WEIGHT: begin
          layer_weights[layer_ctr] <= dpr_pass;
        end
        ASN_WGRAD: begin
          layer_wgrad[layer_ctr] <= dpr_pass;
        end
        ASN_BIAS: begin
          layer_bias[layer_ctr] <= dpr_pass;
        end
        ASN_BGRAD: begin
          layer_bgrad[layer_ctr] <= dpr_pass;

          if(nextState == ASN_LAYER) 
            layer_ctr <= layer_ctr + 1;
        end
      endcase

      state <= nextState;
    end
  end

endmodule



