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
; Procedury obsługi UART niższego poziomu

;-----------------------------------------------------------
; Czeka na odbiór znaku
; Zwraca odebrany znak w A, lub nie wraca
; Odbiór znaku od wyjścia z trybu IDLE
; (przy flag_rx_busy=1, flag_rx_stop=1, uart_rx_buffer!=3)
; trwa 120 cykli (+ przerwanie SINT)
uart_receive_char:
	jnb flag_rx_busy, uart_receive_wait		; 24 cykle
	; coś przyszło
	mov A, uart_rx_buffer	; 12 cykli
	clr flag_rx_busy		; 12 cykli
	cjne A, #3, ret2		; 24 cykle
	; "an ASCII control-C character (^C) causes the ROM loader to terminate any function currently being executed and display the command line prompt"
	ajmp print_welcome
uart_receive_wait:
	orl PCON, #00000001b	; PCON.0=IDL, "Set to enter idle mode" (sleep)
	sjmp uart_receive_char	; 24 cykle

;-----------------------------------------------------------
; Wysyła znaki z ROM spod adresu podanego w DPTR aż do 0
; Niszczy A, DPTR ustawia na pozycję znaku 0 kończącego transmisję
uart_send_rom:
	clr A
	movc A, @A + DPTR
	jz ret2	; 0 kończy nadawanie
	acall uart_send_char
	inc DPTR
	sjmp uart_send_rom	; następny znak
ret2:
	ret	; 24 cykle

;-----------------------------------------------------------
; Wysyła bajt z A jako 2 cyfry szesnastkowe w ASCII
; Niszczy A, C
uart_send_hex_byte:
	push ACC
	swap A
	anl A, #0Fh
	acall uart_send_hex_digit
	pop ACC
	anl A, #0Fh
	; sjmp uart_send_hex_digit
;-----------------------------------------------------------
; Wysyła cyfrę szesnastkową z A
uart_send_hex_digit:
	add A, #'0'
	cjne A, #'9' + 1, uart_send_hex_digit2
uart_send_hex_digit2:
	jc uart_send_hex_digit_ok
	add A, #'A' - '0' - 10
	cjne A, #'F' + 1, uart_send_hex_digit3
uart_send_hex_digit3:
	jc uart_send_hex_digit_ok
uart_send_colon:
	mov A, #':'
uart_send_hex_digit_ok:
	; sjmp uart_send_char
;-----------------------------------------------------------
; Wysyła znak z A
; Jeśli trwa jeszcze nadawanie poprzedniego znaku, to najpierw czeka, aż tamten się wyśle
uart_send_char:
	jb flag_tx_busy, uart_send_char
	mov SBUF, A
	setb flag_tx_busy
	ret

;-----------------------------------------------------------
; Wysyła spację
; Niszczy A
uart_send_space:
	mov A, #' '
	ajmp uart_send_char
