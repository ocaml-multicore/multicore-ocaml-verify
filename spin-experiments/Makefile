interp: multicore_gc.pml
	spin -T multicore_gc.pml

ltl:
	# Run as: $ PROP=p0 make ltl
	# See source file for ltl formulae
	# -f is weak fairness. Otherwise, spin wait is rejected.
	spin -T -run -f -ltl $(PROP) -m10000000 multicore_gc.pml

%.exe: %.pml
	spin -a $<
	cc -o $@ pan.c

clean:
	rm -f pan* *.trail *~ *.exe *.tmp
