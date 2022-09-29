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
; Procedura obsługi poleceń:
; - DX [begin-address [end-address]]
; - VX
; - LX
; Czyli odczyt/weryfikacja/zapis pamięci EEPROM na I2C (AT24CXX, gdzie XX<=16)

;-----------------------------------------------------------
; DX [begin-address [end-address]]
command_dump_i2c_eeprom:
	; domyślnie DX 0000 0800 (24C16: 16K = 2048*8)
	clr A
	mov R2, A
	mov R3, A
	mov R4, #8
	mov R5, A
	acall get_2_hex_numbers
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	; rozpoczynamy odczyt
	mov P1, #P1RD_I2C_EEPROM
	mov DPTR, #cb_dump_i2c_eeprom
	ajmp dump_hex_file

cb_dump_i2c_eeprom:
	acall i2c_eeprom_start_reading
	jc cb_dump_i2c_eeprom_error
	; gotowi do odczytu
	mov R0, #input
cb_dump_i2c_eeprom_loop:
	acall i2c_shin
	mov @R0, A
	inc R0
	djnz R7, cb_dump_i2c_eeprom_loop2
	acall i2c_NAK_stop
cb_ret_input_OK:
	clr C
cb_ret_input:
	mov R0, #input
ret6:
	ret
cb_dump_i2c_eeprom_error:
	mov DPTR, #s_error_i2cerr
	sjmp cb_ret_input
cb_dump_i2c_eeprom_loop2:
	acall i2c_ACK
	sjmp cb_dump_i2c_eeprom_loop

;-----------------------------------------------------------
; VX
command_verify_i2c_eeprom:
	acall ensure_no_args
	; rozpoczynamy odczyt
	mov P1, #P1RD_I2C_EEPROM
	mov DPTR, #cb_verify_i2c_eeprom
	ajmp load_hex_file

cb_verify_i2c_eeprom:
	acall i2c_eeprom_start_reading
	jc cb_lv_code_F
	; gotowi do odczytu
cb_verify_i2c_eeprom_loop:
	acall i2c_shin
	mov R2, A
	mov A, @R0
	cjne A, AR2, cb_lv_code_V
	inc R0
	djnz R7, cb_verify_i2c_eeprom_loop2
	acall i2c_NAK_stop
	; wszystko się zgadzało
cb_lv_code_G:
	mov A, #'G'
	ret
cb_lv_code_A:
	mov A, #'A'
	ret
cb_lv_code_V:
	mov A, #'V'
	ret
cb_verify_i2c_eeprom_loop2:
	acall i2c_ACK
	sjmp cb_verify_i2c_eeprom_loop

;-----------------------------------------------------------
; LX
command_load_i2c_eeprom:
	acall ensure_no_args
	; rozpoczynamy zapis
	mov P1, #P1WR_I2C_EEPROM
	mov DPTR, #cb_load_i2c_eeprom
	ajmp load_hex_file

cb_load_i2c_eeprom:
	acall i2c_eeprom_start_writing
	jc cb_lv_code_F
	; gotowi do zapisu
cb_load_i2c_eeprom_loop:
	mov A, @R0
	acall i2c_shout
	jc cb_lv_code_F
	inc R0
	; aktualizujemy też adres w dziedzinie EEPROM (R4:R5)
	inc R5
	mov A, R5
	jnz cb_load_i2c_eeprom_no_carry
	inc R4
cb_load_i2c_eeprom_no_carry:
	djnz R7, cb_load_i2c_eeprom_loop2
	; koniec
	acall i2c_stop
	; wszystko się udało
	sjmp cb_lv_code_G
cb_load_i2c_eeprom_loop2:
	; sprawdzamy, czy aby nie skończyła się strona
	anl A, i2c_eeprom_page_mask
	jnz cb_load_i2c_eeprom_loop
	; koniec strony - musimy zatrzymać transmisję, żeby dane się zapisały
	acall i2c_stop
	; czekamy, aż zapis danych się skończy (powinno to trwać max. 5 ms)
	clr A
	mov R3, A
cb_load_i2c_eeprom_poll:
	acall i2c_eeprom_start_writing
	jnc cb_load_i2c_eeprom_loop
	djnz R3, cb_load_i2c_eeprom_poll
	; coś się stało, pamięć przestała reagować na dłużej
cb_lv_code_F:
	mov A, #'F'
	ret

;===========================================================
; Procedury wspólne

;-----------------------------------------------------------
; Rozpoczyna komunikację z AT24CXX i wysyła adres
; R4:R5 = adres
; Zwraca C=1, jeśli błąd, w przeciwnym razie
; zwraca w A użyty adres na magistrali I2C (do zapisu) i układ
; jest gotowy do zapisu (lub do przełączenia na odczyt)
; Niszczy A, C, R1
i2c_eeprom_start_writing:
	acall i2c_start
	jc ret11
	; adres układu na magistrali: 1 0 1 0 A2 A1 A0 RW
	; bity adresu A2,A1,A0 bierzemy z najmłodszych bitów starszego bajtu czyli R4
	; młodszy bajt czyli R4 będzie użyty bezpośrednio później
	mov A, R4
	anl A, #00000111b
	rl A
	orl A, #I2C_EEPROM_ADDR
	mov R1, A	; R1 = adres zapisu na magistrali I2C
	acall i2c_shout
	jc i2c_stop
	mov A, R5	; młodszy bajt adresu
	acall i2c_shout
	jc i2c_stop
	mov A, R1
ret11:
	ret

;-----------------------------------------------------------
; Przełącza AT24CXX na odczyt
; Wywoływać po i2c_eeprom_start_addr
; A = adres układu na magistrali I2C (do zapisu)
; Zwraca C=1 jeśli błąd
i2c_eeprom_start_reading:
	acall i2c_eeprom_start_writing
	jc ret12
	acall i2c_start
	jc i2c_stop
	orl A, #1	; tym razem odczyt
	acall i2c_shout
	jc i2c_stop
ret12:
	ret

;-----------------------------------------------------------
; NAK + stop
i2c_NAK_stop:
	acall i2c_NAK
	ajmp i2c_stop
