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

if	ICP51_W79EX051
	acall uart_send_space

	mov A, #'R'	; R - ICP51 clock delay
	mov R7, icp51_clock_delay
	acall print_rest

	acall uart_send_space

	mov A, #'W'
	acall uart_send_char
	mov A, #'L'	; WL - ICP51 clock delay (w stanie niskim przed impulsem)
	mov R7, icp51_clock_delay_low
	acall print_rest

	acall uart_send_space

	mov A, #'W'
	acall uart_send_char
	mov A, #'H'	; WH - ICP51 clock delay (w stanie wysokim)
	mov R7, icp51_clock_delay_high
	acall print_rest

	acall uart_send_space

	mov A, #'R'
	acall uart_send_char
	mov A, #'F'	; RF - ICP51 flash read command code
	mov R7, icp51_cmd_read_flash
	acall print_rest
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
