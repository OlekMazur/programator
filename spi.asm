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
; Procedury pomocnicze do obsługi SPI

;-----------------------------------------------------------
spi_read_byte:
	clr A			; w czasie odczytu DI=0
;-----------------------------------------------------------
spi_transfer_byte:
	mov R6, #8
;-----------------------------------------------------------
; Wymienia bity danych z urządzeniem SPI
; Wysyła bity z A na linię DI (od najstarszych)
;  i zasysa bity z DO do A (od najmłodszych)
; Na wejściu CS=1 i CLK=0
; Przesuwa A, niszczy C, R6
spi_transfer_bits:
	rlc A
	mov SPI_DI, C	; najstarszy bit z A -> DI
	mov SPI_DI, C	; najstarszy bit z A -> DI
	setb SPI_CLK
	rr A			; przywracamy A do poprzedniego stanu (oprócz najstarszego bitu, który jest już nieistotny, bo przed chwilą go wysłaliśmy)
	mov C, SPI_DO
	mov C, SPI_DO
	rlc A			; DO -> najmłodszy bit w A
	clr SPI_CLK
	djnz R6, spi_transfer_bits
	ret

;-----------------------------------------------------------
; Inicjuje komunikację z pamięcią i wykrywa jej organizację pamięci.
; Wpisuje liczbę bitów adresowych do spi_address_bits.
; Wypisuje wynik na port szeregowy.
; Najmłodszy bit spi_address_bits oznacza:
; 1 = organizacja 8-bitowa
; 0 = organizacja 16-bitowa
; Niszczy A, B, C, R6, DPTR
; Na wyjściu CS=CLK=GND=0
; W razie błędu wypisuje komunikat i nie wraca!
spi_eeprom_autodetect:
	; DI=DO=1, CS=CLK=GND=0
	orl P1, #00000110b
	anl P1, #11000111b
	nop
	setb SPI_CS	; CS=1
	; sprawdzamy, ilobitowy adres przyjmie kość
	mov A, #11000000b
	mov R6, #3	; READ: 1,1,0
	bcall spi_transfer_bits
	; w odpowiedzi powinniśmy dostać 3 jedynki
	cjne A, #00000111b, spi_eeprom_error
	; przy ostatnim bicie adresu urządzenie wystawia DO=0
	mov R6, #11
spi_eeprom_autodetect_loop:
	setb SPI_CLK
	nop
	mov C, SPI_DO
	nop
	clr SPI_CLK
	jnc spi_eeprom_autodetect_check
	djnz R6, spi_eeprom_autodetect_loop
	; nie dostaliśmy zera
spi_eeprom_error:
	mov DPTR, #s_error_spierr
	bjmp print_error_then_prompt
spi_eeprom_autodetect_check:
	anl P1, #11000111b	; CS=CLK=GND=0
	; liczba bitów adresu = 12 - R6
	mov A, #12
	clr C
	subb A, R6
	mov spi_address_bits, A
	; 6 bitów -> 93XX46B (64*16)
	; 7 bitów -> 93XX46A (128*8)
	; 8 bitów -> 93XX56B (128*16) albo 93XX66B (256*16)
	; 9 bitów -> 93XX56A (256*8) albo 93XX66A (512*8)
	; 10 bitów -> 93XX76B (512*16) albo 93XX86B (1024*16)
	; 11 bitów -> 93XX76A (1024*8) albo 93XX86A (2048*8)
	mov DPTR, #s_spi_org
	bcall uart_send_rom
	mov A, spi_address_bits
	bcall convert_to_bcd
	bcall uart_send_hex_byte
	bjmp uart_send_crlf

;-----------------------------------------------------------
; Sprawdza, czy adres pamięci podany w R4:R5 jest właściwy dla trybu
; organizacji pamięci w spi_address_bits.
; Zwraca C=0 jeśli jest OK, C=1 jeśli adres jest nieprawidłowy.
; Niszczy A, C
spi_eeprom_check_address:
	jb spi_address_bits.0, spi_eeprom_check_address_ok
	; czy adres jest nieparzysty w trybie 16-bitowym?
	mov A, R5
	rrc A
	ret
spi_eeprom_check_address_ok:
	clr C
ret9:
	ret

;-----------------------------------------------------------
; Obraca A o R6 bitów w prawo
; dzięki czemu bit o numerze R6 staje się najstarszym
a_shr_r6:
	mov temp, R6
