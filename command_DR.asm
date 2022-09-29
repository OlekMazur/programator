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
; Procedura obsługi polecenia DR [begin-address [end-address]]
; Zrzuca zawartość RAM hosta

command_dump_host_RAM:
	; domyślnie DR 0000 0080
	clr A
	mov R2, A
	mov R3, A
	mov R4, A
	mov R5, #80h
	acall get_2_hex_numbers
command_dump_host_RAM_internal:
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_RAM
	ajmp dump_hex_file

cb_dump_RAM:
	mov A, R5
	mov R0, A
	clr C
	ret
