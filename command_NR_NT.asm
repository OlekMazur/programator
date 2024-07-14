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
	clr flag_7bits
	clr flag_now_lsb	; cały bajt składamy z dwóch cyfr szesnastkowych w R2
command_icp51_transfer_loop:
	mov A, R1
	cjne A, AR0, command_icp51_transfer_next_char
	ret
command_icp51_transfer_next_char:
	; R1 < R0
	mov A, @R1
	inc R1
	cjne A, #' ', command_icp51_transfer_not_space
	; spacja wraca do stanu początkowego
	jb flag_now_lsb, error_nothex_fwd
	acall uart_send_space
	sjmp command_icp51_transfer

command_icp51_transfer_not_space:
	cjne A, #'R', command_icp51_transfer_not_R
	; odbieramy bajt
	jb flag_now_lsb, error_nothex_fwd
	acall icp51_recv_byte
	acall uart_send_hex_byte
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_R:
	cjne A, #'S', command_icp51_transfer_not_S
	; skraca następny bajt do 7 bitów (obcina najstarszy bit)
	jb flag_now_lsb, error_nothex_fwd
	setb flag_7bits
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_S:
	cjne A, #'Z', command_icp51_transfer_not_Z
	; wysyłamy bit 0
	jb flag_now_lsb, error_nothex_fwd
	clr C
	sjmp command_icp51_send_bit_fast

command_icp51_transfer_not_Z:
	cjne A, #'J', command_icp51_transfer_not_J
	; wysyłamy bit 1
	jb flag_now_lsb, error_nothex_fwd
	setb C
command_icp51_send_bit_fast:
	acall icp51_send_bit
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_J:
	cjne A, #'L', command_icp51_transfer_not_L
	; wysyłamy bit 0, ale długo
	jb flag_now_lsb, error_nothex_fwd
	clr C
	sjmp command_icp51_send_bit_slow

command_icp51_transfer_not_L:
	cjne A, #'H', command_icp51_transfer_not_H
	; wysyłamy bit 1, ale długo
	jb flag_now_lsb, error_nothex_fwd
	setb C
command_icp51_send_bit_slow:
	acall icp51_send_bit_slow
	sjmp command_icp51_transfer_loop

command_icp51_transfer_not_H:
	; teraz musi być cyfra
	acall convert_hex_digit
	jc error_illopt
	jbc flag_now_lsb, command_icp51_transfer_now_lsb
	; MSB
	swap A
	mov R2, A
	setb flag_now_lsb
	sjmp command_icp51_transfer_loop
command_icp51_transfer_now_lsb:
	orl A, R2
	mov R2, A
	; mamy cały bajt
	jbc flag_7bits, command_icp51_transfer_7bits
	; wysyłamy bajt z A
	acall icp51_send_byte
	sjmp command_icp51_transfer_loop
command_icp51_transfer_7bits:
	; wysyłamy 7 bitów z A
	acall icp51_send_7bits
	sjmp command_icp51_transfer_loop

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
