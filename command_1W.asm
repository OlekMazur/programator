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
; Procedura obsługi poleceń 1-wire (1W*)

;-----------------------------------------------------------
; Obsługuje komendę 1WR - wyślij/odbierz surowe dane do/z 1-wire
command_1wire_rw:
	mov P1, #11111011b	; OW_GND do masy, jedynki gdzie indziej
	; domyślnie 1WR 33 8 = wyślij 33h (READ ROM) i czytaj 8 bajtów
	; przykład: 1WR CC44 0 = mierz temperaturę na DS18B20
	; przykład: 1WR CCBE 9 = wyślij CC,BE (SKIP ROM + READ SCRATCHPAD) i czytaj 9 bajtów z DS18B20
	clr A
	mov R2, A
	mov R3, #33h	; READ ROM
	mov R4, A
	mov R5, #8		; 64 bity = 8 bajtów
	acall get_2_hex_numbers
	; wysyłamy R4 (jeśli nie zero), R5
	; potem jeśli R2 nie jest zerem, to wysyłamy jeszcze R2 i R3
	; a jeśli R2 jest zerem, to czytamy R3 bajtów
	acall ow_reset
	jc error_1w_err
	mov A, R4
	jz command_1wire_rw_skip
	acall ow_write
command_1wire_rw_skip:
	mov A, R5
	acall ow_write
	mov A, R2
	jnz command_1wire_rw_write
	; czytamy R3 bajtów
command_1wire_rw_loop:
	acall ow_read
	acall uart_send_hex_byte
	djnz R3, command_1wire_rw_loop
	ret
command_1wire_rw_write:
	; wysyłamy jeszcze R2 i R3
	mov A, R2
	acall ow_write
	mov A, R3
	ajmp ow_write

;-----------------------------------------------------------
; Obsługuje komendę 1W1 - przywróć tryb 1-wire czujnikowi DS1821
; "Communications can be re-established with the DS1821 while it is in
;  thermostat mode by pulling VDD to 0V while the DQ line is held high,
;  and then toggling the DQ line low 16 times (...)"
command_1wire_ds1821_exit_thermostat:
	mov P1, #11111011b	; OW_GND do masy, jedynki gdzie indziej
	nop
	clr OW_PWR			; "pulling VDD to 0V while the DQ line is held high"
	mov R7, #32
	nop
command_1wire_ds1821_loop:	; "toggling the DQ line low 16 times"
	nop
	cpl OW_DQ
	nop
	djnz R7, command_1wire_ds1821_loop
	nop
	setb OW_PWR
	acall ow_reset
	jc error_1w_err
	ret

;-----------------------------------------------------------
error_1w_err:
	mov DPTR, #s_error_1w_err
	ajmp print_error_then_prompt
