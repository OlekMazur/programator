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
; Procedury pomocnicze do programowania AVR-ów (np. ATtiny2313)

;-----------------------------------------------------------
; Inicjuje komunikację z mikrokontrolerem.
; W razie błędu wypisuje komunikat i nie wraca!
; Niszczy A, C, R5, R6, R7
avr_init:
	mov R6, #0
avr_init_loop1:
	; SCK=0, nRST=0
	anl P1, #01101111b
	djnz R6, avr_init_loop1
	mov R7, #20
avr_init_reset:
	mov R6, #10
avr_init_loop2:
	; nRST=1
	setb AVR_nRST
	djnz R6, avr_init_loop2
	; nRST=0
	clr AVR_nRST
	; sleep 20ms
	mov R5, #36
avr_init_loop3:
	djnz R6, avr_init_loop3
	djnz R5, avr_init_loop3
	; wysyłamy Programming Enable (0xAC53)
	mov A, #10101100b
	acall avr_transfer_byte
	mov A, #01010011b
	acall avr_transfer_byte
	; czytamy 2 bajty - prawidłowa odpowiedź to 53h w trzecim bajcie
	acall avr_transfer_byte
	mov R5, A
	acall avr_transfer_byte
	cjne R5, #01010011b, avr_init_error
	ret
avr_init_error:
	mov DPTR, #s_error_avrerr
	acall uart_send_rom
	acall uart_send_colon
	mov A, R5
	acall uart_send_hex_byte
	acall uart_send_crlf
	djnz R7, avr_init_reset
avr_error:
	mov DPTR, #s_error_avrerr
	ajmp print_error_then_prompt

;-----------------------------------------------------------
; Wymienia bajt danych z AVR
; Wysyła bity z A na linię MOSI (od najstarszych)
;  i zasysa bity z MISO do A (od najmłodszych)
; Na wejściu nRST=0 i SCK=0
; Przesuwa A, niszczy C, R6
avr_transfer_byte:
	mov R6, #8
avr_transfer_bits:
	rlc A
	mov AVR_MOSI, C	; najstarszy bit z A -> MOSI
	rr A			; przywracamy A do poprzedniego stanu (oprócz najstarszego bitu, który jest już nieistotny, bo przed chwilą go wysłaliśmy)
	setb AVR_SCK
	nop
	mov C, AVR_MISO
	rlc A			; MISO -> najmłodszy bit w A
	clr AVR_SCK
	djnz R6, avr_transfer_bits
	ret

;-----------------------------------------------------------
; Czeka, aż AVR przejdzie w stan READY z BUSY
; Niszczy A, C, R2, R6
; Zwraca C=0, jeśli jest READY, a C=1, jeśli strasznie długo jest BUSY
avr_wait_until_ready:
	mov R2, #0
avr_poll_rdy_bsy_loop:
	; Poll RDY/nBSY: 1111 0000 0000 0000 xxxx xxxx xxxx xxxo
	mov A, #11110000b
	acall avr_transfer_byte
	clr A
	acall avr_transfer_byte
	acall avr_transfer_byte
	acall avr_transfer_byte
	rrc A
	jnc avr_poll_rdy_bsy_end
	djnz R2, avr_poll_rdy_bsy_loop2
	; C=1 (djnz nie zmienia flag)
avr_poll_rdy_bsy_end:
	ret
avr_poll_rdy_bsy_loop2:
	mov R6, #230
	djnz R6, $	; 0,5 ms
	sjmp avr_poll_rdy_bsy_loop
