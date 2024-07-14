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
; Procedura obsługi polecenia H (Help)
; Podaje listę wszystkich dostępnych komend

;-----------------------------------------------------------
; H
if	USE_HELP_DESC
	dw	s_help_H
endif
command_help:
	bcall ensure_no_args
	clr A
	dec A
	push ACC	; push -1
	mov R0, #input
	clr A
	; A=0 - zaczynamy od początku listy

command_help_next_reset_dptr:
	mov DPTR, #s_commands
command_help_next:
	; A = bieżący offset
	cjne A, #-1, command_help_next_ok
	; offset = -1 -> koniec
	ret

command_help_next_ok:
	mov R2, A
	acall get_next_from_dptr_a
	; R2 = offset za znakiem
	; A = kod znaku na liście przejść stanu
	; A=0 -> koniec komendy
	jz command_help_print_cmd
	; A=-1 -> powrót
	cjne A, #-1, command_help_collect_char
	sjmp command_help_pop

command_help_collect_char:
	mov @R0, A
	inc R0
	; A = offset podlisty
	acall get_next_from_dptr_r2
	push AR2	; zapisujemy offset następnego znaku w tej podliście
	sjmp command_help_next_ok

command_help_print_cmd:
	; wypisujemy, co mamy w input
	mov @R0, #0
	mov R1, #input
command_help_print_cmd_loop:
	mov A, @R1
	jz command_help_print_cmd2
	bcall uart_send_char
	inc R1
	sjmp command_help_print_cmd_loop
command_help_print_cmd2:
if	USE_HELP_DESC
	; sprawdzamy kod realizujący komendę
	acall get_next_from_dptr_r2
	cjne A, #2, command_help_not_ljmp
	; LJMP hh ll - adres bezwzględny jest w dwóch kolejnych bajtach
	acall get_next_from_dptr_r2
	mov R6, A
	acall get_next_from_dptr_r2
	mov R7, A
	sjmp command_help_print_desc
command_help_not_ljmp:
	; czy to AJMP? kody 01h, 21h, 41h, 61h, 81h, A1h, C1h, E1h
	mov R6, A
	anl A, #00011111b
	cjne A, #01h, command_help_not_ajmp
	; 8 najmłodszych bitów adresu jest w drugim bajcie rozkazu
	; 3 kolejne są w najstarszych bitach pierwszego bajtu (które właśnie zamaskowaliśmy)
	; najstarsze bity są takie, jak w punkcie skoku, czyli w DPTR po przejściu za rozkaz
	mov A, R6
	rl A
	rl A
	rl A
	anl A, #00000111b
	mov R6, A
	acall get_next_from_dptr_r2
	mov R7, A
	mov A, DPH
	anl A, #11111000b
	orl A, R6
	mov R6, A
command_help_print_desc:
	mov A, #9	; tab
	bcall uart_send_char
	; w R6:R7 mamy adres docelowy skoku realizującego komendę
	; 2 bajty wcześniej powinien być adres tekstu z krótkim opisem komendy
	clr C
	mov A, R7
	subb A, #2
	mov R7, A
	mov A, R6
	subb A, #0
	mov DPH, A
	mov DPL, R7
	; DPTR := code[DPTR]
	clr A
	movc A, @A + DPTR
	mov R6, A
	mov A, #1
	movc A, @A + DPTR
	mov DPH, R6
	mov DPL, A
	bcall uart_send_rom
command_help_not_ajmp:
endif
	; i enter
	bcall uart_send_crlf
command_help_pop:
	; wracamy poziom wyżej
	dec R0
	pop ACC
if	USE_HELP_DESC
	sjmp command_help_next_reset_dptr
else
	sjmp command_help_next
endif

;-----------------------------------------------------------
; Pobiera bajt spod DPTR+R2 do A i zwiększa R2
; A := code[DPTR + R2++]
get_next_from_dptr_r2:
	mov A, R2
get_next_from_dptr_a:
	movc A, @A + DPTR
	inc R2
	ret
