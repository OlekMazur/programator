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
; Copyright (c) 2024 Aleksander Mazur
;
; Konfiguracja buildu dla AT89C2051/W79E2051 (2KB pamięci flash)

$nomod51
$include (89c2051.mcu)

AT89C4051		equ	0
USE_HELP		equ	1
USE_HELP_DESC	equ	0
DEBUG			equ	1
ICP51_W79EX051	equ	1
USE_AT89CX051	equ	0
USE_1WIRE		equ	0
USE_I2C			equ	0
USE_SPI			equ	0
USE_AVR			equ	1

$include (hw-DIP20.asm)
$include (main.asm)
