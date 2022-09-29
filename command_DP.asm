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
; Procedura obsługi polecenia DP [begin-address [end-address]]
; Zrzuca zawartość pamięci programu hosta

command_dump_host_ROM:
	clr A
	mov R2, A
	mov R3, A
	mov R4, #total_program_size shr 8
	mov R5, #total_program_size and 0FFh
	acall get_2_hex_numbers
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_ROM
	ajmp dump_hex_file

cb_dump_ROM:
	mov R0, #input
	mov DPH, R4
	mov DPL, R5
cb_dump_ROM_loop:
	clr A
	movc A, @A + DPTR
	inc DPTR
	mov @R0, A
	inc R0
	djnz R7, cb_dump_ROM_loop
	mov DPTR, #cb_dump_ROM
	sjmp cb_ret_input_OK
