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
; Procedura obsługi polecenia I2C

;-----------------------------------------------------------
; Obsługuje komendę I2C - wyślij/odbierz surowe dane do/z I2C
if	USE_HELP_DESC
	dw	s_help_I2C
endif
command_i2c_transfer:
	mov P1, #P1WR_I2C_EEPROM
	clr F0	; czy był START
command_i2c_transfer_loop:
	bcall get_hex_or_char
	jnc command_i2c_send_byte
	jnz command_i2c_handle_char
	; C=1, A=0 -> koniec
command_i2c_maybe_stop:
	jnb F0, command_i2c_transfer_ret
	clr F0
	bjmp i2c_stop
command_i2c_transfer_ret:
	ret

command_i2c_send_byte:
	; C=0, A=bajt do wysłania
	bcall i2c_shout
	jnc command_i2c_transfer_loop
command_i2c_KO:
	mov DPTR, #s_error_i2cerr
	bjmp print_error_then_prompt

command_i2c_handle_char:
	; C=1, A=znak
	cjne A, #' ', command_i2c_transfer_not_space
	; spacja = [STOP] START
	bcall command_i2c_maybe_stop
	bcall uart_send_char	; echo
	sjmp command_i2c_start_and_cont

command_i2c_transfer_not_space:
	cjne A, #'R', command_i2c_transfer_not_R
	; odbieramy bajt
	bcall i2c_shin
	jc command_i2c_KO
	bcall uart_send_hex_byte
	sjmp command_i2c_transfer_loop

command_i2c_transfer_not_R:
	cjne A, #'S', command_i2c_transfer_not_S
command_i2c_start_and_cont:
	bcall i2c_start
	jc command_i2c_KO
	setb F0
	sjmp command_i2c_transfer_loop

command_i2c_transfer_not_S:
	cjne A, #'K', command_i2c_transfer_not_K
	bcall i2c_ACK
	sjmp command_i2c_transfer_loop

command_i2c_transfer_not_K:
	cjne A, #'N', command_i2c_transfer_not_N
	bcall i2c_NAK
	sjmp command_i2c_transfer_loop

command_i2c_transfer_not_N:
	bjmp error_illopt
