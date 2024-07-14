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

;; Podłączenie AT89CX051 do DS89C4X0
AT89C_VPP		equ	P0.7	; podanie 0 wystawia 12 V na RST/VPP; jedynka podaje 5 V na RST/VPP
AT89C_XTAL1		equ	P0.1
AT89C_P1		equ	P2		; port P2 dallasa to P1 atmela
AT89C_RDY_BSY	equ	P1.2	; P3.1 atmela
AT89C_PROG		equ	P0.2	; P3.2 atmela
AT89C_ENABLE	equ	P0.4	; P3.4 atmela

P0AT_OP_READ_FLASH	equ	11100101b	; RST/VPP=5V, operacja=read code, P3.2=H, XTAL1=L
P0AT_OP_READ_SIGN	equ	10000101b	; RST/VPP=5V, operacja=read signature, P3.2=H, XTAL1=L
P0AT_OP_ERASE_ALL	equ	10001101b	; RST/VPP=5V, operacja=chip erase, P3.2=H, XTAL1=L
P0AT_OP_WRITE_FLASH	equ	11110101b	; RST/VPP=5V, operacja=write code, P3.2=H, XTAL1=L
