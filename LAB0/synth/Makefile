all: synth clean_synth

# This runs synthesis with Design Compiler
synth:
	dc_shell-t  -f  compile_dc.tcl |& tee synth.log

clean_synth:
	\rm -rf *.syn *.pvl *.mr *.svf command.log  WORK

clean:
	\rm -rf csrc DVEFiles simv.daidir simv ucli.key vcdplus.vpd *.syn *.pvl *.mr *.svf command.log *.txt cksum_dir *.log *.rep WORK/

