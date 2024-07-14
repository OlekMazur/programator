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
; Procedura obsługi polecenia W

;-----------------------------------------------------------
; W P1 XX
if	USE_HELP_DESC
	dw	s_help_W_P1
endif
command_write_P1:
	acall get_hex_arg
	jc error_argreq
	acall ensure_no_args
	mov P1, R3
	ret

;-----------------------------------------------------------
; W P3 XX
if	USE_HELP_DESC
	dw	s_help_W_P3
endif
command_write_P3:
	acall get_hex_arg
	jc error_argreq
	acall ensure_no_args
	; musimy ochronić 2 najmłodsze bity P3 (czyli RXD i TXD) przed zmianą
	mov A, R3
	anl A, #11111100b
	orl P3, A
	orl A, #00000011b
	anl P3, A
	ret

; część wspólna procedur zapisu parametru w RAM
; zwraca nową wartość parametru w R2:R3
get_new_param_value:
	acall get_hex_arg
	jc error_argreq
	ajmp ensure_no_args

if	USE_I2C
;-----------------------------------------------------------
; W PG XX
if	USE_HELP_DESC
	dw	s_help_W_PG
endif
command_write_pagemask:
	acall get_new_param_value
	mov i2c_eeprom_page_mask, R3
	ret
endif

if	ICP51_W79EX051
;-----------------------------------------------------------
; W RF XX
if	USE_HELP_DESC
	dw	s_help_W_RF
endif
command_write_icp51_cmd_read_flash:
	acall get_new_param_value
	mov icp51_cmd_read_flash, R3
	ret
endif

if	USE_AT89CX051
;-----------------------------------------------------------
; W AM XX
if	USE_HELP_DESC
	dw	s_help_W_AM
endif
command_write_at89cx051_mask:
	acall get_new_param_value
	mov at89cx051_addr_H_mask, R3
	setb flag_at89cx051_init	; przyjmijmy, że użytkownik wie, co robi
	ret

;-----------------------------------------------------------
; W A XXXX
if	USE_HELP_DESC
	dw	s_help_W_A
endif
command_write_at89cx051_address:
	acall get_new_param_value
	mov at89cx051_addr_H, R2
	mov at89cx051_addr_L, R3
	setb flag_at89cx051_init	; przyjmijmy, że użytkownik wie, co robi
	ret
endif

error_argreq:
	mov DPTR, #s_error_argreq
	ajmp print_error_then_prompt
