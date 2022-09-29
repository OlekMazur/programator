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
; Procedura obsługi polecenia W {P1 | P3} byte
; Wpisuje wartość do portu

command_write_P1:
	acall get_hex_arg
	jc error_argreq
	acall ensure_no_args
	mov P1, R3
	ret

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
command_write_pagemask:
	acall get_new_param_value
	mov i2c_eeprom_page_mask, R3
	ret
endif

error_argreq:
	mov DPTR, #s_error_argreq
	ajmp print_error_then_prompt
