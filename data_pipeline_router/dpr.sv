`default_nettype none

`include "data_pipeline_router/tpp_opcodes.vh"
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

  enum logic [5:0] {WAIT, PARSE, RD_MFULL, MM_COPY, COPY_MODEL, ASSIGN_MODEL, 
                    ASN_LAYER1, ASN_LAYER1_INTER, ASN_LAYER2, ASN_LAYERSW1, ASN_LAYERSW2, 
                    ASN_LAYERSW1_INTER, ASN_LAYERW1, ASN_LAYERW2, ASN_LAYERB1, ASN_LAYERB2, 
                    ASN_LAYERNW1, ASN_LAYERNW2, ASN_MODEL_DONE, ASSIGN_DP, ASN_LAYERNWINTER,
                    ASN_LAYERWINTER, ASN_LAYERNW2INTER, ASN_MSE1, ASN_MSE2, ASN_MSE3,
                    ASN_MSE4, ASN_INPUTS, ASN_OUTPUTS, ASN_SAMPLE_SPIN} state, nextState;

  enum logic [1:0] {M_WAIT, M_READ, M_COPY, M_UPDATE} memState, nextMemState;

  mem_handle_t sdram_all, sdram_avail, sdram_taken;
  mem_handle_t m9k_all, m9k_avail, m9k_taken;
  mem_handle pkt_dpr(), pkt_copy(), mmu_dpr(), mmu_copy();

  logic copy_access;

  logic [`ADDR_SIZE-1:0] mem_curr;
  logic copy_go, copy_done;

  mem_handle_t model_handle;

  logic [31:0] lyr_opcode, lyr_insize, lyr_outsize, data_len;


  CopyRegion batch_process(.clk, .rst_l,
                           .a(pkt_copy), .d(mmu_copy),
                           .go(copy_go), .done(copy_done));
  
  

  always_comb begin
    pkt.avail = pkt.r_en | pkt.w_en;
    pkt_copy.done = pkt.done;
    pkt_dpr.done = pkt.done;
    pkt_copy.region_end = pkt.region_end;
    pkt_dpr.region_begin = pkt.region_begin;
    pkt_dpr.region_end = pkt.region_end;

    pkt_dpr.data_load = pkt.data_load;
    pkt_copy.data_load = pkt.data_load;

    mmu_dpr.data_load = mmu.data_load;
    mmu_copy.data_load = mmu.data_load;

    mmu_copy.done = mmu.done;
    mmu_dpr.done = mmu.done;

    if (copy_access) begin
      pkt.ptr = pkt_copy.ptr;
      pkt.w_en = pkt_copy.w_en;
      pkt.r_en = pkt_copy.r_en;
      pkt.write_through = pkt_copy.write_through;
      pkt.read_through = pkt_copy.read_through;
      mmu.ptr = mmu_copy.ptr;
      mmu.region_begin = mmu_copy.region_begin;
      mmu.region_end = mmu_copy.region_end;
      mmu.avail = mmu_copy.avail;
      mmu.w_en = mmu_copy.w_en;
      mmu.r_en = mmu_copy.r_en;
      mmu.write_through = mmu_copy.write_through;
      mmu.read_through = mmu_copy.read_through;

      mmu.data_store = mmu_copy.data_store;
    end else begin
      pkt.ptr = pkt_dpr.ptr;
      pkt.w_en = pkt_dpr.w_en;
      pkt.r_en = pkt_dpr.r_en;
      pkt.write_through = pkt_dpr.write_through;
      pkt.read_through = pkt_dpr.read_through;
      mmu.region_begin = mmu_dpr.region_begin;
      mmu.region_end = mmu_dpr.region_end;
      mmu.ptr = mmu_dpr.ptr;
      mmu.avail = mmu_dpr.avail;
      mmu.w_en = mmu_dpr.w_en;
      mmu.r_en = mmu_dpr.r_en;
      mmu.write_through = mmu_dpr.write_through;
      mmu.read_through = mmu_dpr.read_through;

      mmu.data_store = mmu_dpr.data_store;
    end
  end

  // Next State Logic
  always_comb begin
    case (state)
      WAIT: nextState = (pkt_avail) ? PARSE : WAIT;
      PARSE: begin
        if (~pkt.done) begin
          nextState = PARSE;
        end else begin
          case (pkt.data_load)
            OP_ASN_MD: nextState = COPY_MODEL;
            OP_ASN_DP: nextState = ASSIGN_DP;
            OP_M_FULL: nextState = RD_MFULL;
            OP_BATCH:  nextState = ASN_INPUTS;
          endcase
        end
      end
      COPY_MODEL: begin
        if (memState == M_UPDATE) 
          nextState = ASSIGN_MODEL;
        else
          nextState = COPY_MODEL;
      end
      ASSIGN_MODEL:
        nextState = (model_handle.ptr == model_handle.region_end-1) ? ASN_MSE1 : ASN_LAYER1;
      ASN_LAYER1: begin
        nextState = (pkt.done) ? ASN_LAYER1_INTER : ASN_LAYER1;
      end
      ASN_LAYER1_INTER:
        nextState = ASN_LAYER2;
      ASN_LAYER2: begin
        nextState = (lyr_opcode == 1) ? ASN_LAYERSW1 : ASN_LAYERNWINTER;
      end
      ASN_LAYERSW1: begin
        nextState = (pkt.done) ? ASN_LAYERSW1_INTER : ASN_LAYERSW1;
      end
      ASN_LAYERSW1_INTER:
        nextState = ASN_LAYERSW2;
      ASN_LAYERSW2:
        nextState = (pkt.avail) ? ASN_LAYERNWINTER : ASN_LAYERSW2;
      ASN_LAYERWINTER:
        nextState = ASN_LAYERW1;
      ASN_LAYERW1:
        nextState = ASN_LAYERW2;
      ASN_LAYERW2:
        nextState = ASN_LAYERB1;
      ASN_LAYERB1:
        nextState = ASN_LAYERB2;
      ASN_LAYERB2:
        nextState = ASSIGN_MODEL;
      ASN_LAYERNWINTER:
        nextState = ASN_LAYERNW1;
      ASN_LAYERNW1:
        nextState = ASN_LAYERNW2;
      ASN_LAYERNW2:
        nextState = (lyr_opcode == 1) ? ASN_LAYERWINTER : ASN_LAYERNW2INTER;
      ASN_LAYERNW2INTER:
        nextState = ASSIGN_MODEL;
      ASN_MSE1:
        nextState = ASN_MSE2;
      ASN_MSE2:
        nextState = ASN_MSE3;
      ASN_MSE3:
        nextState = ASN_MSE4;
      ASN_MSE4:
        nextState = ASN_MODEL_DONE;
      ASN_MODEL_DONE:
        nextState = (~pkt_avail) ? WAIT : ASN_MODEL_DONE;
      ASN_INPUTS:
        nextState = ASN_OUTPUTS;
      ASN_OUTPUTS:
        nextState = ASN_SAMPLE_SPIN;
      ASN_SAMPLE_SPIN:
        nextState = ASN_MODEL_DONE;
      default: begin
        nextState = WAIT;
      end
    endcase
  end

  always_comb begin
    case (memState)
      M_WAIT: begin
        if (state == COPY_MODEL && ~pkt.done) begin
          nextMemState = M_READ;
        end else begin
          nextMemState = M_WAIT;
        end
      end
      M_READ: begin
        if (pkt.done && ~pkt_dpr.avail) begin
          nextMemState = M_COPY;
        end else begin
          nextMemState = M_READ;
        end
      end
      M_COPY: begin
        if (copy_done) begin
          nextMemState = M_UPDATE;
        end else begin
          nextMemState = M_COPY;
        end
      end
      M_UPDATE: begin
        nextMemState = M_WAIT;
      end
      default: begin
        nextMemState = M_WAIT;
      end
    endcase
  end
  

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
      memState <= M_WAIT;

      done <= 0;

      sdram_all.region_begin <= 0;
      sdram_avail.region_begin <= 0;
      sdram_taken.region_begin <= 0;

      sdram_all.region_end <= `SDRAM_SIZE;
      sdram_avail.region_end <= `SDRAM_SIZE;
      sdram_taken.region_end <= 0;

      m9k_all.region_begin <= 23'h400000;
      m9k_avail.region_begin <= 23'h400000;
      m9k_taken.region_begin <= 23'h400000;

      m9k_all.region_end <= 23'h400000 + `M9K_SIZE;
      m9k_avail.region_end <= 23'h400000 + `M9K_SIZE;
      m9k_taken.region_end <= 23'h400000;

      copy_access <= 1'b0;
      copy_go <= 1'b0;

      mem_curr <= 0;

      pkt_copy.region_begin <= 0;
      mmu_copy.region_begin <= 0;
      mmu_copy.region_end <= 0;
      mmu_dpr.region_begin <= 0;
      mmu_dpr.region_end <= 0;
      pkt_dpr.ptr <= 0;
      pkt_dpr.w_en <= 0;
      pkt_dpr.r_en <= 0;
      pkt_dpr.write_through <= 0;
      pkt_dpr.read_through <= 0;

      copy_access <= 0;

      mm_o <= mm_state'(WAIT);

      lyr_opcode <= 0;
      data_len <= 0;
    end
    else begin
      case(state)
      WAIT: begin
        done <= 0;
        if (nextState == PARSE) begin
          pkt_copy.region_begin <= pkt.region_begin;
          mem_curr <= pkt.region_begin;
          pkt_dpr.ptr <= pkt.region_begin;
          pkt_dpr.r_en <= 1'b1;
        end
      end
      PARSE: begin
        if (nextState != PARSE) begin
          pkt_dpr.r_en <= 1'b0;
          if (nextState == COPY_MODEL) begin
          
          end
          if(nextState == ASSIGN_MODEL) begin
            pkt_dpr.ptr <= pkt.region_begin;
          end
        end
      end
      COPY_MODEL: begin
        copy_access <= 1'b0;
        copy_go <= 1'b0;
        pkt_dpr.r_en <= 1'b0;
        case (nextMemState)
        M_WAIT: begin end
        M_READ: begin
          pkt_dpr.ptr <= pkt.region_begin + 3;
          pkt_dpr.r_en <= 1'b1;
          pkt_dpr.avail <= 1'b1;
          if(pkt.done) begin
            pkt_copy.region_begin <= pkt.region_begin + 4;
            mmu_copy.region_end <= sdram_avail.region_begin + pkt.data_load;
            model_handle.region_end <= sdram_avail.region_begin + pkt.data_load;
          end
          if(pkt.done && pkt_dpr.avail) begin
            pkt_dpr.r_en <= 0;
            pkt_dpr.avail <= 0;
          end
        end
        M_COPY: begin
          copy_access <= 1'b1;
          copy_go <= 1'b1;
          mmu_copy.region_begin <= sdram_avail.region_begin;
          data_len <= pkt.data_load;
          model_handle.region_begin <= sdram_avail.region_begin;
          model_handle.ptr <= sdram_avail.region_begin;
        end
        M_UPDATE: begin
          sdram_avail.region_begin <= sdram_avail.region_begin + data_len;
          sdram_taken.region_end <= sdram_taken.region_end + data_len;
          pkt_dpr.ptr <= pkt.region_begin + 5;
        end
        endcase
      end
      ASSIGN_MODEL: begin
        mm_o <= ASN_MODEL;
      end
      ASN_LAYER1: begin
        pkt_dpr.avail <= 1;
        pkt_dpr.r_en <= 1;

        if(pkt_dpr.done && pkt_dpr.avail) begin
          pkt_dpr.avail <= 0;
          pkt_dpr.r_en <= 0;
          lyr_opcode <= pkt.data_load;
          model_handle.ptr <= model_handle.ptr + 1;
        end
      end
      ASN_LAYER2: begin
        mm_o <= ASN_LAYER;
        if(lyr_opcode == 1) begin      // linear layer
          pkt_dpr.ptr <= pkt_dpr.ptr + 2;      // move pointer to the output size
          asn_opcode <= LINEAR;
        end
        else if(lyr_opcode == 3) begin // ReLU layer
          pkt_dpr.ptr <= pkt_dpr.ptr + 1;  // Move pointer to next layer
          lyr_insize <= lyr_outsize;   // input size is output size of last layer
                                       // output size remains the same
          asn_opcode <= RELU;
        end
      end
      ASN_LAYERSW1: begin
        pkt_dpr.avail <= 1;
        pkt_dpr.r_en <= 1;

        if(pkt_dpr.done && pkt_dpr.avail) begin
          pkt_dpr.avail <= 0;
          pkt_dpr.r_en <= 0;
          lyr_outsize <= pkt.data_load;
          pkt_dpr.ptr <= pkt_dpr.ptr + 1;
        end
      end
      ASN_LAYERSW2: begin
        pkt_dpr.avail <= 1;
        pkt_dpr.r_en <= 1;

        if(pkt_dpr.done && pkt_dpr.avail) begin
          pkt_dpr.avail <= 0;
          pkt_dpr.r_en <= 0;
          lyr_insize <= pkt.data_load;
          pkt_dpr.ptr <= pkt_dpr.ptr + 1;
        end
      end
      ASN_LAYERWINTER: begin
        mm_o <= ASN_WEIGHT;
      end
      ASN_LAYERW1: begin
        // Calculate weight space
        dpr_pass.region_begin <= model_handle.ptr;
        dpr_pass.region_end <= model_handle.ptr + 4 + (lyr_insize * lyr_outsize);
        model_handle.ptr <= model_handle.ptr + 4 + (lyr_insize * lyr_outsize); // Set model pointer to point to bias
        pkt_dpr.ptr <= pkt_dpr.ptr + (lyr_insize * lyr_outsize);
        mm_o <= ASN_WGRAD;
      end
      ASN_LAYERW2: begin
        // Calculate weight gradient space
        dpr_pass.region_begin <= sdram_avail.region_begin;
        dpr_pass.region_end <= sdram_avail.region_begin + 4 + (lyr_insize * lyr_outsize);
        sdram_avail.region_begin <= sdram_avail.region_begin + 4 + (lyr_insize * lyr_outsize);
        mm_o <= ASN_BIAS;
      end
      ASN_LAYERB1: begin
        // Calculate bias space
        dpr_pass.region_begin <= model_handle.ptr;
        dpr_pass.region_end <= model_handle.ptr + 3 + lyr_outsize;
        model_handle.ptr <= model_handle.ptr + 3 + lyr_outsize;
        pkt_dpr.ptr <= pkt_dpr.ptr + 2 + lyr_outsize;
        mm_o <= ASN_BGRAD;
      end
      ASN_LAYERB2: begin
        // Calculate bias gradient space
        dpr_pass.region_begin <= sdram_avail.region_begin;
        dpr_pass.region_end <= sdram_avail.region_begin + 3 + lyr_outsize;
        sdram_avail.region_begin <= sdram_avail.region_begin + 3 + lyr_outsize;
        mm_o <= ASN_MODEL;
      end
      ASN_LAYERNWINTER: begin
        mm_o <= ASN_SCRATCH;
      end
      ASN_LAYERNW1: begin
        // Calculate scratch space
        dpr_pass.region_begin <= sdram_avail.region_begin;
        dpr_pass.region_end <= sdram_avail.region_begin + 3 + lyr_outsize;
        sdram_avail.region_begin <= sdram_avail.region_begin + 3 + lyr_outsize;
        mm_o <= ASN_SGRAD;
      end
      ASN_LAYERNW2: begin
        // Calculate scratch gradient space
        dpr_pass.region_begin <= sdram_avail.region_begin;
        dpr_pass.region_end <= sdram_avail.region_begin + 3 + lyr_insize;
        sdram_avail.region_begin <= sdram_avail.region_begin + 3 + lyr_insize;
        mm_o <= ASN_MODEL;
      end
      ASN_LAYERNW2INTER: begin

      end
      ASN_MSE1: begin
        asn_opcode <= MSE;
        mm_o <= ASN_LAYER;
      end
      ASN_MSE2: begin
        mm_o <= ASN_SCRATCH;
      end
      ASN_MSE3: begin
        // Calculate scratch space
        dpr_pass.region_begin <= sdram_avail.region_begin;
        dpr_pass.region_end <= sdram_avail.region_begin + 3 + lyr_outsize;
        sdram_avail.region_begin <= sdram_avail.region_begin + 3 + lyr_outsize;
        mm_o <= ASN_SGRAD;
      end
      ASN_MSE4: begin
        // Calculate scratch gradient space
        dpr_pass.region_begin <= sdram_avail.region_begin;
        dpr_pass.region_end <= sdram_avail.region_begin + 3 + lyr_outsize;
        sdram_avail.region_begin <= sdram_avail.region_begin + 3 + lyr_outsize;
        mm_o <= ASN_MODEL;
      end
      ASN_MODEL_DONE: begin
        done <= 1;
        mm_o <= mm_state'(WAIT);
      end
      ASN_INPUTS: begin
        mm_o <= mm_state'(ASN_INPUT);
      end
      ASN_OUTPUTS: begin
        // Input ptr
        dpr_pass.region_begin <= 0;
        dpr_pass.region_begin[`ADDR_SIZE-1] <= 1;
        dpr_pass.region_end <= 22;
        dpr_pass.region_end[`ADDR_SIZE-1] <= 1;
        mm_o <= mm_state'(ASN_OUTPUT);
      end
      ASN_SAMPLE_SPIN: begin
        // Output ptr
        dpr_pass.region_begin <= 22;
        dpr_pass.region_begin[`ADDR_SIZE-1] <= 1;
        dpr_pass.region_end <= 34;
        dpr_pass.region_end[`ADDR_SIZE-1] <= 1;
      end
      endcase

      state <= nextState;
      memState <= nextMemState;
    end
  end

endmodule: DPR

