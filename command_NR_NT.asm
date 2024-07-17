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
; Procedury obsługi niskopoziomowej komunikacji

;-----------------------------------------------------------
; NT
if	USE_HELP_DESC
	dw	s_help_NT
endif
command_icp51_transfer:
	clr F0				; czy wysłać tylko 7 bitów z następnego bajtu
command_icp51_transfer_loop:
	acall get_hex_or_char
	jnc command_icp51_send_byte
	jnz command_icp51_transfer_next_char
	; C=1, A=0 -> koniec
	ret

command_icp51_send_byte:
	; C=0, A=bajt do wysłania (lub 7 bitów jeśli F0)
	jbc F0, command_icp51_transfer_7bits
	; wysyłamy bajt z A
	acall icp51_send_byte
	sjmp command_icp51_transfer_loop

command_icp51_transfer_7bits:
	; wysyłamy 7 bitów z A
	acall icp51_send_7bits
	sjmp command_icp51_transfer_loop

command_icp51_transfer_next_char:
	; C=1, A=znak
	cjne A, #' ', command_icp51_transfer_not_space
	; spacja wraca do stanu początkowego
	acall uart_send_char	; echo
	sjmp command_icp51_transfer

command_icp51_transfer_not_space:
	cjne A, #'R', command_icp51_transfer_not_R
	; odbieramy bajt
	acall icp51_recv_byte
	acall uart_send_hex_byte
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_R:
	cjne A, #'S', command_icp51_transfer_not_S
	; skraca następny bajt do 7 bitów (obcina najstarszy bit)
	setb F0
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_S:
	cjne A, #'Z', command_icp51_transfer_not_Z
	; wysyłamy bit 0
	clr C
	sjmp command_icp51_send_bit_fast

command_icp51_transfer_not_Z:
	cjne A, #'J', command_icp51_transfer_not_J
	; wysyłamy bit 1
	setb C
command_icp51_send_bit_fast:
	acall icp51_send_bit
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_J:
	cjne A, #'L', command_icp51_transfer_not_L
	; wysyłamy bit 0, ale długo
	clr C
	sjmp command_icp51_send_bit_slow

command_icp51_transfer_not_L:
	cjne A, #'H', command_icp51_transfer_not_H
	; wysyłamy bit 1, ale długo
	setb C
command_icp51_send_bit_slow:
	acall icp51_send_bit_slow
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_H:
	ajmp error_illopt

;-----------------------------------------------------------
; NR
if	USE_HELP_DESC
	dw	s_help_NR
endif
command_icp51_reset:
	acall ensure_no_args
	; jeśli mikrokontroler był już zainicjowany w trybie programowania, to zresetujmy go i zainicjujmy ponownie
	jbc flag_icp51_init, command_icp51_reset2
	sjmp command_icp51_reset_skip
command_icp51_reset2:
	clr ICP51_RST
	acall sleep_timer0_max
	setb ICP51_RST
command_icp51_reset_skip:
	ajmp icp51_init

;-----------------------------------------------------------
error_nothex_fwd:
	acall error_nothex