a_shr_r6_loop:
	rr A
	djnz R6, a_shr_r6_loop
	mov R6, temp
	ret

;-----------------------------------------------------------
; Wysyła komendę z 3 najstarszych bitów A i adres z R4:R5
; Zwraca C=1, jeśli błąd, a C=0 i ostatnio odebrane bity w A, jeśli sukces
; Na wejściu CS=GND=0
; Na wyjściu CS=1
; Niszczy A, R1, R6
spi_eeprom_send_cmd_addr:
	orl P1, #00010110b	; CS=DI=DO=1
	mov R6, #3
	bcall spi_transfer_bits
	; w odpowiedzi powinniśmy dostać 3 jedynki
	cjne A, #00000111b, spi_eeprom_send_cmd_addr_error
	; musimy wysłać spi_address_bits bitów adresu
	mov A, spi_address_bits
	orl A, #1
	cjne A, #8, spi_eeprom_send_cmd_addr2
spi_eeprom_send_cmd_addr2:
	jc spi_eeprom_send_cmd_addr_skip_msb
	; wysyłamy bity ze starszego bajtu (R4)
	add A, #-8
	mov R1, A	; R1 = liczba bitów wysyłanych z R4
	; przesuwamy najmłodszych A bitów na najstarsze pozycje
	mov R6, A
	mov A, R4
	bcall a_shr_r6
	bcall spi_transfer_bits
	; teraz trzeba wysłać pozostałe bity (spi_address_bits - R1) z najstarszych pozycji R3
	mov A, spi_address_bits
	clr C
	subb A, R1
	mov R6, A
	mov A, R3
	sjmp spi_eeprom_send_cmd_addr_send_lsb
spi_eeprom_send_cmd_addr_skip_msb:
	; (spi_address_bits | 1) < 8
	; wysyłamy bity od A = spi_address_bits | 1
	mov R6, A
	mov A, R5
	bcall a_shr_r6
	mov R6, spi_address_bits
spi_eeprom_send_cmd_addr_send_lsb:
	bcall spi_transfer_bits
	clr C
	ret
spi_eeprom_send_cmd_addr_error:
	setb C
	ret

;-----------------------------------------------------------
; Rozpoczyna odczyt danych spod adresu podanego w R4:R5
; Zwraca C=0 jeśli sukces, C=1 jeśli błąd
; Niszczy A, R1, R6
spi_eeprom_start_reading:
	mov A, #11000000b	; READ: 1,1,0
	bcall spi_eeprom_send_cmd_addr
	jc ret9
	; najmłodszy bit powinien być 0 -> do C z nim
	rrc A
	ret

;-----------------------------------------------------------
; Rozpoczyna zapis danych (bajtu albo słowa) pod adres podany w R4:R5
; Zwraca C=0 jeśli sukces, C=1 jeśli błąd
; Niszczy A, R1, R6
spi_eeprom_start_writing:
	mov A, #10100000b	; WRITE: 1,0,1
	bcall spi_eeprom_send_cmd_addr
	jc ret9
	; najmłodszy bit powinien być 1 -> do C z nim
	rrc A
	cpl C
	ret

;-----------------------------------------------------------
; Obsługuje zrzut jednego bajtu spod R4:R5 do @R0
; Inkrementuje R4:R5 i R0
cb_dump_spi_eeprom_byte:
	bcall spi_read_byte
cb_common_store_increment:
	mov @R0, A
cb_common_increment:
	inc R0
	inc R5
	cjne R5, #0, ret10
	inc R4
ret10:
	ret

;-----------------------------------------------------------
; Obsługuje weryfikację jednego bajtu spod R4:R5 z @R0
; Inkrementuje R4:R5 i R0
; Zwraca bieżący bajt (pobrany z urządzenia) w R2, a spodziewany bajt (spod @R0) w A
cb_verify_spi_eeprom_byte:
	bcall spi_read_byte
	mov R2, A
	mov A, @R0
	sjmp cb_common_increment

;-----------------------------------------------------------
; Obsługuje zapis jednego bajtu spod @R0 do R4:R5
; Inkrementuje R4:R5 i R0
cb_load_spi_eeprom_byte:
	mov A, @R0
	bcall spi_transfer_byte
	sjmp cb_common_increment
