W79EX051/AVR/I²C/SPI USB Programmer
===================================

A programmer built on AT89C4051 with USB-TTL converter (PL2303)
able to read/erase/program:
- W79EX051 (e.g. W79E2051)
- AVR (e.g. ATTiny2313)
- I²C EEPROM (e.g. AT24C02)
- SPI EEPROM (e.g. 93C46N)
- 1-wire (e.g. DS18B20)

Assembled using [asem-51].

![img-top] ![img-bottom] ![img-nuvoton]

Schematic
---------

![img-schematic]

PC-side interface
-----------------

The programmer communicates with PC using protocol compatible with
DS89C4X0, which is described in Ultra-High-Speed Flash Microcontroller
User's Guide ([USER GUIDE 4833]).
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
| WP1     | \<byte\>  | Sets output of port P1 |
| WP3     | \<byte\>  | Sets output of port P3, except P3.0 (RXD) and P3.1 (TXD) |
| WPG     | \<byte\>  | Sets mask of adresses inside the same page of I²C EEPROM |
| WRF     | \<byte\>  | Sets code of operation performed by D and V commands |
| WR      | \<byte\>  | Sets low CLK delay for slow bit transfers to W79EX051 |
| WWL     | \<byte\>  | Sets low CLK delay for transfers to W79EX051 |
| WWH     | \<byte\>  | Sets high CLK delay for transfers to W79EX051 |
| 1WR     | \<send\> \<recv\> | Reset 1-wire device, send some bytes and receive some bytes from it |
| 1W1     |           | Restore 1-wire mode (exit thermostate mode) of DS1821 |
| D       | \[\<addr\> \[\<len\>\]\] | Dumps memory of W79EX051 |
| V       |           | Verifies memory of W79EX051 against given Intel HEX data |
| LB      |           | Loads memory of W79EX051 from given Intel HEX data |
| K       |           | Clears all memory of W79EX051 |
| NR      |           | Resets W79EX051 |
| NT      | \<desc\>  | Performs raw transfer to/from W79EX051 |
| DX      | \[\<addr\> \[\<len\>\]\] | Dumps contents of I²C EEPROM |
| VX      |           | Verifies contents of I²C EEPROM against given Intel HEX data |
| LX      |           | Loads contents of I²C EEPROM from given Intel HEX data |
| DY      | \[\<addr\> \[\<len\>\]\] | Dumps contents of SPI EEPROM |
| VY      |           | Verifies contents of SPI EEPROM against given Intel HEX data |
| LY      |           | Loads contents of SPI EEPROM from given Intel HEX data |
| DA      | \[\<addr\> \[\<len\>\]\] | Dumps memory of AVR |
| VA      |           | Verifies memory of AVR against given Intel HEX data |
| LA      |           | Loads memory of AVR from given Intel HEX data |
| KA      |           | Clears all memory of AVR |
| DAE     | \[\<addr\> \[\<len\>\]\] | Dumps EEPROM of AVR |
| VAE     |           | Verifies EEPROM of AVR against given Intel HEX data |
| LAE     |           | Loads EEPROM of AVR from given Intel HEX data |
| DR      | \[\<addr\> \[\<len\>\]\] | Dumps RAM content of the programmer |
| VR      |           | Verifies RAM content of the programmer against given Intel HEX data |
| LR      |           | Loads RAM content of the programmer from given Intel HEX data |
| DP      | \[\<addr\> \[\<len\>\]\] | Dumps program of the programmer |

### Command R

Example:
```
> R
P1:FE P3:BF PG:07 R:95 WL:05 WH:03 RF:00
```

### Command WP1

Controls pins of DIP-20 socket according to the schematic above, that is:

| P1 bit | Pin | W79EX051 | ATtiny2313 | 24CXX | 93CX6 | 1-wire |
| ------:| ---:| -------- | ---------- | ----- | ----- | ------ |
|      7 |  19 | ICP CLK  | SCK        | WP    | PE    |        |
|      6 |  18 | ICP DAT  | MISO       | SCL   | ORG   |        |
|      5 |  17 | P1.5     | MOSI       | SDA   | GND   |        |
|      4 |   1 | RST      | nRST       | A0    | CS    | GND    |
|      3 |   2 | RXD      | RXD        | A1    | CLK   | DQ     |
|      2 |   3 | TXD      | TXD        | A2    | DI    | VCC    |
|      1 |   4 | XTAL2    | XTAL2      | GND   | DO    |        |

### Command WPG

Mask of addresses lying within the same page of AT24CXX.
By default 07 (hex) = 111 (bin), meaning 8 bytes per page, what is
suitable for AT24C01 and AT24C02.
In case of AT24C04 and bigger it can be set to 0F = 16 bytes per page.
```
> WPG F

> R
P1:FE P3:BF PG:0F R:95 WL:05 WH:03 RF:00
```

### Command 1WR

Reset, send 1 or 2 bytes, then receive given number of bytes.
Examples:
- `1WR 33 8` - Read ROM
- `1WR CC44 0` - Skip ROM, Convert T (DS18B20)
- `1WR CCBE 9` - Skip ROM, Read Scratchpad (DS18B20)

### Commands D* (dump)

These commands take 2 optional arguments (offset and length in bytes;
up to 16 bits both) and dump data in Intel HEX format.

