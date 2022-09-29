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
; Procedura obsługi polecenia H (Help)
; Podaje listę wszystkich dostępnych komend

command_help:
	bcall ensure_no_args
	mov DPTR, #s_commands
	clr A
	dec A
	push ACC	; push -1
	mov R0, #input
	clr A
	; A=0 - zaczynamy od początku listy

command_help_next:
	; A = bieżący offset
	cjne A, #-1, command_help_next_ok
	; offset = -1 -> koniec
	ret

command_help_next_ok:
	mov R2, A
	movc A, @A + DPTR
	; A = kod pod bieżącym offsetem
	; A=0 -> koniec komendy
	jz command_help_print_cmd
	; A=-1 -> powrót
	cjne A, #-1, command_help_collect_char
	sjmp command_help_pop

command_help_collect_char:
	mov @R0, A
	inc R0
	inc R2		; R2 = offset za znakiem
	mov A, R2	; A = offset podlisty
	movc A, @A + DPTR
	inc R2
	push AR2	; zapisujemy offset następnego znaku w tej podliście
	sjmp command_help_next_ok

command_help_print_cmd:
	; wypisujemy, co mamy w input
	mov @R0, #0
	mov R1, #input
command_help_print_cmd_loop:
	mov A, @R1
	jz command_help_print_cmd_crlf
	bcall uart_send_char
	inc R1
	sjmp command_help_print_cmd_loop
command_help_print_cmd_crlf:
	; i enter
	bcall uart_send_crlf

command_help_pop:
	; wracamy poziom wyżej
	dec R0
	pop ACC
	sjmp command_help_next

command_help_end:
	ret
