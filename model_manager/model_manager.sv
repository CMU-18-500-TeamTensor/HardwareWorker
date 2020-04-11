`default_nettype none

`include "model_manager/mmdefine.vh"
`include "memory/mem_handle.vh"

module model_manager
  (input logic   clk, rst_l,

   // DPR<->MM handshake
   input logic asn_model, asn_layer, asn_scratch, asn_weight, asn_wgrad, asn_bias, asn_bgrad, asn_done,
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
        nextState = (asn_layer) ? ASN_LAYER: ((asn_done) ? ASSIGNED : ASN_MODEL);
      end
      ASN_LAYER: begin
        nextState = (asn_scratch) ? ASN_SCRATCH : ASN_LAYER;
      end
      ASN_SCRATCH: begin
        // FLATTEN is the only layer that doesn't require extra space to store
        // gradient info
        if(asn_opcode == FLATTEN)
          nextState = ASN_MODEL;
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
        nextState = (asn_layer) ? ASN_MODEL : ASN_BGRAD;
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
          layer_ctr <= 4'b0000; // -1, will overflow on increment
        end
        ASN_MODEL: begin
          model_ptr <= dpr_pass;
        end
        ASN_LAYER: begin
          layer_opcodes[layer_ctr] <= asn_opcode;
        end
        ASN_SCRATCH: begin
          layer_scratch[layer_ctr] <= dpr_pass;
       
          if(nextState == ASN_MODEL)
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

          if(nextState == ASN_MODEL) 
            layer_ctr <= layer_ctr + 1;
        end
      endcase

      state <= nextState;
    end
  end

endmodule

module model_manager_test;

  logic   clk, rst_l;

  // DPR<->MM handshake
  logic asn_model, asn_layer, asn_scratch, asn_weight, asn_wgrad, asn_bias, asn_bgrad, asn_done;
  layer_opcode asn_opcode;
  mem_handle_t dpr_pass;
  mem_handle_t mm_pass;

  model_manager mm(.*);


  // LINEAR, CONV, FLATTEN, MAXPOOL, RELU, SOFTMAX

  initial begin
    clk <= 0;
    rst_l <= 0;
    rst_l <= #1 1;

    forever #5 clk <= ~clk;
  end

  initial begin
    dpr_pass.region_begin <= 0;
    asn_model <= 0;
    asn_layer <= 0;
    asn_scratch <= 0;
    asn_weight <= 0;
    asn_wgrad <= 0;
    asn_bias <= 0;
    asn_bgrad <= 0;
    asn_done <= 0;


    @(posedge clk);
    asn_model <= 1;

    @(posedge clk);
    asn_model <= 0;
    dpr_pass.region_begin <= 10;
    asn_layer <= 1;
    asn_opcode <= LINEAR;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);    

    @(posedge clk);
    asn_layer <= 0;
    asn_scratch <= 1;
    dpr_pass.region_begin <= 20;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_scratch <= 0;
    asn_weight <= 1;
    dpr_pass.region_begin <= 30;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_weight <= 0;
    asn_wgrad <= 1;
    dpr_pass.region_begin <= 40;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);
    
    @(posedge clk);
    asn_wgrad <= 0;
    asn_bias <= 1;
    dpr_pass.region_begin <= 50;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_wgrad <= 0;
    asn_bias <= 1;
    dpr_pass.region_begin <= 60;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_bias <= 0;
    asn_bgrad <= 1;
    dpr_pass.region_begin <= 70;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_bgrad <= 0;
    asn_layer <= 1;
    dpr_pass.region_begin <= 80;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_layer <= 0;
    asn_done <= 1;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);

    @(posedge clk);
    asn_done <= 0;
    $display("model manager state = %s, layer_ctr = %d", mm.state, mm.layer_ctr);
    $finish;
  end

endmodule: model_manager_test

