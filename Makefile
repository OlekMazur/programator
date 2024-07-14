# Programator
#
# Copyright (c) 2022, 2024 Aleksander Mazur

PROGRAM=programator
VARIANTS=$(wildcard build-*.asm)
HEX_FILES=$(patsubst %.asm,output/%.hex,$(VARIANTS))
BIN_FILES=$(patsubst %.asm,output/%.bin,$(VARIANTS))
LST_FILES=$(patsubst %.asm,output/%.lst,$(VARIANTS))
ASM_FILES=$(wildcard *.asm)
SRC_FILES=$(filter-out $(VARIANTS),$(ASM_FILES))
ASEM51?=asem -i /usr/local/share/asem-51/1.3/mcu

.PHONY:	all test clean

all:	$(BIN_FILES) $(HEX_FILES)

clean:
	rm $(BIN_FILES) $(HEX_FILES) $(LST_FILES)
	rmdir output

output/%.hex:	%.asm $(SRC_FILES)
	mkdir -p output
	$(ASEM51) $< $@

%.bin:	%.hex
	hexbin $< $@
