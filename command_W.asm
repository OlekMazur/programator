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

; część wspólna procedur zapisu parametru w RAM
; zwraca nową wartość parametru w R2:R3
get_new_param_word:
	acall get_hex_arg
	jc error_argreq_fwd2
	ajmp ensure_no_args
error_argreq_fwd2:
	ajmp error_argreq

; zwraca nową wartość parametru w R3
get_new_param_value:
	acall get_new_param_word
	cjne R2, #0, error_extarg_fwd
	ret
error_extarg_fwd:
	ajmp error_extarg

;-----------------------------------------------------------
; W P1 XX
if	USE_HELP_DESC
	dw	s_help_W_P1
endif
command_write_P1:
	acall get_new_param_value
	mov P1, R3
	ret

;-----------------------------------------------------------
; W P3 XX
if	USE_HELP_DESC
	dw	s_help_W_P3
endif
command_write_P3:
	acall get_new_param_value
	; musimy ochronić 2 najmłodsze bity P3 (czyli RXD i TXD) przed zmianą
	mov A, R3
	anl A, #11111100b
	orl P3, A
	orl A, #00000011b
	anl P3, A
	ret

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
	acall get_new_param_word
	mov at89cx051_addr_H, R2
	mov at89cx051_addr_L, R3
	setb flag_at89cx051_init	; przyjmijmy, że użytkownik wie, co robi
	ret

;-----------------------------------------------------------
; W NB 0|1
if	USE_HELP_DESC
	dw	s_help_W_NB
endif
command_write_at89cx051_nobsy:
	acall get_new_param_value
	clr C
	mov A, R3
	rrc A
	jz command_write_at89cx051_nobsy_ok
	ajmp error_illopt	; podano parametr inny niż 0 lub 1
command_write_at89cx051_nobsy_ok:
	mov flag_at89cx051_nobsy, C
	ret
endif
