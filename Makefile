all: prog

prog: main.hs Automata.hs
	ghc -O2 main.hs -o prog

clean:
	rm -f prog *.o *.hi

.PHONY: all clean
