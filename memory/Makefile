TARGET = simv

SRC = cache.sv mport_manager.sv

SIM = vcs
VCSFLAGS = -sverilog +warn_all

simv:
	${SIM} ${VCSFLAGS} ${SRC}   

clean:
	rm -r csrc simv.daidir
	rm simv
