.SUFFIXES: .erl .beam .yrl

MODS := $(wildcard *.erl)
CWD := $(shell pwd)

%.beam: %.erl
	erlc  -W $<

%.html: %.erl
	./erl2html $<

all: beam blog

blog:
	(sleep 1 && ../../../js/openurl http://localhost:2068/mini7.html) &		
	erl -pa ../../bin -s my_simple_server start 2068 `pwd` 

beam: ${MODS:%.erl=%.beam}

clean:
	rm -rf *.beam 
	rm -rf *.log *.tmp erl_crash.dump

veryclean:
	make clean
	rm -rf *~ 
 





