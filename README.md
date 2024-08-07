[![Build](https://github.com/OlekMazur/programator/actions/workflows/makefile.yml/badge.svg)](https://github.com/OlekMazur/programator/actions/workflows/makefile.yml)

W79EX051/AVR/I²C/SPI USB Programmer
===================================

A programmer built on AT89C4051 with USB-TTL converter (PL2303)
able to read/erase/program:
- W79EX051 (e.g. W79E2051)
- AVR (e.g. ATTiny2313, ATTiny13A)
- I²C EEPROM (e.g. AT24C02)
- SPI EEPROM (e.g. 93C46N)
- 1-wire (e.g. DS18B20, DS1821)

Assembled using [asem-51].

![img-nuvoton]

Schematic
---------

![img-schematic]

PC-side interface
-----------------

The programmer communicates with PC using protocol compatible with
DS89C4X0, which is described in Ultra-High-Speed Flash Microcontroller
User's Guide ([USER GUIDE 4833]), section 15: PROGRAM LOADING.

This is a text-based protocol, so you can use your favourite terminal
program. Memory is loaded, verified and dumped in the Intel HEX format.

Unlike in the mentioned guide, there is no autobaud-rate detection, but
**57600,8,N,1** only. After power on, the programmer waits for `<CR>`,
then prints its welcome message, command prompt and waits for commands.

`CTRL-C` terminates any function currently executed and displays
the command prompt.

Break character (which can be sent from *minicom* with `C-A F`)
restarts the programmer.

Input characters are filtered and echoed back. Accepted are uppercase
letters, digits, colon, space and delete. Backspace is converted to
delete, horizontal tab is converted to space, lowercase letters are
converted to upper case.

Commands
--------

| Command | Arguments | Description |
| ------- | --------- | ----------- |
| H       |           | Prints all supported commands |
| R       |           | Displays values of ports and configurable parameters |
| W P1    | \<byte\>  | Sets output of port P1 |
| W P3    | \<byte\>  | Sets output of port P3, except P3.0 (RXD) and P3.1 (TXD) |
| W PG    | \<byte\>  | Sets mask of adresses inside the same page of I²C EEPROM |
| W RF    | \<byte\>  | Sets code of operation performed by D and V commands |
| 1W1     |           | Restore 1-wire mode (exit thermostate mode) of DS1821 |
| 1W      | \<desc\>  | Reset 1-wire device and transfer raw data |
| I2C     | \<desc\>  | Transfer raw data to/from an I²C device |
| D       | \[\<begin\> \[\<end\>\]\] | Dumps memory of W79EX051 |
| V       |           | Verifies memory of W79EX051 against given Intel HEX data |
| LB      |           | Loads memory of W79EX051 from given Intel HEX data |
| K       | \[\<code\>\] | Clears selected memory of W79EX051 |
| NR      |           | Resets W79EX051 |
| NT      | \<desc\>  | Transfer raw data to/from W79EX051 |
| DX      | \[\<begin\> \[\<end\>\]\] | Dumps contents of I²C EEPROM |
| VX      |           | Verifies contents of I²C EEPROM against given Intel HEX data |
| LX      |           | Loads contents of I²C EEPROM from given Intel HEX data |
| DY      | \[\<begin\> \[\<end\>\]\] | Dumps contents of SPI EEPROM |
| VY      |           | Verifies contents of SPI EEPROM against given Intel HEX data |
| LY      |           | Loads contents of SPI EEPROM from given Intel HEX data |
| DA      | \[\<begin\> \[\<end\>\]\] | Dumps memory of AVR |
| VA      |           | Verifies memory of AVR against given Intel HEX data |
| LA      |           | Loads memory of AVR from given Intel HEX data |
| KA      |           | Clears all memory of AVR |
| DAE     | \[\<begin\> \[\<end\>\]\] | Dumps EEPROM of AVR |
| VAE     |           | Verifies EEPROM of AVR against given Intel HEX data |
| LAE     |           | Loads EEPROM of AVR from given Intel HEX data |
| DR      | \[\<begin\> \[\<end\>\]\] | Dumps RAM content of the programmer |
| VR      |           | Verifies RAM content of the programmer against given Intel HEX data |
| LR      |           | Loads RAM content of the programmer from given Intel HEX data |
| DP      | \[\<begin\> \[\<end\>\]\] | Dumps program of the programmer |

### Command H

Prints all supported commands along with short description.

```
W79EX051/AVR PROGRAMMER VERSION 1.1  Copyright (c) 2022-2024 Aleksander Mazur
> H
H	Print this help
R	Read regs & show config
W P1	Write to P1
W P3	Write to P3
W PG	Set PaGe mask: 7 for AT24C01/2, F for AT24C04 and bigger
W RF	Set Read Flash code used by D&V commands
DX	Dump AT24CXX
DY	Dump 93XXY6Z
DAE	Dump AVR EEPROM
DA	Dump AVR flash
DR	Dump internal RAM
DP	Dump internal flash
D	Dump W79EX051 memory
VX	Verify AT24CXX
VY	Verify 93XXY6Z
VAE	Verify AVR EEPROM
VA	Verify AVR flash
VR	Verify internal RAM
V	Verify W79EX051 memory
LX	Load AT24CXX
LY	Load 93XXY6Z
LAE	Load AVR EEPROM
LA	Load AVR flash
LR	Load internal RAM
LB	Load W79EX051 memory blindly
KA	Klear AVR (Chip Erase)
K	Klear W79EX051: 26=erase all, 22=AP flash (default), 62=NVM
NR	Reset W79EX051 & enter ICP mode
NT	Transfer to/from W79EX051 (no reset): NT 0000S0BRJ FB00S0CRZ RJ
1W1	Exit thermostat mode of DS1821
1W	Transfer to/from 1-wire: 33RRRRRRRR
I2C	Transfer to/from I2C: A000SA1RKRN
```

### Command R

Example:
```
> R
P1:FE P3:BD PG:07 RF:00
```

### Command W P1

Controls pins of DIP-20 socket according to the schematic above, that is:

| P1 bit | Pin | W79EX051 | ATtiny2313 | ATtiny13A | 24CXX | 93CX6 | 1-wire |
| ------:| ---:| -------- | ---------- | --------- | ----- | ----- | ------ |
|      7 |  19 | ICP CLK  | SCK        | SCK       | WP    | PE    |        |
|      6 |  18 | ICP DAT  | MISO       | MISO      | SCL   | ORG   |        |
|      5 |  17 | P1.5     | MOSI       | MOSI      | SDA   | GND   |        |
|      4 |   1 | RST      | nRST       | nRST      | A0    | CS    | VCC    |
|      3 |   2 | RXD      | RXD        | PB3       | A1    | CLK   | DQ     |
|      2 |   3 | TXD      | TXD        | PB4       | A2    | DI    | GND    |
|      1 |   4 | XTAL2    | XTAL2      | GND       | GND   | DO    |        |

### Command W PG

Sets mask of addresses lying within the same page of AT24CXX.
By default 07h = 111b, meaning 8 bytes per page, what is
suitable for AT24C01 and AT24C02.
In case of AT24C04 and bigger it can be set to 0F = 16 bytes per page.
```
> W PG F

> R
P1:FE P3:BF PG:0F RF:00
```

### Command 1W

Syntax of \<desc\>:

| Input | Description |
| ----- | ----------- |
| space | Reset, echo space |
| XX (hex byte) | Send given byte |
| R | Receive one byte |
| W | Receive bits in a loop until 1 arrives |

Examples:
- `1W 33RRRRRRRR` - reset, read ROM code
- `1W CC44W CCBERRRRRRRRR` - reset, initiate temperature conversion,
  wait for completion, reset, read 9 bytes of scratchpad (DS18B20)
- `1W CC4E12341F CCBERRRRRRRRR` - reset, write 3 bytes to scratchpad,
  reset, read 9 bytes of scratchpad (DS18B20)
- `1W CCF08000RRRRRRRRRRRRRRRR` - reset, read 16 bytes @80h (DS2431)

### Command I2C

Syntax of \<desc\>:

| Input | Description |
| ----- | ----------- |
| space | STOP (only if preceded by START); START |
| XX (hex byte) | Send given byte |
| R | Receive one byte |
| S | START |
| K | ACK |
| N | NAK |

STOP is also implicitly sent at the end of the command if there was
START before.

Examples:
- `I2C A000SA1RKRN` - read 2 bytes from AT24C04
- `I2C 86000CD077 C2080C8819A0` - setup TDA9887 & FM1216ME for FM
  stereo reception, tune to 92.3 MHz
- `I2C 86000C3077 C2080C8859A0` - setup TDA9887 & FM1216ME for FM
  mono reception, tune to 92.3 MHz
- `I2C 86S87RKRKRKRKRKRKRKRKRKRKRN` - read status of TDA9887
- `I2C C2SC3RN` - read status of FM1216ME

### Commands D* (dump)

These commands take 2 optional arguments: begin address and end address
(in bytes, hexadecimal, each up to 16 bits) - and dump data
in Intel HEX format.

If arguments are omitted, some reasonable defaults are assumed,
hopefully covering full memory range.

```
> DP 0 3F
:20000000E4F5D0F8F6D8FD148006FFC28CD20032438780758921F58BF58D75884075985084
:20002000802EFF10980710990132C20132859921309A04D20280EFC0E0E5216004D0E08009
:00000001FF
```

If using *minicom*, the dump can be captured to an Intel HEX file using
`C-A L` command.

### Commands V* (verify) and L* (load)

These commands take no arguments. Instead, they process input data
given in Intel HEX format until valid record of type 1 is encountered
(or `CTRL-C` is given). For each record of type 0, appropriate operation
(verify or program) is performed and a response code (single character)
is returned. No new record should be sent to the programmer until it
responds to previous one.

| Code | Meaning |
| ---- | ------- |
| H    | Invalid format of Intel HEX record |
| L    | Intel HEX record too long |
| R    | Invalid type of Intel HEX record |
| S    | Invalid checksum of Intel HEX record |
| F    | Reading or programming failed |
| V    | Verification failed |
| A    | Invalid address in Intel HEX record |
| G    | Good record (verified or programmed successfully) |

If using *minicom*, Intel HEX file can be sent using `C-A Y` command,
but note that *minicom* won't stop sending next records when something
goes wrong. To fully conform with PC-side interface protocol,
a specialized tool like *dsmtk* needs to be used.

### Commands *Y (SPI EEPROM)

The programmer automatically detects memory organization.

| Bits | Chip(s) |
| ----:| ------- |
|    6 | 93XX46B (64x16) |
|    7 | 93XX46A (128x8) |
|    8 | 93XX56B (128x16) or 93XX66B (256x16) |
|    9 | 93XX56A (256x8) or 93XX66A (512x8) |
|   10 | 93XX76B (512x16) or 93XX86B (1024x16) |
|   11 | 93XX76A (1024x8) or 93XX86A (2048x8) |

### Command LA (load AVR program memory)

At the moment it supports only Intel HEX records consisting of whole
memory pages (16 words = 32 bytes) because it first issues
*Load Program Memory Page* command for each byte, and then
*Write Program Memory Page* once per record.

Files can be converted to 32 bytes per record using e.g. *srecord* tool:
```sh
srec_cat --address-length=2 -o output.hex -intel -obs 32 input.hex -intel
```

### Commands *AE (AVR EEPROM)

These commands support dumping, verifying and programming AVR's
EEPROM and other similarly organized memory spaces. Accessed memory
depends on most significant bits of virtual address supplied to the
programmer:

| Offset | Memory space |
| ------:| ------------ |
|   30XX | Signature Byte |
|   38XX | Calibration Byte |
|   50XX | Fuse Bits |
|   54XX | Extended Fuse Bits |
|   58XX | Lock Bits |
|   5CXX | Fuse High Bits |
|   A0XX | EEPROM Memory |

Adresses 00XX are mapped to A0XX so that EEPROM dumps don't need to
have A000h offset.

Example - dump 4 bytes of signature of ATtiny13A:
```
> DAE 3000 3003
:043000001E9007FF18
:00000001FF
```

### Command NT (W79EX051)

Syntax of \<desc\>:

| Input | Description |
| ----- | ----------- |
| XX (hex byte) | Send given value |
| S | Cut most significant bit of the next byte (send only 7 bits of it) |
| R | Receive one byte |
| Z | Send bit 0 |
| J | Send bit 1 |
| L | Send bit 0 slowly |
| H | Send bit 1 slowly |
| space | Reset internal state, echo space |

Example: read signature
```
> NT 0000S0BRJ FB00S0CRZ RJ
 DA 22 03
```
- `NT FB00S00RZ RJ` - read values CONFIG0 and CONFIG1 (can be done with `D FB00 FB01` as well)
- `NT FB00S21XYJ` - set CONFIG0 to XY (can be done with `LB` as well)
- `NT FB01S21XYJ` - set CONFIG1 to XY (can be done with `LB` as well)

Note: this command doesn't reset W79CX051 or enter ICP mode.
(It's enough to do NR, D or V command before.)

### Commands LB, D, V (W79EX051)

Memory map given in datasheet applies, so apart from AP flash,
these commands can be used to access NVM at addresses FC00-FC7F
and configuration bytes at FB00-FB01 (using properly prepared
Intel HEX records).

### Command K (W79EX051)

The command takes an optional argument - code of erase operation
(one byte).

| Command | Memory erased |
| ------- | --------------- |
| `K 26`  | All chip (AP flash, NVM, CONFIG0 & CONFIG1) |
| `K 22`  | Just AP flash |
| `K 62`  | Just NVM |

Code 22h is used by default, so `K` alone clears just the AP flash.

Firmware variants
-----------------

Makefile creates *.hex* and *.bin* files for each *build-XX.asm*.
Currently there are 3 builds defined:

| Variant | Description |
|:-------:| ----------- |
|    4k   | Full-featured firmware for AT89C4051 |
|    2k   | W79EX051/AVR programmer in just 2KB (fits AT89C2051 and W79E2051) |
|    ds   | AT89CX051 programmer; firmware for DS89C4X0 (not documented here) |

License
=======

This file is part of Programator.

Programator is free software: you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

Programator is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the [GNU General Public License]
along with Programator. If not, see <https://www.gnu.org/licenses/>.

[GNU General Public License]: LICENSE.md
[asem-51]: http://plit.de/asem-51
[USER GUIDE 4833]: https://www.maximintegrated.com/en/design/technical-documents/userguides-and-manuals/4/4833.html
[img-nuvoton]: img/programator-w79ex051.jpg
[img-schematic]: img/schematic.png
[programator.zip]: https://olekmazur.github.io/programator/programator.zip