```
> DP 0 40
:20000000E4F5D0F8F6D8FD43878014758921F58BF58D75884075985075A890752207752378
:20002000958001327524057525033109B40DFB900B9C80097581477445313631343111750E
:00000001FF
```

If using *minicom*, the dump can be captured to an Intel HEX file using
`C-A L` command.

### Commands V* (verify) and L* (load)

These commands take no arguments. Instead, they process input data
given in Intel HEX format until valid record of type 1 is encountered
(or CTRL-C is got). For each record of type 0, appropriate operation
(verify or program) is performed and a response code (single character)
is returned. No new record should be sent to the programmer until it
sends a response code to previous one.

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
goes wrong. To conform with PC-side interface protocol, a specialized
tool like *dsmtk* needs to be used.

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
- `NT 0000S2600H` - erase AP flash, NVM, CONFIG0 and CONFIG1 (`K` command does the same)
- `NT 0000S2200H` - erase just AP flash memory
- `NT 0000S6200H` - erase just NVM memory
- `NT FB00S00RZ RJ` - read values CONFIG0 and CONFIG1 (can be done with `D FB00 2` as well)
- `NT FB00S21XYJ` - set CONFIG0 to XY (can be done with `LB` as well)
- `NT FB01S21XYJ` - set CONFIG1 to XY (can be done with `LB` as well)

### Commands LB, D, V (W79EX051)

Program memory map given in datasheet applies, so apart from AP flash,
these commands can be used to access NVM at offsets FC00-FC7F
and configuration bytes at FB00-FB01 (using properly prepared
Intel HEX records).

Test
====

W79E2051
--------

Let's consider a program which initially clears some output pins
and then periodically toggles some other two
(each ~18.2 s if using 11059200 Hz crystal):

```asm
cseg

org RESET

start:
	clr P1.7
	clr RXD
loop:
	cpl P1.6
	cpl TXD
delay:
	djnz R0, delay
	djnz R1, delay
	djnz R2, delay
	sjmp loop

end
```

After assembling we can flash it into W79E2051 with *minicom*:

```
W79EX051/AVR PROGRAMMER VERSION 1.0  Copyright (C) 2022-2024 Aleksander Mazur  
> K

> LB
:10000000C297C2B0B296B2B1D8FED9FCDAFA80F487
:00000001FF
G
> V
:10000000C297C2B0B296B2B1D8FED9FCDAFA80F487
:00000001FF
G
> 
```

Thanks to a connection between XTAL2 of the main microcontroller and
XTAL1 of W79E2051, the latter is provided with external clock so we can
launch the program without taking W79E2051 out of the programmer board,
by just lowering RST pin, and observe effects using `R` command:

```
> R
P1:FE P3:BF PG:07 R:95 WL:05 WH:03 RF:00
> WP1 EF

> R
P1:22 P3:BF PG:07 R:95 WL:05 WH:03 RF:00
> R
P1:66 P3:BF PG:07 R:95 WL:05 WH:03 RF:00
> R
P1:22 P3:BF PG:07 R:95 WL:05 WH:03 RF:00
```

So P1 toggles between 22h and 66h ...

| P1 hex | P1 bin   | P1.7 | P1.6 | P1.3 (RXD) | R1.2 (TXD) |
| ------:| --------:| ----:| ----:| ----------:| ----------:|
|     22 | 00100010 |    0 |    0 |          0 |          0 |
|     66 | 01100110 |    0 |    1 |          0 |          1 |

... meaning that effects of initial `clr P1.7`, `clr RXD` and
periodically repeated `cpl P1.6`, `cpl TXD` are visible.

ATtiny2313
----------

```C
#include <avr/io.h>
#include <util/delay.h>

void start(void)
{
	DDRB = (1 << DDB7) | (1 << DDB6) | (1 << DDB5);
	PORTB = 0x7F;

	for (;;) {
		PORTB ^= 0x60;
		_delay_ms(1000);
	}
}
```

Build it:
```sh
avr-gcc -mmcu=attiny2313 -g -Wall -Wextra -pedantic -DF_CPU=8000000 -Os -nostdlib -nostartfiles avr.c -o avr
avr-objcopy -O ihex avr avr.ihex
```
As mentioned above, the programmer is limited to Intel HEX files with
records containing full memory pages (32 bytes), so we need to convert
```
:1000000080EE87BB8FE788BB90E688B3892788BBE3
:100010002FEF39E688E1215030408040E1F700C001
:040020000000F3CF1A
:00000001FF
```
using e.g. `srecord` tool
```sh
srec_cat --address-length=2 -o avr.hex -intel -obs 32 avr.ihex -intel
```
into
```
:2000000080EE87BB8FE788BB90E688B3892788BB2FEF39E688E1215030408040E1F700C0F4
:040020000000F3CF1A
:00000001FF
```
Now we're ready to go.
```
W79EX051/AVR PROGRAMMER VERSION 1.0  Copyright (C) 2022-2024 Aleksander Mazur
> KA

> LA
GG
> R
P1:2E P3:BF PG:07 R:95 WL:05 WH:03 RF:00
> WP1 FF

> R
P1:1E P3:BF PG:07 R:95 WL:05 WH:03 RF:00
> R
P1:7E P3:BF PG:07 R:95 WL:05 WH:03 RF:00
```

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
[img-top]: img/programator-top.jpg
[img-bottom]: img/programator-bottom.jpg
[img-nuvoton]: img/programator-w79ex051.jpg
[img-schematic]: img/schematic.png
