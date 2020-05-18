all: major_slice.exe ephemerons.exe

%.exe: %.pml
	spin -a $<
	cc -o $@ pan.c

clean:
	rm -f pan* *.trail *~ *.exe *.tmp
