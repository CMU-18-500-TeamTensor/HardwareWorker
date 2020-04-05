
MMUSRC = memory/cache.sv memory/mport_manager.sv memory/mmu.sv
MMSRC = model_manager/model_manager.sv
FPUSRC = fpu/fpu_jm.sv

SIM = vcs
VCSFLAGS = -sverilog +warn_all

all: mmu modelmanager fpujobmanager
.PHONY: all

mmu:
	${SIM} ${VCSFLAGS} ${MMUSRC} -o $@

modelmanager:
	${SIM} ${VCSFLAGS} ${MMSRC} -o $@

fpujobmanager:
	${SIM} ${VCSFLAGS} ${FPUSRC} -o $@


clean:
	rm -r csrc *.daidir
	rm simv mmu modelmanager fpujobmanager
