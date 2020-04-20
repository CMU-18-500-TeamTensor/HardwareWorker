
MMUSRC = memory/cache.sv memory/mport_manager.sv memory/mmu.sv memory/m9k.sv
MMSRC = model_manager/model_manager.sv
FPUSRC = fpu/fpubank.sv fpu/fpu_jm.sv fpu/linear_fw.sv fpu/linear_bw.sv fpu/linear_wgrad.sv fpu/linear_bgrad.sv fpu/conv_fw.sv fpu/conv_bw.sv fpu/conv_wgrad.sv fpu/conv_bgrad.sv fpu/maxp_fw.sv fpu/maxp_bw.sv fpu/relu_fw.sv fpu/relu_bw.sv fpu/flatten_fw.sv fpu/flatten_bw.sv fpu/param_update.sv fpu/mse_fw.sv fpu/mse_bw.sv
TOPSRC = top.sv
TOPDPRSRC = top_dpr.sv data_pipeline_router/dpr.sv memory/copy.sv

SIM = vcs
VCSFLAGS = -sverilog +warn_all

all: mmu modelmanager fpujobmanager top
.PHONY: all

mmu:
	${SIM} ${VCSFLAGS} ${MMUSRC} -o $@

modelmanager:
	${SIM} ${VCSFLAGS} ${MMSRC} -o $@

fpujobmanager:
	${SIM} ${VCSFLAGS} ${FPUSRC} -o $@

top:
	${SIM} ${VCSFLAGS} ${MMUSRC} ${MMSRC} ${FPUSRC} ${TOPSRC} -o $@

top_dpr:
	${SIM} ${VCSFLAGS} ${MMUSRC} ${MMSRC} ${FPUSRC} ${TOPDPRSRC} -o $@

clean:
	rm -r csrc *.daidir
	rm simv mmu modelmanager fpujobmanager top top_dpr
