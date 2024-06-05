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
; Procedury komunikacji z W79EX051 (ICP) niższego poziomu

;-----------------------------------------------------------
; Wysyła bit=1 do programowanego mikrokontrolera
; Niszczy C, R6
icp51_send_bit1:
	setb C
;-----------------------------------------------------------
; Wysyła bit do programowanego mikrokontrolera
; C = bit do wysłania
; Niszczy R6
; Na wejściu i wyjściu CLK=1
icp51_send_bit:
	mov ICP51_DAT, C
	acall icp51_clock_tick_low
	sjmp icp51_clock_tick_high

;-----------------------------------------------------------
; Odbiera bit z programowanego mikrokontrolera
; Zwraca go w C
; Niszczy R6
icp51_recv_bit:
	acall icp51_clock_tick_low
	mov C, ICP51_DAT
	sjmp icp51_clock_tick_high

;-----------------------------------------------------------
; Opuszcza linię zegara i czeka przez zadany czas
icp51_clock_tick_low:
	clr ICP51_CLK
	mov R6, icp51_clock_delay_low
	djnz R6, $
	ret

;-----------------------------------------------------------
; Podnosi linię zegara i czeka przez zadany czas
icp51_clock_tick_high:
	setb ICP51_CLK
	mov R6, icp51_clock_delay_high
	djnz R6, $
	ret

;-----------------------------------------------------------
; Wysyła 8 bitów do programowanego mikrokontrolera
; A = bity do wysłania od najstarszego do najmłodszego
; Niszczy A, C, R6, R7
; Na wejściu i wyjściu CLK=1
icp51_send_byte:
	mov R7, #8
icp51_send_bits_loop:
	rlc A
	acall icp51_send_bit
	djnz R7, icp51_send_bits_loop
	ret

;-----------------------------------------------------------
; Wysyła 7 bitów do programowanego mikrokontrolera
; A = bity do wysłania od najstarszego do najmłodszego
; (z pominięciem samego najstarszego)
; Niszczy A, C, R6, R7
; Na wejściu i wyjściu CLK=1
icp51_send_7bits:
	mov R7, #7
	rlc A
	sjmp icp51_send_bits_loop

;-----------------------------------------------------------
; Odbiera 8 bitów od programowanego mikrokontrolera
; Zwraca je w A
; Niszczy A, C, R6, R7
; Na wejściu i wyjściu CLK=1
icp51_recv_byte:
	setb ICP51_DAT
	mov R7, #8
icp51_recv_bits_loop:
	acall icp51_recv_bit
	rlc A
	djnz R7, icp51_recv_bits_loop
	ret

;-----------------------------------------------------------
; Wysyła bit z C i czeka z CLK w stanie niskim przez czas R6*2*256 djnz'ów
; Niszczy R6, R7
icp51_send_bit_slow:
	mov ICP51_DAT, C
	clr ICP51_CLK
	mov R7, #0
icp51_send_bit_slow_loop:
	djnz R7, $
	djnz R7, $
	djnz R6, icp51_send_bit_slow_loop
	setb ICP51_CLK
	ret
