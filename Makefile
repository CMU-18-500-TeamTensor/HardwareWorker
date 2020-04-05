
MMUSRC = memory/cache.sv memory/mport_manager.sv memory/mmu.sv
MMSRC = model_manager/model_manager.sv

SIM = vcs
VCSFLAGS = -sverilog +warn_all

all: mmu modelmanager
.PHONY: all

mmu:
	${SIM} ${VCSFLAGS} ${MMUSRC} -o $@

modelmanager:
	${SIM} ${VCSFLAGS} ${MMSRC} -o $@

clean:
	rm -r csrc *.daidir
	rm simv mmu, model_manager
