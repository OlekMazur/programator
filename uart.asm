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
; Odbiera znak i zeruje RI
; Na wejściu RI=1
; Nie wraca, jeśli tym znakiem był break lub control-C
; Kiedy wraca, to zwraca odebrany znak w A
uart_receive_internal:
	; coś przyszło
	mov A, SBUF
	jnz uart_receive_internal2
	jb RB8, uart_receive_internal2
	; "An incoming break character (defined as a received null character (00h) with the stop bit = 0) causes the ROM loader to be restarted"
	; imitacja software'owego resetu
	clr A
	mov IE, A
	mov SCON, A
	mov TCON, A
	dec A
	mov P1, A
	mov P3, A
	ajmp start	; tam też sczyścimy RI
uart_receive_internal2:
	clr RI	; czyszczenie RI dopiero po sprawdzeniu RB8
	cjne A, #3, ret2
	; "an ASCII control-C character (^C) causes the ROM loader to terminate any function currently being executed and display the command line prompt"
	ajmp print_prompt

;-----------------------------------------------------------
; Czeka na odbiór znaku
; Zwraca odebrany znak w A, lub nie wraca
uart_receive_char:
	jb RI, uart_receive_internal
	orl PCON, #00000001b	; PCON.0=IDL, "Set to enter idle mode" (sleep)
	sjmp uart_receive_char

;-----------------------------------------------------------
; Wysyła znaki z ROM spod adresu podanego w DPTR aż do 0
; Na wejściu TI powinno być 0
; Niszczy A, DPTR ustawia na pozycję znaku 0 kończącego transmisję
uart_send_rom:
	clr A
	movc A, @A + DPTR
	jz ret2	; 0 kończy nadawanie
	acall uart_send_char
	inc DPTR
	sjmp uart_send_rom	; następny znak
ret2:
	ret

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
; Na wejściu TI powinno być 0, na wyjściu też jest 0
; Wraca, gdy znak się wyśle
uart_send_char:
	mov SBUF, A
uart_send_wait:
	orl PCON, #00000001b	; PCON.0=IDL, "Set to enter idle mode" (sleep)
	jb RI, uart_send_RI
uart_send_wait2:
	jnb TI, uart_send_wait
	clr TI
	ret
uart_send_RI:
	acall uart_receive_internal
	; ignorujemy odbierane znaki
	sjmp uart_send_wait2

;-----------------------------------------------------------
; Wysyła spację
; Niszczy A
uart_send_space:
	mov A, #' '
	ajmp uart_send_char
