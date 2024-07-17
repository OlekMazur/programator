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
; Procedura obsługi poleceń 1-wire (1W*)

;-----------------------------------------------------------
; Obsługuje komendę 1W - wyślij/odbierz surowe dane do/z 1-wire
if	USE_HELP_DESC
	dw	s_help_1W
endif
command_1wire_transfer:
	mov P1, #11111011b	; OW_GND do masy, jedynki gdzie indziej
command_1wire_transfer_loop:
	acall get_hex_or_char
	jnc command_1wire_send_byte
	jnz command_1wire_handle_char
	; C=1, A=0 -> koniec
ret_1wire:
	ret

command_1wire_send_byte:
	; C=0, A=bajt do wysłania
	bcall ow_write
	sjmp command_1wire_transfer_loop

command_1wire_handle_char:
	; C=1, A=znak
	cjne A, #' ', command_1wire_transfer_not_space
	; spacja = reset 1-wire
	bcall ow_reset
	jc error_1w_err
	bcall uart_send_char	; echo
	sjmp command_1wire_transfer

command_1wire_transfer_not_space:
	cjne A, #'R', command_1wire_transfer_not_R
	; odbieramy bajt
	bcall ow_read
	bcall uart_send_hex_byte
	sjmp command_1wire_transfer_loop

command_1wire_transfer_not_R:
	cjne A, #'W', command_1wire_transfer_not_W
	; czytamy bity, dopóki jest zero (trwa pomiar)
	clr A	; max.65536*ow_read_bit, ok.5s
	mov R6, A
	mov R5, A
command_1wire_wait_loop:
	; "the master can issue read time slots after the Convert T command ..."
	bcall ow_read_bit
	; "... and the DS18B20 will respond by transmitting a 0 while the temperature conversion is in progress and a 1 when the conversion is done"
	jc command_1wire_transfer_loop
	djnz R6, command_1wire_wait_loop
	djnz R5, command_1wire_wait_loop
	mov DPTR, #s_error_1w_timeout
	bcall uart_send_rom
	sjmp command_1wire_transfer_loop

command_1wire_transfer_not_W:
	bjmp error_illopt

;-----------------------------------------------------------
; Obsługuje komendę 1W1 - przywróć tryb 1-wire czujnikowi DS1821
; "Communications can be re-established with the DS1821 while it is in
;  thermostat mode by pulling VDD to 0V while the DQ line is held high,
;  and then toggling the DQ line low 16 times (...)"
if	USE_HELP_DESC
	dw	s_help_1W1
endif
command_1wire_ds1821_exit_thermostat:
	bcall ensure_no_args
	mov P1, #11111011b	; OW_GND do masy, jedynki gdzie indziej
	nop
	clr OW_PWR			; "pulling VDD to 0V while the DQ line is held high"
	mov R7, #32
	nop
command_1wire_ds1821_loop:	; "toggling the DQ line low 16 times"
	nop
	cpl OW_DQ
	nop
	djnz R7, command_1wire_ds1821_loop
	nop
	setb OW_PWR
	bcall ow_reset
	jnc ret_1wire
	;jc error_1w_err
;-----------------------------------------------------------
error_1w_err:
	mov DPTR, #s_error_1w_err
	bjmp print_error_then_prompt
