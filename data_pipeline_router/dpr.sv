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

  enum logic [5:0] {WAIT, PARSE, RD_MFULL, MM_COPY, COPY_MODEL, ASSIGN_MODEL, ASN_LAYER1, ASN_LAYER2, ASN_LAYERW1, ASN_LAYERW2, ASN_LAYERB1, ASN_LAYERB2, ASN_LAYERNW1, ASN_LAYERNW2} state, nextState;

  enum logic [1:0] {M_WAIT, M_READ, M_COPY, M_UPDATE} memState, memNextState;

  mem_handle sdram_all, sdram_avail, sdram_taken;
  mem_handle m9k_all, m9k_avail, m9k_taken;
  mem_handle pkt_dpr, pkt_copy, mmu_dpr, mmu_copy;

  logic copy_access;

  logic [`ADDR_SIZE-1:0] mem_curr;
  logic copy_go, copy_done;


  CopyRegion batch_process(.clk, .rst_l,
                           .a(pkt_copy), .d(mmu_copy),
                           .go(copy_go), .done(copy_done));
  
  

  always_comb begin
    pkt.write_through = 1'b0;
    pkt.read_through = 1'b0;
    pkt.avail = pkt.r_en | pkt.w_en;
    pkt_copy.avail = pkt.avail;
    pkt_copy.done = pkt.done;

    mmu.write_through = 1'b0;
    mmu.read_through = 1'b0;
    mmu.avail = mmu.r_en | mmu.w_en;
    mmu_copy.avail = mmu.avail;
    mmu_copy.done = mmu.done;

    if (copy_access) begin
      pkt.ptr = pkt_copy.ptr;
      pkt.w_en = pkt_copy.w_en;
      pkt.r_en = pkt_copy.r_en;
      mmu.ptr = mmu_copy.ptr;
      mmu.w_en = mmu_copy.w_en;
      mmu.r_en = mmu_copy.r_en;
    end else begin
      pkt.ptr = pkt_dpr.ptr;
      pkt.w_en = pkt_dpr.w_en;
      pkt.r_en = pkt_dpr.r_en;
      mmu.ptr = mmu_dpr.ptr;
      mmu.w_en = mmu_dpr.w_en;
      mmu.r_en = mmu_dpr.r_en;
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
          case (data_load)
            OP_ASN_MD: nextState = COPY_MODEL;
            OP_ASN_DP: nextState = ASSIGN_DP;
            OP_M_FULL: nextState = RD_MFULL;
            OP_BATCH:  nextState = MM_COPY;
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
      default: begin
        nextState = WAIT;
      end
    endcase
  end

  always_comb begin
    case (memState)
      M_WAIT: begin
        if (nextState == COPY_MODEL) begin
          nextMemState = M_READ;
        end else begin
          nextMemState = M_WAIT;
        end
      end
      M_READ: begin
        if (pkt.avail && pkt.done) begin
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
        memNextState = M_WAIT;
      end
    endcase
  end
  

  // FSM logic
  always_ff @(posedge clk, negedge rst_l) begin
    if(~rst_l) begin
      state <= WAIT;
      memState <= M_WAIT;

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

      mem_curr <= 0;

      pkt_dpr.ptr <= 0;
      pkt_dpr.w_en <= 0;
      pkt_dpr.r_en <= 0;

      copy_access <= 0;

      mm_o <= WAIT;
    end
    else begin
      case(state)
      WAIT: begin
        if (nextState == PARSE) begin
          mem_curr <= pkt.region_begin;
          pkt.ptr <= pkt.region_begin;
          pkt_dpr.r_en <= 1'b1;
        end
      end
      PARSE: begin
        if (nextState != PARSE) begin
          pkt_dpr.r_en <= 1'b0;
          if (nextState == COPY_MODEL) begin
          
          end
        end
      end
      COPY_MODEL: begin
        copy_access <= 1'b0;
        copy_go <= 1'b0;
        pkt_dpr.r_en <= 1'b0;
        case (memNextState)
        M_WAIT: begin end
        M_READ: begin
          pkt_dpr.ptr <= pkt.region_begin + 3;
          pkt.r_en <= 1'b1;
        end
        M_COPY: begin
          copy_access <= 1'b1;
          copy_go <= 1'b1;
          pkt_copy.region_begin <= pkt.region_begin + 4;
          pkr_copy.region_end <= pkt.region_end;
          mmu.region_begin <= sdram_avail.region_begin;
          mmu.region_end <= sdram_avail.region_begin + pkt.data_load;
          data_len <= pkt.data_load;
        end
        M_UPDATE: begin
          sdram_avail.region_begin <= sdram_avail.region_begin + data_len;
          sdram_taken.region_end <= sdram_taken.region_end + data_len;
        end
        endcase
      end
      ASSIGN_MODEL: begin
        mm_o <= ASN_MODEL;
      end
      ASN_LAYER1: begin
        
      end

      
      endcase

      state <= nextState;
      memState <= memNextState;
    end
  end

endmodule: DPR

