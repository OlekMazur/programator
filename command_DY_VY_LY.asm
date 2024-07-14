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
; Procedura obsługi poleceń:
; - DY [begin-address [end-address]]
; - VY
; - LY
; Czyli odczyt, weryfikacja i zapis pamięci EEPROM na SPI (np. 93C46N)

;-----------------------------------------------------------
; DY [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_DY
endif
command_dump_spi_eeprom:
	bcall spi_eeprom_autodetect
	; domyślny zakres adekwatny do liczby bitów adresu
	clr A
	mov R2, A
	mov R3, A
	mov R4, A
	mov R5, #1
	mov A, spi_address_bits
	orl A, #1	; parzysta liczba oznacza tryb 16-bitowy, w którym adresowanych _bajtów_ jest 2x więcej
	mov R6, A
command_dump_spi_eeprom_shl:
	mov A, R5
	clr C
	rlc A
	mov R5, A
	mov A, R4
	rlc A
	mov R4, A
	djnz R6, command_dump_spi_eeprom_shl
	; 6, 7 bitów -> 2^7=128 bajtów
	; 8, 9 bitów -> 2^9=512 bajtów
	; 10, 11 bitów -> 2^11=2048 bajtów
	clr C
	mov A, R5
	subb A, #1
	mov R5, A
	mov A, R4
	subb A, #0
	mov R4, A
	bcall get_address_range
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_spi_eeprom
	bjmp dump_hex_file

cb_dump_spi_eeprom:
	; na wejściu i na wyjściu CS=CLK=0
	bcall spi_eeprom_check_address
	jnc cb_dump_spi_eeprom_addr_ok
	mov DPTR, #s_error_odd_address
	bjmp print_error_then_prompt
cb_dump_spi_eeprom_addr_ok:
	setb RS0
	mov R4, AR4
	mov R5, AR5
	mov R7, AR7
	mov R0, #input
cb_dump_spi_eeprom_loop:
	; rozpoczynamy odczyt
	bcall spi_eeprom_start_reading
	jc cb_dump_spi_eeprom_error
	bcall cb_dump_spi_eeprom_byte
	djnz R7, cb_dump_spi_eeprom_loop2
	sjmp cb_dump_spi_eeprom_end
cb_dump_spi_eeprom_loop2:
	jb spi_address_bits.0, cb_dump_spi_eeprom_loop3
	; drugi bajt w trybie 16-bitowym
	bcall cb_dump_spi_eeprom_byte
	djnz R7, cb_dump_spi_eeprom_loop3
cb_dump_spi_eeprom_end:
	clr C
cb_dump_spi_eeprom_ret:
	anl P1, #11000111b	; CS=CLK=GND=0
	clr RS0
	mov R0, #input
	ret
cb_dump_spi_eeprom_loop3:
	; kończymy odczyt bajtu/słowa
	anl P1, #11000111b	; CS=CLK=GND=0
	sjmp cb_dump_spi_eeprom_loop
cb_dump_spi_eeprom_error:
	mov DPTR, #s_error_spierr
	setb C
	sjmp cb_dump_spi_eeprom_ret

;-----------------------------------------------------------
; VY
if	USE_HELP_DESC
	dw	s_help_VY
endif
command_verify_spi_eeprom:
	bcall ensure_no_args
	bcall spi_eeprom_autodetect
	mov DPTR, #cb_verify_spi_eeprom
	bjmp load_hex_file

cb_verify_spi_eeprom:
	; na wejściu i na wyjściu CS=CLK=0
	bcall spi_eeprom_check_address
	jnc cb_verify_spi_eeprom_loop
cb_spi_eeprom_code_A:
	mov A, #'A'
	sjmp cb_spi_eeprom_ret
cb_verify_spi_eeprom_loop:
	; rozpoczynamy odczyt
	bcall spi_eeprom_start_reading
	jc cb_spi_eeprom_code_F
	bcall cb_verify_spi_eeprom_byte
	cjne A, AR2, cb_spi_eeprom_code_V
	djnz R7, cb_verify_spi_eeprom_loop2
	sjmp cb_spi_eeprom_code_G
cb_verify_spi_eeprom_loop2:
	jb spi_address_bits.0, cb_verify_spi_eeprom_loop3
	; drugi bajt w trybie 16-bitowym
	bcall cb_verify_spi_eeprom_byte
	cjne A, AR2, cb_spi_eeprom_code_V
	djnz R7, cb_verify_spi_eeprom_loop3
	; wszystko się zgadzało
cb_spi_eeprom_code_G:
	mov A, #'G'
cb_spi_eeprom_ret:
	anl P1, #11000111b	; CS=CLK=GND=0
	ret
cb_verify_spi_eeprom_loop3:
	; kończymy odczyt bajtu/słowa
	anl P1, #11000111b	; CS=CLK=GND=0
	sjmp cb_verify_spi_eeprom_loop
cb_spi_eeprom_code_F:
	mov A, #'F'
	sjmp cb_spi_eeprom_ret
cb_spi_eeprom_code_V:
	mov A, #'V'
	sjmp cb_spi_eeprom_ret

;-----------------------------------------------------------
; LY
if	USE_HELP_DESC
	dw	s_help_LY
endif
command_load_spi_eeprom:
	bcall ensure_no_args
	bcall spi_eeprom_autodetect
	; musimy włączyć możliwość zapisu
	orl P1, #00010110b	; CS=DI=DO=1
	mov A, spi_address_bits
	add A, #3
	mov R6, A
	mov A, #10011000b	; EWEN (Erase/Write ENable): 1,0,0,1,1,x,x,x,... 3 bity + niby-adres
	; to nic, że R6 może być > 8, bo i tak wartości po piątym wysłanym bicie są bez znaczenia
	bcall spi_transfer_bits
	anl P1, #11000111b	; CS=CLK=GND=0
	mov DPTR, #cb_load_spi_eeprom
	bjmp load_hex_file

cb_load_spi_eeprom:
	; na wejściu i na wyjściu CS=CLK=0
	bcall spi_eeprom_check_address
	jc cb_spi_eeprom_code_A
	jb spi_address_bits.0, cb_load_spi_eeprom_loop
	; czy długość jest parzysta w trybie 16-bitowym?
	mov A, R7
	clr C
	rrc A
	jnc cb_load_spi_eeprom_16bit
cb_spi_eeprom_code_L:
	mov A, #'L'
	sjmp cb_spi_eeprom_ret
cb_load_spi_eeprom_16bit:
	mov R7, A	; R7 /= 2 - jedno djnz na słowo
cb_load_spi_eeprom_loop:
	; rozpoczynamy zapis
	bcall spi_eeprom_start_writing
	jc cb_spi_eeprom_code_F
	bcall cb_load_spi_eeprom_byte
	jb spi_address_bits.0, cb_load_spi_eeprom_one_byte
	; drugi bajt w trybie 16-bitowym
	bcall cb_load_spi_eeprom_byte
cb_load_spi_eeprom_one_byte:
	; opuszczamy CS na minimum T_CSL = 250 ns
	clr SPI_CS	; CS=0
	orl P1, #00010010b	; CS=DO=1
	; DO = READY/nBUSY po max. T_SV = 500 ns
	; czekamy, dopóki DO=0 (BUSY) - max. T_WC = 15 ms
	; ((100+(6-1)*256)*(24+24)+6*24)/11059200 = 6 ms
	; ((121+(14-1)*256)*(24+24)+14*24)/11059200 = 15 ms
	mov R6, #121
	mov R1, #14
cb_load_spi_eeprom_busy_loop:
	jb SPI_DO, cb_load_spi_eeprom_ready		; 24 cykle
	djnz R6, cb_load_spi_eeprom_busy_loop	; 24 cykle
	djnz R1, cb_load_spi_eeprom_busy_loop	; 24 cykle
	; coś jest nie tak - za długo DO=0
	sjmp cb_spi_eeprom_code_F
cb_load_spi_eeprom_ready:
	; kończymy zapis bajtu/słowa
	anl P1, #11000111b	; CS=CLK=GND=0
	djnz R7, cb_load_spi_eeprom_loop
	; wszystko się zgadzało
	sjmp cb_spi_eeprom_code_G
