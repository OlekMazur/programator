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

error_argreq:
	mov DPTR, #s_error_argreq
	ajmp print_error_then_prompt

error_illopt:
	mov DPTR, #s_error_illopt
	ajmp print_error_then_prompt

if USE_AVR or ICP51_W79EX051 or USE_AT89CX051
if ICP51_W79EX051
;-----------------------------------------------------------
; Maksymalne opóźnienie na 16-bitowym timerze to 71ms
sleep_timer0_max:
	clr A
	mov TH0, A
	mov TL0, A
	;ajmp sleep_timer0
endif
;-----------------------------------------------------------
; Włącza TIMER0 i śpi, aż ten się przekręci
; czyli aż TH0:TL0 dojdzie do 10000h
; a zwiększa się o 1 co 12 / 11.0592 MHz = 1,085 µs
; Wejście tu i włączenie timera zajmuje 36 cykli;
; od obudzenia się do powrotu schodzi nam jeszcze 120 cykli;
; czyli łączny czas czekania to 156 cykli (1,41µs)
; + czas liczenia przez timer (j.w.)
; + ewentualny czas wybudzania się z trybu IDLE
sleep_timer0:
	clr flag_timer
	setb TR0	; 12 cykli
sleep_cont:
	jbc flag_timer, cb_ret	; 24 cykle
	orl PCON, #00000001b	; PCON.0=IDL, "Set to enter idle mode" (sleep)
	; 48 cykli zajmuje nam obsługa przerwania TIMER0
	sjmp sleep_cont			; 24 cykle
endif

if DEBUG or USE_I2C or USE_AVR or ICP51_W79EX051 or USE_AT89CX051
cb_ret_RS_input_OK:
	clr RS0
cb_ret_input_OK:
	clr C
cb_ret_input:
	mov R0, #input
cb_ret:
	ret

cb_lv_code_G:
	mov A, #'G'
	ret

cb_lv_code_V:
	mov A, #'V'
	ret
endif

if USE_AVR or USE_SPI
cb_common_store_increment:
	mov @R0, A
cb_common_increment:
	inc R0
	inc R5
	cjne R5, #0, common_ret
	inc R4
common_ret:
	ret
endif
