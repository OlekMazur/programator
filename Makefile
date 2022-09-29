# Programator
#
# Copyright (c) 2022 Aleksander Mazur

PROGRAM=programator
ASM_FILES=$(wildcard *.asm)
.PHONY:	all clean

all:	$(PROGRAM).bin

clean:
	rm -f $(PROGRAM).bin $(PROGRAM).hex $(PROGRAM).lst

$(PROGRAM).hex $(PROGRAM).lst:	$(ASM_FILES)
	asem -i /usr/local/share/asem-51/1.3/mcu main.asm $(PROGRAM).hex

$(PROGRAM).bin:	$(PROGRAM).hex
	hexbin $< $@
