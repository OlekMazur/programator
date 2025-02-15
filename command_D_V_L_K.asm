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
; Copyright (c) 2006, 2024 Aleksander Mazur
;
; Procedury obsługi poleceń:
; - D [begin-address [end-address]] - zrzut pamięci programu
; - V - weryfikacja pamięci programu
; - L - ładowanie pamięci programu (z weryfikacją)
; - K - kasowanie pamięci programu
; Czyli obsługa AT89C2051 i AT89C4051, a może i AT89C1051.
; Opóźnienia dostosowane do DS89C4X0.

AT89C_SIGN_ROLLOVER	equ	40h	; sygnatura ma 6-bitowy adres

;-----------------------------------------------------------
; D [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_D_atmel
endif
command_dump_at89cx051_flash:
	; domyślnie D 0 FFF
	acall at89cx051_init
	clr A
	mov R2, A
	mov R3, A
	mov R4, at89cx051_addr_H_mask
	mov R5, #0FFh
	acall get_address_range
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_at89cx051
	acall at89cx051_init_read_flash
	ajmp dump_hex_file

;-----------------------------------------------------------
; DS [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_DS_atmel
endif
command_dump_at89cx051_signature:
	; domyślnie DS 0 1
	;acall at89cx051_init
	clr A
	mov R2, A
	mov R3, A
	mov R4, A
	mov R5, #1
	acall get_address_range
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_at89cx051
	acall at89cx051_init_read_signature
	ajmp dump_hex_file

cb_dump_at89cx051:
	acall at89cx051_go_to_R4_R5
	jc cb_invalid_addr
	mov R0, #input
cb_dump_at89cx051_loop:
	mov A, AT89C_P1
	mov @R0, A
	acall at89cx051_inc_addr
	inc R0
	djnz R1, cb_dump_at89cx051_loop
	ajmp cb_ret_input_OK

cb_invalid_addr:
	mov DPTR, #s_error_out_of_range
	ajmp cb_ret_input

;-----------------------------------------------------------
; V
if	USE_HELP_DESC
	dw	s_help_V_atmel
endif
command_verify_at89cx051_flash:
	acall ensure_no_args
	acall at89cx051_init
	mov DPTR, #cb_verify_at89cx051
	acall at89cx051_init_read_flash
	ajmp load_hex_file

cb_verify_at89cx051:
	acall at89cx051_go_to_R4_R5
	jnc cb_verify_at89cx051_loop
cb_at89cx051_code_A:
	mov A, #'A'
	ret
cb_verify_at89cx051_loop:
	mov A, AT89C_P1
	mov R2, A
	mov A, @R0
	cjne A, AR2, cb_verify_at89cx051_fail
	acall at89cx051_inc_addr
	inc R0
	djnz R1, cb_verify_at89cx051_loop
	ajmp cb_lv_code_G
cb_verify_at89cx051_fail:
	ajmp cb_lv_code_V

;-----------------------------------------------------------
; L
if	USE_HELP_DESC
	dw	s_help_L_atmel
endif
command_load_at89cx051_flash:
	acall ensure_no_args
	acall at89cx051_init
	mov DPTR, #cb_load_at89cx051
	acall at89cx051_init_read_flash
	ajmp load_hex_file

cb_load_at89cx051:
	acall at89cx051_go_to_R4_R5
	jc cb_at89cx051_code_A
cb_load_at89cx051_loop:
	mov A, AT89C_P1
	cpl A
	anl A, @R0
	jz cb_load_at89cx051_loop2
	mov A, #'P'	; nie uda się przeprogramować zer na jedynki
	ret
cb_load_at89cx051_loop2:
	mov A, @R0
	mov AT89C_P1, A	; niech już leci t_DVGL
	setb AT89C_ENABLE	; zmiana kodu operacji z Read na Write {Code Data}
	acall wait_1us	; t_EHSH: min.1µs
	clr AT89C_VPP	; podanie 12V na RST/VPP
	acall wait_10us	; t_SHGL: min.10µs
	clr AT89C_PROG	; początek impulsu PROG
	mov R7, #0		; to będzie 93,5µs
	acall wait_R7	; t_GLGH: min.1µs, max.110µs
	setb AT89C_PROG	; koniec PROG
	mov C, AT89C_RDY_BSY	; AT89CX051 powinien opuścić /BUSY w czasie t_GHBL od puszczenia /PROG czyli max. 50ns
	acall wait_10us	; t_GHSL: min.10µs
	setb AT89C_VPP	; opuszczenie RST/VPP z 12V spowrotem do 5V
	acall at89cx051_init_read_flash	; poza wystawieniem jedynek na P1 równoważne clr AT89C_ENABLE
	clr flag_timer
	; t_WC - czas programowania bajtu to max.2ms
	mov TH0, #-8
	mov TL0, #-52
	setb TR0	; uruchamiamy timer na 2ms
	jb flag_at89cx051_nobsy, cb_load_at89cx051_no_BSY
	jnc cb_load_at89cx051_wait
	; /BUSY nie opadło od razu po puszczeniu /PROG
	jnb AT89C_RDY_BSY, cb_load_at89cx051_wait
	; /BUSY nie opadło nawet teraz -> błąd F
	jnb flag_at89cx051_nobsy, cb_load_at89cx051_code_F
cb_load_at89cx051_wait:
	; czekamy max.2ms na podniesienie linii /BUSY
	jb AT89C_RDY_BSY, cb_load_at89cx051_loop4
	jbc flag_timer, cb_load_at89cx051_timeout
	sjmp cb_load_at89cx051_wait
cb_load_at89cx051_timeout:
	clr TR0
cb_load_at89cx051_code_F:
	mov A, #'F'
	ret
cb_load_at89cx051_no_BSY:
	; kazano nam ignorować /BUSY, więc po prostu zaczekamy te 2ms
	acall sleep_timer0
cb_load_at89cx051_loop4:
	clr TR0
	; weryfikacja
	mov A, @R0
	cjne A, AT89C_P1, cb_load_at89cx051_code_V
	acall wait_1us	; t_BHIH: min.1µs
	acall at89cx051_inc_addr
	inc R0
	djnz R1, cb_load_at89cx051_loop
	ajmp cb_lv_code_G
cb_load_at89cx051_code_V:
	ajmp cb_lv_code_V

;-----------------------------------------------------------
; K
if	USE_HELP_DESC
	dw	s_help_K_atmel
endif
command_erase_at89cx051_flash:
	acall ensure_no_args
	;acall at89cx051_init - spróbujmy nawet, jeśli nie udałoby się zagadać z AT89CX051
	mov P0, #P0AT_OP_ERASE_ALL
	acall wait_1us	; t_EHSH
	clr AT89C_VPP	; podanie 12V na RST/VPP
	acall wait_10us	; t_SHGL
	clr AT89C_PROG	; początek impulsu PROG
	; 10ms = 9216 cykli timera
	mov TH0, #-36
	mov TL0, #0
	acall sleep_timer0
	setb AT89C_PROG	; koniec PROG
	acall wait_10us	; t_GHSL
	setb AT89C_VPP	; podanie 5V na RST/VPP
	ret

;===========================================================
; Procedury wspólne

; W razie błędu wypisuje komunikat i nie wraca!
; Niszczy A, C, R6, R7
at89cx051_init:
	jb flag_at89cx051_init, at89cx051_init_OK
	acall at89cx051_init_read_signature
	mov R6, #AT89C_SIGN_ROLLOVER
at89cx051_init_loop:
	acall wait_1us	; t_ELQV: max.1µs
	mov A, AT89C_P1	; (000H) = 1EH indicates manufactured by Atmel
	cjne A, #1Eh, at89cx051_init_not_atmel
	clr A
	mov at89cx051_addr_H, A
	; zawinęliśmy adres i wróciliśmy do pierwszego bajtu sygnatury
	mov at89cx051_addr_L, #AT89C_SIGN_ROLLOVER
	cjne R6, #AT89C_SIGN_ROLLOVER, at89cx051_init_rollover
	; udało się za pierwszym strzałem, czyli licznik jest na zerze
	mov at89cx051_addr_L, A
at89cx051_init_rollover:
	acall wait_1us	; t_BHIH: min.1µs
	acall at89cx051_inc_addr
	acall wait_1us	; t_ELQV: max.1µs
	mov A, AT89C_P1	; (001H) = X1H indicates AT89CX051
	mov R6, A
	anl A, #10001111b
	cjne A, #01h, at89cx051_init_fail
	mov DPTR, #s_at89c
	acall uart_send_rom
	mov A, R6
	swap A
	anl A, #00001111b
	mov R6, A
	acall uart_send_hex_digit
	mov DPTR, #s_051colon
	acall uart_send_rom
	mov A, R6
	; 1 -> 3, 2 -> 7, 4 -> F
	rl A
	rl A
	dec A
	mov at89cx051_addr_H_mask, A
	acall uart_send_hex_byte
	; FF do kompletu
	clr A
	dec A
	acall uart_send_hex_byte
	acall uart_send_crlf
	setb flag_at89cx051_init
at89cx051_init_OK:
	ret
at89cx051_init_not_atmel:
	acall wait_1us	; t_BHIH: min.1µs
	acall at89cx051_inc_addr
	djnz R6, at89cx051_init_loop
at89cx051_init_fail:
	mov DPTR, #s_error_at89cx051err
	bjmp print_error_then_prompt

s_at89c:	db	"AT89C",0
s_051colon:	db	"051: UP TO ",0

;-----------------------------------------------------------
; Przygotowuje do odczytu flasha z AT89CX051
at89cx051_init_read_flash:
	mov AT89C_P1, #11111111b
	mov P0, #P0AT_OP_READ_FLASH
	ret

;-----------------------------------------------------------
; Przygotowuje do odczytu sygnatury z AT89CX051
at89cx051_init_read_signature:
	mov AT89C_P1, #11111111b
	mov P0, #P0AT_OP_READ_SIGN
	ret

;-----------------------------------------------------------
; Przepisuje R7 do R1
; Przechodzi do adresu R4:R5
; Niszczy A
; Zwraca C=1 jeśli adres jest zły
at89cx051_go_to_R4_R5:
	mov A, R7
	mov R1, A
	mov A, at89cx051_addr_H_mask
	cpl A
	anl A, R4
	jz at89cx051_while_addr_inc
	; R4 & ~at89cx051_addr_H_mask != 0
	setb C
	ret
at89cx051_while_addr_inc:
	mov A, R5				; 1 cykl
	cjne A, at89cx051_addr_L, at89cx051_addr_different	; 5 cykli
	mov A, R4				; 1 cykl
	cjne A, at89cx051_addr_H, at89cx051_addr_different	; 5 cykli
	clr C
	ret
at89cx051_addr_different:
	acall at89cx051_inc_addr		; 24 cykle
	sjmp at89cx051_while_addr_inc	; 3 cykle

;-----------------------------------------------------------
; Inkrementuje licznik adresu - zarówno wewnętrzny w AT89CX051, jak i nasz w at89cx051_addr_H:L
; Niszczy A, C
at89cx051_inc_addr:
	setb AT89C_XTAL1		; 2 cykle
	; stan wysoki na XTAL1 musi trwać co najmniej 200 ns
	mov A, at89cx051_addr_L	; 2 cykle
	add A, #1				; 2 cykle
	mov at89cx051_addr_L, A	; 2 cykle
	mov A, at89cx051_addr_H	; 2 cykle
	addc A, #0				; 2 cykle
	clr AT89C_XTAL1			; 2 cykle
	anl A, at89cx051_addr_H_mask	; 2 cykle
	mov at89cx051_addr_H, A	; 2 cykle
	ret	; 3 cykle

;-----------------------------------------------------------
; Czeka 2+2+2*4+3=15 cykli czyli 1,35 µs
; Niszczy R7
wait_1us:			; 2 cykle (acall)
	mov R7, #2		; 2 cykle
	;sjmp wait_R7
;-----------------------------------------------------------
; Żeby poczekać X µs:
;  mov R7, #Y
;  sjmp wait_R7
; gdzie Y = sufit z (11.0592 * X - 10) / 4
; liczba cykli 10 = 2 (acall) + 2 (mov R7, #Y) + 3 (sjmp) + 3 (ret)
; Niszczy R7
wait_R7:
	djnz R7, $		; 2*4=8 cykli
wait_ret:
	ret				; 3 cykle

;-----------------------------------------------------------
; Niszczy R7
wait_10us:
	mov R7, #26		; 2 cykle
	sjmp wait_R7
