PROGRAM=hexbin
CFLAGS	+= -Wall -Wextra
LDFLAGS	+= -s

.PHONY:	all clean

all:	$(PROGRAM)

clean:
	rm $(PROGRAM) $(PROGRAM).o

$(PROGRAM):	$(PROGRAM).o

$(PROGRAM).o:	$(PROGRAM).c
