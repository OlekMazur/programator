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
; Procedury obsługi poleceń:
; - DAE [begin-address [end-address]] - zrzut EEPROM, sygnatury, kalibracji, fuse-bitów, lock-bitów
; - VAE - weryfikacja EEPROM (a także sygnatury, kalibracji, fuse-bitów, lock-bitów)
; - LAE - ładowanie pamięci EEPROM
; - DA [begin-address [end-address]] - zrzut pamięci programu
; - VA - weryfikacja pamięci programu
; - LA - ładowanie pamięci programu
; - KA - kasowanie pamięci programu
; Czyli obsługa AVR (np. ATtiny2313)

;-----------------------------------------------------------
; DAE [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_DAE
endif
command_dump_avr_eeprom:
	; domyślnie DAE 0 7F
	acall avr_init
	clr A
	mov R2, A
	mov R3, A
	mov R4, A
	mov R5, #7Fh	; 128 B EEPROMu
	acall get_address_range
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov A, R2
	jz command_dump_avr_eeprom_ok
	ajmp error_illopt_fwd
command_dump_avr_eeprom_ok:
	mov DPTR, #cb_dump_avr_eeprom
	ajmp dump_hex_file

cb_dump_avr_eeprom:
	setb RS0
	mov R4, AR4
	mov R5, AR5
	mov R7, AR7
	mov R0, #input
cb_dump_avr_eeprom_loop:
	acall avr_read_eeprom_R4R5
	bcall cb_common_store_increment
	djnz R7, cb_dump_avr_eeprom_loop
cb_dump_avr_ret:
	; koniec
	ajmp cb_ret_RS_input_OK

;-----------------------------------------------------------
; DA [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_DA
endif
command_dump_avr_flash:
	; domyślnie DA 0 7FF
	acall avr_init
	clr A
	mov R2, A
	mov R3, A
	mov R4, #7h
	mov R5, #0FFh
	acall get_address_range
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_avr_flash
	ajmp dump_hex_file

cb_dump_avr_flash:
	setb RS0
	mov R4, AR4
	mov R5, AR5
	mov R7, AR7
	mov R0, #input
cb_dump_avr_flash_loop:
	acall avr_read_flash_R4R5
	bcall cb_common_store_increment
	djnz R7, cb_dump_avr_flash_loop
	; koniec
	sjmp cb_dump_avr_ret

;-----------------------------------------------------------
; VAE
if	USE_HELP_DESC
	dw	s_help_VAE
endif
command_verify_avr_eeprom:
	acall ensure_no_args
	acall avr_init
	mov DPTR, #cb_verify_avr_eeprom
	ajmp load_hex_file

cb_verify_avr_eeprom:
	acall avr_read_eeprom_R4R5
	acall avr_common_verify
	djnz R7, cb_verify_avr_eeprom
cb_avr_code_G:
	ajmp cb_lv_code_G

;-----------------------------------------------------------
; VA
if	USE_HELP_DESC
	dw	s_help_VA
endif
command_verify_avr_flash:
	acall ensure_no_args
	acall avr_init
	mov DPTR, #cb_verify_avr_flash
	ajmp load_hex_file

cb_verify_avr_flash:
	acall avr_read_flash_R4R5
	acall avr_common_verify
	djnz R7, cb_verify_avr_flash
	sjmp cb_avr_code_G

;-----------------------------------------------------------
; LAE
if	USE_HELP_DESC
	dw	s_help_LAE
endif
command_load_avr_eeprom:
	acall ensure_no_args
	acall avr_init
	mov DPTR, #cb_load_avr_eeprom
	ajmp load_hex_file

cb_load_avr_eeprom:
	cjne R7, #1, cb_load_avr_eeprom_not_one_byte
	; tylko 1 bajt
	; Write EEPROM Memory: 1100 0000 000x xxxx xbbb bbbb iiii iiii
	mov A, #11000000b
	acall avr_write_eeprom_AR4R5atR0
	jc cb_avr_code_F
	sjmp cb_load_avr_eeprom_finish
cb_load_avr_eeprom_next:
	bcall cb_common_increment
	mov A, R5
	anl A, #00000011b
	jnz cb_load_avr_eeprom_not_one_byte
	; cofamy się o 4 bajty, żeby mieć adres wypełnionej strony, a nie następnej
	clr C
	mov A, R5
	subb A, #4
	mov R5, A
	mov A, R4
	subb A, #0
	mov R4, A
	; zapisujemy stronę, bo jest cała gotowa
	acall avr_write_eeprom_R4R5
	jc cb_avr_code_F
	; wracamy do następnej strony
	mov A, R5
	add A, #4
	mov R5, A
	mov A, R4
	addc A, #0
	mov R4, A
cb_load_avr_eeprom_not_one_byte:
	; Load EEPROM Memory Page: 1100 0001 0000 0000 0000 00bb iiii iiii
	mov A, #11000001b
	acall avr_transfer_byte
	clr A
	acall avr_transfer_byte
	mov A, R5
	anl A, #00000011b
	acall avr_transfer_byte
	mov A, @R0
	acall avr_transfer_byte
	djnz R7, cb_load_avr_eeprom_next
	; zapisujemy stronę, bo skończyły się dane wejściowe
	mov A, R5
	anl A, #11111100b
	mov R5, A
	acall avr_write_eeprom_R4R5
cb_load_avr_eeprom_finish:
	jnc cb_avr_code_G
cb_avr_code_F:
	mov A, #'F'
	ret

;-----------------------------------------------------------
; LA
if	USE_HELP_DESC
	dw	s_help_LA
endif
command_load_avr_flash:
	acall ensure_no_args
	acall avr_init
	mov DPTR, #cb_load_avr_flash
	ajmp load_hex_file

cb_load_avr_flash_next:
	bcall cb_common_increment
cb_load_avr_flash:
	; Load Program Memory Page: 0100 H000 000x xxxx xxxx bbbb iiii iiii
	; zapisuje 1 bajt pod adres bbbbH (w ramach strony o 16 słowach 16-bitowych)
	mov A, R5
	rrc A
	mov A, #01000000b
	mov ACC.3, C
	acall avr_transfer_byte	; 40h | ((R5 & 1) << 3)
	clr A
	acall avr_transfer_byte	; 0
	mov A, R5
	clr C
	rrc A
	acall avr_transfer_byte	; R5 >> 1
	mov A, @R0
	acall avr_transfer_byte
	djnz R7, cb_load_avr_flash_next
	; strona załadowana, teraz trzeba ją wpalić
	; Write Program Memory Page: 0100 1100 0000 00aa bbbb xxxx xxxx xxxx
	; w R4:R5 mamy adres ostatnio wpisanego bajtu;
	; musimy go przesunąć o 1 bit w prawo, aby uzyskać adres słowa
	mov A, R4
	clr C
	rrc A
	mov R4, A
	mov A, R5
	rrc A
	mov R5, A
	mov A, #01001100b
	acall avr_write_eeprom_AR4R5atR0
	ajmp cb_load_avr_eeprom_finish

;-----------------------------------------------------------
; Odczytuje bajt spod podanego adresu EEPROM lub podobnie zorganizowanej pamięci
; Przeprowadza cały 4-bajtowy transfer
; R4:R5 - adres i rozkaz wg poniższego schematu
;  starszy bajt adresu (R4) rozbijamy na 2 części:
;  - 5 starszych bitów będzie najstarszymi bitami pierwszego bajtu komendy
;  - 3 młodsze bity będą bitami 3,2,1 drugiego bajtu komendy (tj. z przesunięciem o 1 bit w lewo)
;  młodszy bajt adresu (R5) będzie wysyłany jako trzeci bajt komendy
;  R4 = xxxx xyyy -> xxxx x000 0000 yyy0
;  czyli:
;   30h = Read Signature Byte (R5 mod 4)
;   38h = Read Calibration Byte (R5=0,1)
;   50h = Read Fuse Bits (R5=x)
;   54h = Read Extended Fuse Bits (R5=x)
;   58h = Read Lock Bits (R5=x)
;   5Ch = Read Fuse High Bits (R5=x)
;   A0h = Read EEPROM Memory (R5 mod 128 w przypadku ATtiny2313)
;   0 jest przekształcane na A0h (dzięki czemu zrzut EEPROM ma adresy od 0)
; Zwraca odczytany bajt w A
; Niszczy C, R6
avr_read_eeprom_R4R5:
	mov A, R4
	jnz avr_read_eeprom_R4R5_nz
	mov A, #0A0h	; 00 -> A0 (EEPROM)
avr_read_eeprom_R4R5_nz:
	anl A, #11111000b
	acall avr_transfer_byte	; R4 & 0F8h
	mov A, R4
	anl A, #00000111b
	rl A
	acall avr_transfer_byte	; (R4 & 7) << 1
	mov A, R5
	acall avr_transfer_byte	; R5
	ajmp avr_transfer_byte

;-----------------------------------------------------------
; Odczytuje bajt spod podanego adresu pamięci flash
; Przeprowadza cały 4-bajtowy transfer
; R4:R5 - adres bajtu
; Zwraca odczytany bajt w A
; Niszczy C, R6
avr_read_flash_R4R5:
	; Read Program Memory:
	; 0010 H000 0aaa aaaa bbbb bbbb oooo oooo
	; czyta 1 bajt spod adresu aaaa aaab bbbb bbbH
	mov A, R5
	rrc A
	mov A, #00100000b
	mov ACC.3, C
	acall avr_transfer_byte	; 20h | ((R5 & 1) << 3)
	mov A, R4
	clr C
	rrc A
	acall avr_transfer_byte	; R4 >> 1
	mov A, R4
	rrc A
	mov A, R5
	rrc A
	acall avr_transfer_byte	; ((R4 & 1) << 7) | (R5 >> 1)
	ajmp avr_transfer_byte

;-----------------------------------------------------------
; Wspólna podprocedura weryfikacji
; A = wartość odczytana z pamięci
; R0 = adres w RAM, gdzie jest spodziewana wartość do porównania z A
; Musi być włączony bank rejestrów #0
; Jeśli wartości są różne, funkcja wraca poziom wyżej, zwracając kod V
; Jeśli wartości są równe, funkcja wykonuje cb_common_increment i wraca normalnie
avr_common_verify:
	mov R2, A
	mov A, @R0
	cjne A, AR2, avr_common_verify_fail
	bjmp cb_common_increment
avr_common_verify_fail:
	; zdejmujemy ze stosu adres naszego bezpośredniego wywołania
	pop ACC
	pop ACC
	mov A, #'V'
	ret

;-----------------------------------------------------------
; Zapisuje wypełnioną wcześniej stronę pamięci EEPROM
; i czeka na faktyczne zakończenie zapisu
avr_write_eeprom_R4R5:
	; Write EEPROM Memory Page: 1100 0010 00xx xxxx xbbb bb00 xxxx xxxx
	mov A, #11000010b
;-----------------------------------------------------------
; Wysyła A, R4, R5, @R0
; i czeka na faktyczne zakończenie zapisu
; Zwraca odczytany bajt w A
; Niszczy C, R6
avr_write_eeprom_AR4R5atR0:
	acall avr_transfer_byte
	mov A, R4
	acall avr_transfer_byte
	mov A, R5
	acall avr_transfer_byte
	mov A, @R0
	acall avr_transfer_byte
	ajmp avr_wait_until_ready

;-----------------------------------------------------------
; KA
if	USE_HELP_DESC
	dw	s_help_KA
endif
command_avr_chip_erase:
	acall ensure_no_args
	acall avr_init
	; Chip Erase: 1010 1100 100x xxxx xxxx xxxx xxxx xxxx
	mov A, #10101100b
	mov R4, #10000000b
	acall avr_write_eeprom_AR4R5atR0
	jc avr_error
	ret
