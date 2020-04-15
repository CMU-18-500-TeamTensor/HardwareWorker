`default_nettype none

`include "fpu/fpu_defines.vh"
`include "model_manager/mmdefine.vh"
`include "memory/mem_handle.vh"

module model_manager
  (input logic   clk, rst_l,

   // DPR<->MM handshake
   input mm_state mm_o,
   input layer_opcode asn_opcode,
   input mem_handle_t dpr_pass,
   output mem_handle_t mm_pass,

   mem_handle a, b, c, d,
   output op_id fpu_op,
   output logic fpu_avail,
   input  logic fpu_done
   );

  enum logic [5:0] {UNASSIGNED, ASN_MODEL, ASN_LAYER, ASN_SCRATCH, ASN_SGRAD, 
                    ASN_WEIGHT, ASN_WGRAD, ASN_BIAS, ASN_BGRAD,
                    ASSIGNED, INPUT, OUTPUT, FORWARD1, FORWARD2, BACKWARD1,
                    BACKWARD2, BACKWARDW1, BACKWARDW2, BACKWARDB1, BACKWARDB2,
                    UPDATE_LOOP, UPDATEW1, UPDATEW2, UPDATEB1, UPDATEB2,
                    INPUT_DONE} state, nextState;

  logic [15:0]      model_id;

  mem_handle_t        model_ptr, sample_ptr, label_ptr;
  logic [15:0][7:0]   layer_opcodes;
  mem_handle_t [15:0] layer_scratch, layer_sgrad, layer_weights, layer_wgrad,
                      layer_bias, layer_bgrad;

  logic [3:0] layer_ctr, num_layers;

  // Next State logic
  always_comb begin
    unique case(state)
      UNASSIGNED: begin
        nextState = (mm_o == ASN_MODEL) ? ASN_MODEL : UNASSIGNED;
      end
      ASN_MODEL: begin
        nextState = (mm_o == ASN_LAYER) ? ASN_LAYER: ((mm_o == WAIT) ? ASSIGNED : ASN_MODEL);
      end
      ASN_LAYER: begin
        nextState = (mm_o == ASN_SCRATCH) ? ASN_SCRATCH : ASN_LAYER;
      end
      ASN_SCRATCH: begin
        // FLATTEN is the only layer that doesn't require extra space to store
        // gradient info
        if(asn_opcode == FLATTEN)
          nextState = ASN_MODEL;
        else
          nextState = (mm_o == ASN_SGRAD) ? ASN_SGRAD: ASN_SCRATCH;
      end
      ASN_SGRAD: begin
        nextState = (mm_o == ASN_WEIGHT) ? ASN_WEIGHT : ASN_SGRAD;
      end
      ASN_WEIGHT: begin
        nextState = (mm_o == ASN_WGRAD) ? ASN_WGRAD: ASN_WEIGHT;
      end
      ASN_WGRAD: begin
        nextState = (mm_o == ASN_BIAS) ? ASN_BIAS : ASN_WGRAD;
      end
      ASN_BIAS: begin
        nextState = (mm_o == ASN_BGRAD) ? ASN_BGRAD : ASN_BIAS;
      end
      ASN_BGRAD: begin
        nextState = (mm_o == ASN_MODEL) ? ASN_MODEL : ASN_BGRAD;
      end
      ASSIGNED: begin
        nextState = (mm_o == ASN_INPUT) ? INPUT : ASSIGNED;
      end
      INPUT: begin
        nextState = (mm_o == ASN_OUTPUT) ? OUTPUT : INPUT;
      end
      OUTPUT: begin
        nextState = FORWARD1;
      end
      FORWARD1: begin
        nextState = (fpu_done) ? FORWARD2 : FORWARD1;
      end
      FORWARD2: begin
        nextState = (layer_ctr == num_layers-1) ? BACKWARD1 : FORWARD1;
      end
      BACKWARD1: begin
        nextState = (fpu_done) ? BACKWARD2 : BACKWARD1;
      end
      BACKWARD2: begin
        if(layer_opcodes[layer_ctr] == LINEAR)
          nextState = BACKWARDW1;
        else
          nextState = (layer_ctr == 0) ? UPDATE_LOOP : BACKWARD1;
      end
      BACKWARDW1: begin
        nextState = (fpu_done) ? BACKWARDW2 : BACKWARDW1;
      end
      BACKWARDW2: begin
        nextState = BACKWARDB1;
      end
      BACKWARDB1: begin
        nextState = (fpu_done) ? BACKWARDB2 : BACKWARDB1;
      end
      BACKWARDB2: begin
        nextState = (layer_ctr == 0) ? UPDATE_LOOP : BACKWARD1;
      end
      UPDATE_LOOP: begin
        if(layer_ctr != num_layers) begin
          if(layer_opcodes[layer_ctr] == LINEAR)
            nextState = UPDATEW1;
          else
            nextState = UPDATE_LOOP;
        end
        else
          nextState = INPUT_DONE;
      end
      UPDATEW1: begin
        nextState = (fpu_done) ? UPDATEW2 : UPDATEW1;
      end
      UPDATEW2: begin
        nextState = UPDATEB1;
      end
      UPDATEB1: begin
        nextState = (fpu_done) ? UPDATEB2 : UPDATEB1;
      end
      UPDATEB2: begin
        nextState = (layer_ctr == 0) ? INPUT_DONE : UPDATE_LOOP;
      end
      INPUT_DONE: begin
        nextState = ASSIGNED;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= UNASSIGNED;

      a.region_begin <= 0;
      a.region_end <= 0;
      
      b.region_begin <= 0;
      b.region_end <= 0;

      c.region_begin <= 0;
      c.region_end <= 0;

      d.region_begin <= 0;
      d.region_end <= 0;

    end
    else begin

      case(state)
        UNASSIGNED: begin
          layer_ctr <= 4'b0000; // -1, will overflow on increment
        end
        ASN_MODEL: begin
          model_ptr <= dpr_pass;
          if(nextState == ASSIGNED)
            num_layers <= layer_ctr+1;
        end
        ASN_LAYER: begin
          layer_opcodes[layer_ctr] <= asn_opcode;
        end
        ASN_SCRATCH: begin
          layer_scratch[layer_ctr] <= dpr_pass;
        end
        ASN_SGRAD: begin
          layer_sgrad[layer_ctr] <= dpr_pass;

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
        INPUT: begin
          layer_ctr <= 0;
          sample_ptr.region_begin <= dpr_pass.region_begin;
          sample_ptr.region_end <= dpr_pass.region_end;
        end
        OUTPUT: begin
          label_ptr.region_begin <= dpr_pass.region_begin;
          label_ptr.region_end <= dpr_pass.region_end;
        end
        FORWARD1: begin
          fpu_avail <= 1;
          // LINEAR, CONV, FLATTEN, MAXPOOL, RELU, SOFTMAX
          case(layer_opcodes[layer_ctr])
            LINEAR: begin
              fpu_op <= LINEAR_FW;

              // a = W, b = x, c = b, d = z
              a.region_begin <= layer_weights[layer_ctr].region_begin; 
              a.region_end  <= layer_weights[layer_ctr].region_end;

              if(layer_ctr == 0) begin
                b.region_begin <= sample_ptr.region_begin;
                b.region_end <= sample_ptr.region_end;
              end
              else begin
                b.region_begin <= layer_scratch[layer_ctr-1].region_begin;
                b.region_end <= layer_scratch[layer_ctr-1].region_end;
              end
              
              c.region_begin <= layer_bias[layer_ctr].region_begin;
              c.region_end <= layer_bias[layer_ctr].region_end;

              d.region_begin <= layer_scratch[layer_ctr].region_begin;
              d.region_end <= layer_scratch[layer_ctr].region_end;
            end
            RELU: begin
              fpu_op <= RELU_FW;

              // a = x, b = , c = , d = z
              if(layer_ctr == 0) begin
                a.region_begin <= sample_ptr.region_begin;
                a.region_end <= sample_ptr.region_end;
              end
              else begin
                a.region_begin <= layer_scratch[layer_ctr-1].region_begin;
                a.region_end <= layer_scratch[layer_ctr-1].region_end;
              end
            
              d.region_begin <= layer_scratch[layer_ctr].region_begin;
              d.region_end <= layer_scratch[layer_ctr].region_end;
            end
          endcase
        end
        FORWARD2: begin
          fpu_avail <= 0;
          
          if(nextState == BACKWARD1)
            layer_ctr <= num_layers - 1;
          else
            layer_ctr <= layer_ctr + 1;
        end
        BACKWARD1: begin
          fpu_avail <= (layer_ctr == 0) ? 0 : 1;
          case(layer_opcodes[layer_ctr])
            LINEAR: begin
              fpu_op <= LINEAR_BW;

              // a = dLdz, b = W, c = x, d = dLdx
              a.region_begin <= layer_sgrad[layer_ctr].region_begin;
              a.region_end  <= layer_sgrad[layer_ctr].region_end;

              b.region_begin <= layer_weights[layer_ctr].region_begin;
              b.region_end <= layer_weights[layer_ctr].region_end;

              c.region_begin <= layer_scratch[layer_ctr-1].region_begin;
              c.region_end <= layer_scratch[layer_ctr-1].region_end;

              d.region_begin <= layer_sgrad[layer_ctr-1].region_begin;
              d.region_end <= layer_sgrad[layer_ctr-1].region_end;
            end
            RELU: begin
              fpu_op <= RELU_BW;

              // a = dLdz, b = , c = x, d = dLdx
              a.region_begin <= layer_sgrad[layer_ctr].region_begin;
              a.region_end <= layer_sgrad[layer_ctr].region_end;

              c.region_begin <= layer_scratch[layer_ctr-1].region_begin;
              c.region_end <= layer_scratch[layer_ctr-1].region_end;

              d.region_begin <= layer_sgrad[layer_ctr-1].region_begin;
              d.region_end <= layer_sgrad[layer_ctr-1].region_end;
            end
          endcase
        end
        BACKWARD2: begin
          fpu_avail <= 0;

          if(nextState == BACKWARD1)
            layer_ctr <= layer_ctr - 1;
        end
        BACKWARDW1: begin
          fpu_avail <= 1;
          case(layer_opcodes[layer_ctr])
            LINEAR: begin
              fpu_op <= LINEAR_WGRAD;

              // a = dLdz, b = W, c = x, d = dLdW
              a.region_begin <= layer_sgrad[layer_ctr].region_begin;
              a.region_end  <= layer_sgrad[layer_ctr].region_end;

              b.region_begin <= layer_weights[layer_ctr].region_begin;
              b.region_end <= layer_weights[layer_ctr].region_end;
              
              if(layer_ctr == 0) begin
                c.region_begin <= sample_ptr.region_begin;
                c.region_end <= sample_ptr.region_end;
              end
              else begin
                c.region_begin <= layer_scratch[layer_ctr-1].region_begin;
                c.region_end <= layer_scratch[layer_ctr-1].region_end;
              end

              d.region_begin <= layer_wgrad[layer_ctr].region_begin;
              d.region_end <= layer_wgrad[layer_ctr].region_end;
            end
          endcase
        end
        BACKWARDW2: begin
          fpu_avail <= 0;
        end
        BACKWARDB1: begin
          fpu_avail <= 1;
          case(layer_opcodes[layer_ctr])
            LINEAR: begin
              fpu_op <= LINEAR_BGRAD;
      
              // a = dLdz, b = W, c = x, d = dLdb
              a.region_begin <= layer_sgrad[layer_ctr].region_begin;
              a.region_end  <= layer_sgrad[layer_ctr].region_end;

              b.region_begin <= layer_weights[layer_ctr].region_begin;
              b.region_end <= layer_weights[layer_ctr].region_end;

              if(layer_ctr == 0) begin
                c.region_begin <= sample_ptr.region_begin;
                c.region_end <= sample_ptr.region_end;
              end
              else begin
                c.region_begin <= layer_scratch[layer_ctr-1].region_begin;
                c.region_end <= layer_scratch[layer_ctr-1].region_end;
              end

              d.region_begin <= layer_bgrad[layer_ctr].region_begin;
              d.region_end <= layer_bgrad[layer_ctr].region_end;
            end
          endcase
        end
        BACKWARDB2: begin
          fpu_avail <= 0;
          
          layer_ctr <= layer_ctr - 1;
        end
        UPDATE_LOOP: begin
          if(nextState == UPDATE_LOOP)
            layer_ctr <= layer_ctr + 1;
        end
        UPDATEW1: begin
          fpu_avail <= 1;
          fpu_op <= PARAM_UPDATE;
          
          // a = dLdW, b = , c = , d = W
          a.region_begin <= layer_wgrad[layer_ctr].region_begin;
          a.region_end <= layer_wgrad[layer_ctr].region_end;

          d.region_begin <= layer_weights[layer_ctr].region_begin;
          d.region_end <= layer_weights[layer_ctr].region_end;
        end
        UPDATEW2: begin
          fpu_avail <= 0;
        end
        UPDATEB1: begin
          fpu_avail <= 1;
          fpu_op <= PARAM_UPDATE;

           // a = dLdb, b = , c = , d = b
          a.region_begin <= layer_bgrad[layer_ctr].region_begin;
          a.region_end <= layer_bgrad[layer_ctr].region_end;

          d.region_begin <= layer_bias[layer_ctr].region_begin;
          d.region_end <= layer_bias[layer_ctr].region_end;
        end
        UPDATEB2: begin
          fpu_avail <= 0;
          
          if(nextState == UPDATE_LOOP)
            layer_ctr <= layer_ctr + 1;
        end
      endcase

      state <= nextState;
    end
  end

endmodule

/*
module model_manager_test;

  logic   clk, rst_l;

  // DPR<->MM handshake
  mm_state mm_o;
  layer_opcode asn_opcode;
  mem_handle_t dpr_pass;
  mem_handle_t mm_pass;

  mem_handle a(), b(), c(), d();
  op_id fpu_op;
  logic fpu_avail;
  logic fpu_done;

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
*/
