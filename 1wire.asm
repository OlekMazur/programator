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
; Copyright (c) 2013, 2014, 2015, 2016, 2017, 2018, 2021, 2022 Aleksander Mazur
;
; Procedury niszczą A, C, R6, R7

;-----------------------------------------------------------
; RESET - zwraca C=1 jeśli wystąpił błąd (nie ma żadnego czujnika)
; niszczy C, R7
ow_reset:
	clr EA
	clr OW_DQ		; reset pulse min. 480 µs
	mov R7, #221	; łącznie impuls potrwa 481,77 µs
	djnz R7, $
	setb OW_DQ		; DS18B20 waits 15-60 µs
	setb C
	mov R7, #6		; łącznie poczekamy 15,19 µs
	djnz R7, $
	mov R7, #11		; poczekamy 12 * (24+24) / 11,0592 MHz = 48,83 µs
ow_reset_check_present:
	jnb OW_DQ, ow_reset_presence_pulse
	djnz R7, ow_reset_check_present
	sjmp ow_reset_return
ow_reset_presence_pulse:
	mov R7, #11		; presence pulse musi trwać jeszcze co najmniej 48,83 µs
ow_reset_check_present2:
	jb OW_DQ, ow_reset_return			; 24 cykle
	djnz R7, ow_reset_check_present2	; 24 cykle
	mov R7, #56		; presence pulse może trwać jeszcze co najwyżej 244,14 µs
ow_reset_check_present3:
	jb OW_DQ, ow_reset_presence_finished	; 24 cykle
	djnz R7, ow_reset_check_present3		; 24 cykle
	sjmp ow_reset_return	; błąd - za długi presence pulse
ow_reset_presence_finished:
	; poczekajmy jeszcze co najmniej tyle, ile w najgorszym przypadku
	; musi pozostać czasu do zakończenia resetu, czyli > 480-15-60=405 µs
	mov R7, #187	; 406,9 µs
	djnz R7, $
	clr C
ow_reset_return:
	setb EA
	ret

;-----------------------------------------------------------
; początek cyklu zapisu/odczytu bitu na 1-wire
; C = bit do wystawienia po impulsie 0
; długość impulsu 0 = 2,17 µs
ow_start_cycle:
	clr EA
	clr OW_DQ
	mov OW_DQ, C
	ret
	; po powrocie slot trwa już 4,34 µs

;-----------------------------------------------------------
; wysłanie bitu z C na 1-wire
; 192+24*(ow_tLOW+ow_tWR) cykli
; niszczy R7
ow_write_bit:
	acall ow_start_cycle
	; slave sampluje linię między 15 µs a 60 µs od początku slotu
	; cały slot trwa co najmniej 60 µs, max. 120 µs jeśli wysyłamy 0
	mov R7, #25
	djnz R7, $
	setb OW_DQ		; end write time slot
	; slot trwał 60,76 µs
	setb EA
	ret

;-----------------------------------------------------------
; odczyt bitu z 1-wire do C
; niszczy C, R7
ow_read_bit:
	setb C
	acall ow_start_cycle
	mov R7, #4
	djnz R7, $
	; master sampluje linię tuż przed upływem 15 µs od rozpoczęcia slotu
	mov C, OW_DQ	; 12 cykli
	mov R7, #21
	djnz R7, $
	; slot trwał 60,76 µs
	setb EA
	ret

;-----------------------------------------------------------
; odczyt bajtu z 1-wire do akumulatora
; niszczy A, C, R6, R7
ow_read:
	mov R6, #8
ow_read_loop:
	acall ow_read_bit
	rrc A
	djnz R6, ow_read_loop
	ret

;-----------------------------------------------------------
; wysłanie bajtu z akumulatora na 1-wire
; niszczy A, C, R6, R7
ow_write:
	mov R6, #8
ow_write_loop:
	rrc A
	acall ow_write_bit
	djnz R6, ow_write_loop
	ret
