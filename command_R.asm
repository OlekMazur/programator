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
; Procedura obsługi polecenia R
; Wypluwa wartości różnych rejestrów

command_read:
	acall ensure_no_args
	mov R6, #'1'
	mov R7, P1
	acall print_port

	acall uart_send_space

	mov R6, #'3'
	mov R7, P3
	acall print_port

if	USE_I2C
	acall uart_send_space

	mov R6, #'G'	; PG - maska rozmiaru strony AT24CXX (I2C EEPROM)
	mov R7, i2c_eeprom_page_mask
	acall print_port
endif

	ret

; Wypisuje P6:R7
;  gdzie 6 to znak z R6
;  a R7 to cyfry szesnastkowe wartości z R7
print_port:
	mov A, #'P'
	acall uart_send_char
	mov A, R6
; Wypisuje A:R7
print_rest:
	acall uart_send_char
	acall uart_send_colon
	mov A, R7
	ajmp uart_send_hex_byte
