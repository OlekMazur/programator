; This file is part of Programator.
;
; Programator is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; Programator is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with Programator. If not, see <https://www.gnu.org/licenses/>.
;
; Copyright (c) 2022 Aleksander Mazur
;
; Konfiguracja buildu

; I2C - podłączenie AT24CXX
I2C_EEPROM_WP	equ P1.7		; Write Protect (1=protected)
SCL				equ P1.6
SDA				equ P1.5
I2C_EEPROM_A0	equ	P1.4
I2C_EEPROM_A1	equ	P1.3
I2C_EEPROM_A2	equ	P1.2
I2C_EEPROM_GND	equ	P1.1
P1RD_I2C_EEPROM	equ	11100001b	; wpisać do P1 przed odczytem
P1WR_I2C_EEPROM	equ	01100001b	; wpisać do P1 przed zapisem
I2C_EEPROM_ADDR	equ	10100000b	; adres AT24CXX na magistrali I2C

; ICP51 - podłączenie W79EX051
ICP51_RST	equ P1.4
ICP51_CLK	equ P1.7
ICP51_DAT	equ P1.6

; 1-wire
OW_PWR		equ P1.4
OW_DQ		equ P1.3
OW_GND		equ P1.2

; SPI - podłączenie 93X46Y
SPI_EEPROM_PE	equ P1.7		; PE = Program Enable (0=protected; tylko wersja Y=C)
SPI_EEPROM_ORG	equ	P1.6		; organizacja pamięci (tylko wersja Y=C): 0=8-bit (Y=A), 1=16-bit (Y=B)
SPI_EEPROM_GND	equ	P1.5
SPI_CS			equ	P1.4
SPI_CLK			equ	P1.3
SPI_DI			equ	P1.2
SPI_DO			equ	P1.1

; AVR - podłączenie ATtiny2313
AVR_SCK			equ	P1.7
AVR_MISO		equ	P1.6
AVR_MOSI		equ	P1.5
AVR_nRST		equ	P1.4

; konfiguracja buildu
AT89C4051		equ	1
USE_HELP		equ	1
DEBUG			equ	1
ICP51_W79EX051	equ	1
USE_1WIRE		equ	1
USE_I2C			equ	1
USE_SPI			equ	1
USE_AVR			equ	1
