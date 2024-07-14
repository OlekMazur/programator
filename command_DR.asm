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
; Copyright (c) 2022, 2024 Aleksander Mazur
;
; Procedura obsługi polecenia DR [begin-address [end-address]]
; Zrzuca zawartość RAM hosta

;-----------------------------------------------------------
; DR [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_DR
endif
command_dump_host_RAM:
	; domyślnie DR 0 7F
	clr A
	mov R2, A
	mov R3, A
	mov R4, A
ifdef	TIMER2	; 8052 ma TIMER2 i 256B RAM-u, 8051 nie ma TIMERa2 i ma 128B RAM-u
	mov R5, #0FFh
else
	mov R5, #7Fh
endif
	acall get_address_range
command_dump_host_RAM_internal:
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_RAM
	ajmp dump_hex_file

cb_dump_RAM:
	mov A, R5
	mov R0, A
	clr C
	ret
