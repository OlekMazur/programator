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
; Budowa systemu:
; - mikrokontroler AT89C2051 z kwarcem 11,0592 MHz
; - slot DIP20, do którego można włożyć od góry:
;  - pamięć EEPROM I2C: AT24CXX
;  - pamięć EEPROM SPI: 93CX6
;  - mikrokontroler Atmel ATtiny2313
; Połączenia mikrokontrolera "hosta" ze slotem:
; - host	slot	guest	ATtiny	24CXX	93CX6	1-wire
; - P1.4	pin 01	RST		nRST	A0		CS		GND
; - P1.3	pin 02	RXD		RXD		A1		CLK		DQ
; - P1.2	pin 03	TXD		TXD		A2		DI		VCC
; - P1.1	pin 04	XTAL2	XTAL2	GND		DO
; - GND		pin 10	GND		GND
; - VCC		pin 20	VCC		VCC		VCC		VCC
; - P1.7	pin 19	CLK		SCK		WP		PE
; - P1.6	pin 18	DAT		MISO	SCL		ORG
; - P1.5	pin 17	P1.5	MOSI	SDA		GND

$nomod51
$include (89c2051.mcu)
using	0

;===========================================================
; Stałe

$include (config.asm)

;===========================================================
; Makra

bcall	macro where
if	AT89C4051
	call where
else
	acall where
endif
endm

bjmp	macro where
if	AT89C4051
	jmp where
else
	ajmp where
endif
endm

;===========================================================
; Flagi

bseg
flag_receive_overflow:	dbit 1	; czy nastąpiło przepełnienie bufora wejściowego
flag_reading:			dbit 1	; czy teraz ma nastąpić bajt z liczbą bajtów do odczytu
flag_now_lsb:			dbit 1	; czy teraz ma nastąpić znak z młodszą połówką liczby szesnastkowej (cały bajt składamy w R2)
flag_end:

;===========================================================
; Zmienne

dseg

; miejsce zarezerwowane na banki rejestrów R0-R7
register_bank_0:	ds 8
register_bank_1:	ds 8
register_bank_2:	ds 8
register_bank_3:	ds 8
; miejsce zarezerwowane na flagi (zmienne adresowalne bitowo)
bit_addresable:		ds (flag_end+7)/8
spi_address_bits:		ds 1	; wykryta liczba bitów adresu pamięci 93XXY6X (najmłodszy bit: 1=tryb 8-bitowy, 0=tryb 16-bitowy)
if	USE_I2C
i2c_eeprom_page_mask:	ds 1	; maska bitów, które są wyzerowane na krawędzi strony (np. 00000111b -> strona 8-bajtowa)
endif
temp:				ds 1
; bufor na znaki przyjmowanego polecenia albo na (binarne) bajty danych
; z rekordu HEX - odbieranego albo przygotowywanego do wysyłki
input:				ds 32
input_end:

stack:		; początek stosu (rosnącego w górę)

;===========================================================

cseg

;-----------------------------------------------------------
; Start - reset hardware'owy albo zwykły skok

start:
	;mov SP, #stack - 1
	clr A
	mov PSW, A
	mov R0, A
zero_RAM:
	mov @R0, A
	djnz R0, zero_RAM
	orl PCON, #10000000b	; SMOD1 - "Set to select double baud rate in mode 1,2,3"
	dec A	; TL1=TH1=0FFh dla 57600 bodów przy SMOD1=1
	; inicjacja timerów 0 i 1 (1 na potrzeby UART0)
	mov TMOD, #00100001b	; tryb 2 (8-bitowy z autoreloadem) dla timera 1 i tryb 1 (16-bitowy) dla timera 0
	mov TL1, A
	mov TH1, A
	mov TCON, #01000000b	; uruchomienie timera 1
	; inicjacja portu UART - tryb 1 (8-bitowy UART z baudatem sterowanym timerem 1); włączenie odbioru (REN=bit4)
	mov SCON, #01010000b
	mov IE, #10010000b		; włączenie przerwań SINT (ES0=bit4) i globalnej flagi przerwań (EA=bit7)
	; ES0=1 żeby UART działał i ustawiał flagi TI,RI
	; EA=1 żeby procesor w ogóle się budził z trybu IDLE
if	USE_I2C
	mov i2c_eeprom_page_mask, #00000111b	; domyślnie strony 8-bajtowe - słuszne dla AT24C01 i 02, od 04 w górę mają 16-bajtowe
endif
	sjmp jump_over_sint

org	SINT
	reti

jump_over_sint:

;-----------------------------------------------------------
; Czekamy na <CR>
wait_for_cr:
	acall uart_receive_char
	cjne A, #13, wait_for_cr
	; wypisujemy powitanie
	mov DPTR, #s_welcome
	sjmp print_message

;-----------------------------------------------------------
; Wypisz E: i komunikat spod DPTR
print_error_then_prompt:
	mov SP, #stack - 1		; reset stosu - zapominamy, gdzie byliśmy
	mov A, #'E'
	acall uart_send_char
	acall uart_send_colon
print_message:
	acall uart_send_rom

;-----------------------------------------------------------
; Wypisz znak zachęty
print_prompt:
	mov SP, #stack - 1		; reset stosu - zapominamy, gdzie byliśmy
	mov DPTR, #s_prompt
	acall uart_send_rom

;-----------------------------------------------------------
; Odbierz linię polecenia pod #input
	mov R0, #input
	clr F0	; w tym bloku F0 jest flagą przepełnienia bufora odbiorczego
receive_command:
	acall uart_receive_char
	cjne A, #13, receive_command_not_CR
	; <CR> = koniec polecenia
	clr TI	; posprzątanie po echach
	acall uart_send_char	; ostatnie echo - <CR>
	mov A, #10				; <LF>
	acall uart_send_char
	jnb F0, process_command
	; za długa linia polecenia
error_extarg:
	mov DPTR, #s_error_extarg
	sjmp print_error_then_prompt
receive_command_not_CR:
	cjne R0, #input_end, receive_command_not_CR2
receive_command_not_CR2:
	; C = R0 < #input_end
	jc receive_command_no_overflow
	setb F0
receive_command_no_overflow:
	cjne A, #9, receive_command_not_HT
	mov A, #' '	; "The horizontal tab character is converted to space"
receive_command_not_HT:
	cjne A, #8, receive_command_not_BS
	mov A, #127	; "Backspaces (<BS>) are converted to delete characters"
receive_command_not_BS:
	cjne A, #'a', receive_command_not_smA
receive_command_not_smA:
	jc receive_command_not_small
	cjne A, #'z' + 1, receive_command_not_smZ
receive_command_not_smZ:
	jnc receive_command_not_small
	add A, #'A' - 'a'	; "Lowercase alphabetic characters are converted to uppercase alphabetic."
receive_command_not_small:
	; koniec konwersji znaków
	cjne A, #':', receive_command_not_colon
	sjmp receive_command_char_OK	; A = ':' -> OK
receive_command_not_colon:
	cjne A, #' ', receive_command_not_space
	sjmp receive_command_char_OK	; A = ' ' -> OK
receive_command_not_space:
	cjne A, #'0', receive_command_not_0
receive_command_not_0:
	jc receive_command_char_KO	; A < '0' -> KO
	cjne A, #'9' + 1, receive_command_not_9
receive_command_not_9:
	jc receive_command_char_OK	; A <= '9' -> OK
	cjne A, #'A', receive_command_not_bigA
receive_command_not_bigA:
	jc receive_command_char_KO	; A < 'A' -> KO
	cjne A, #'Z' + 1, receive_command_not_bigZ
receive_command_not_bigZ:
	jc receive_command_char_OK	; A <= 'Z' -> OK
	cjne A, #127, receive_command_char_KO	; A <> DEL -> KO
	; obsługa DEL/BS
	cjne R0, #input, receive_command_del
	; nie mamy co kasować
receive_command_char_KO:
	sjmp receive_command
receive_command_del:
	dec R0
	; "The <delete> character is executed as a <BS> <space> <BS>"
	clr TI	; posprzątanie po echach
	mov A, #8
	acall uart_send_char
	acall uart_send_space
	mov A, #8
	sjmp receive_command_echo
receive_command_char_OK:
	jb F0, receive_command_echo
	; jeśli mamy miejsce, wpisujemy znak do bufora
	mov @R0, A
	inc R0
receive_command_echo:
	mov SBUF, A
	sjmp receive_command

;-----------------------------------------------------------
; Interpretuj komendę umieszczoną między #input a R0 (nie ma tam <CR>)
process_command:
	mov DPTR, #s_commands
	mov R1, #input	; R1 = adres obecnie przetwarzanego znaku polecenia
	mov R2, #0		; R2 = stan maszyny rozpoznającej polecenie (offset listy przejść)
process_command_loop:
	mov A, R1
	cjne A, AR0, process_command_loop2
	; jesteśmy na końcu komendy - przetwarzamy niby-znak 0
	sjmp process_command_loop3
process_command_loop2:
	mov A, @R1
	inc R1
	cjne A, #' ', process_command_loop4
	; mamy spację - na tym kończymy przetwarzanie, zamieniamy na niby-znak 0
	; R1 musi pokazywać na spację a nie dalej
	dec R1
process_command_loop3:
	clr A
process_command_loop4:
	mov R3, A	; R3 = znak do przetworzenia przez maszynę stanów
	dec R2
process_command_map:
	inc R2
	mov A, R2	; A = offset mapowanego znaku
	inc R2		; R2 = offset za mapowanym znakiem
	movc A, @A + DPTR	; A = mapowany znak
	cjne A, AR3, process_command_unmatched
	; to ten znak - zakładamy, że nie może być -1 na wejściu
	jz process_command_matched	; 0 = cała komenda dopasowana
	; zmieniamy stan na następny
	mov A, R2
	movc A, @A + DPTR
	mov R2, A	; R2 = nowy stan
	sjmp process_command_loop
process_command_unmatched:
	; nie ten znak
	jz error_badcmd	; 0
	inc A
	jnz process_command_map			; nie 0 i nie -1
error_badcmd:
	; znak nie pasuje do żadnego mapowania w bieżącym stanie
	mov DPTR, #s_error_badcmd
	ajmp print_error_then_prompt
process_command_matched:
	mov A, R2
	acall jmp_dptr
	ajmp print_prompt
jmp_dptr:
	jmp @A + DPTR

;===========================================================

; Procedury obsługi UART niższego poziomu
$include (uart.asm)
; Funkcje pomocnicze
$include (library.asm)

; Obsługa poleceń
; Każda procedura obsługi polecenia dostaje:
; R1 = adres pierwszego znaku za nazwą polecenia - tj. spacja
; R0 = adres pierwszego znaku za linią polecenia - jeśli R0=R1, to nie ma argumentów

error_illopt:
	mov DPTR, #s_error_illopt
	ajmp print_error_then_prompt

if	USE_AVR
$include (command_DAE_VAE_LAE_DA_VA_LA_KA.asm)
$include (avr.asm)
endif

if	DEBUG
$include (command_DR.asm)
$include (command_DP.asm)
$include (command_LR_VR.asm)
endif

if	USE_I2C
$include (command_DX_VX_LX.asm)
$include (i2c.asm)
endif

$include (command_R.asm)
$include (command_W.asm)

if	USE_1WIRE
$include (command_1W.asm)
$include (1wire.asm)
endif

if	USE_HELP
$include (command_H.asm)
endif

if	USE_SPI
$include (spi.asm)
$include (command_DY_VY_LY.asm)
endif

;===========================================================

; Listy przejść maszyny stanów
s_commands:
; Tu zaczyna się lista przejść ze stanu początkowego.
; Dla każdego stanu lista składa się z umieszczonych bezpośrednio po sobie następujących wpisów:
; - kod znaku, po nim jednobajtowy offset względem s_commands
;    listy przejść z nowego stanu
; - -1 kończy listę, napotkanie go oznacza nieznaną komendę
; - 0 kończy listę, napotkanie go oznacza rozpoznanie komendy,
;    zaraz potem jest rozkaz skoku do procedury obsługującej polecenie
; stan początkowy przed rozpoznaniem pierwszego znaku
if	USE_HELP
	db	'H', s_commands_H - s_commands
endif
	db	'R', s_commands_R - s_commands
	db	'W', s_commands_W - s_commands
	db	'D', s_commands_D - s_commands
	db	'V', s_commands_V - s_commands
	db	'L', s_commands_L - s_commands
if	USE_AVR
	db	'K', s_commands_K - s_commands
endif
if	USE_1WIRE
	db	'1', s_commands_1 - s_commands
endif
	db	0
	bjmp ret1	; pusta komenda niech nie robi nic zamiast pisać E:BADCMD
if	USE_HELP
s_commands_H:
	db	0
	bjmp command_help
endif
s_commands_D:
if	USE_I2C
	db	'X', s_commands_DX - s_commands
endif
if	USE_SPI
	db	'Y', s_commands_DY - s_commands
endif
if	USE_AVR
	db	'A', s_commands_DA - s_commands
endif
if	DEBUG
	db	'R', s_commands_DR - s_commands
	db	'P', s_commands_DP - s_commands
endif
	db	-1
s_commands_V:
if	USE_I2C
	db	'X', s_commands_VX - s_commands
endif
if	USE_SPI
	db	'Y', s_commands_VY - s_commands
endif
if	USE_AVR
	db	'A', s_commands_VA - s_commands
endif
if	DEBUG
	db	'R', s_commands_VR - s_commands
endif
	db	-1
if	USE_AVR
s_commands_K:
	db	'A', s_commands_KA - s_commands
	db	-1
endif
s_commands_L:
if	USE_I2C
	db	'X', s_commands_LX - s_commands
endif
if	USE_SPI
	db	'Y', s_commands_LY - s_commands
endif
if	USE_AVR
	db	'A', s_commands_LA - s_commands
endif
if	DEBUG
	db	'R', s_commands_LR - s_commands
endif
	db	-1
s_commands_W:
	db	'P', s_commands_WP - s_commands
	db	-1
if	USE_1WIRE
s_commands_1:
	db	'W', s_commands_1W - s_commands
	db	-1
endif
s_commands_R:
	db	0
	bjmp command_read
if	USE_I2C
s_commands_DX:
	db	0
	bjmp command_dump_i2c_eeprom
s_commands_LX:
	db	0
	bjmp command_load_i2c_eeprom
s_commands_VX:
	db	0
	bjmp command_verify_i2c_eeprom
endif
if	USE_SPI
s_commands_DY:
	db	0
	bjmp command_dump_spi_eeprom
s_commands_VY:
	db	0
	bjmp command_verify_spi_eeprom
s_commands_LY:
	db	0
	bjmp command_load_spi_eeprom
endif
if	USE_AVR
s_commands_DA:
	db	'E', s_commands_DAE - s_commands
	db	0
	bjmp command_dump_avr_flash
s_commands_VA:
	db	'E', s_commands_VAE - s_commands
	db	0
	bjmp command_verify_avr_flash
s_commands_KA:
	db	0
	bjmp command_avr_chip_erase
s_commands_LA:
	db	'E', s_commands_LAE - s_commands
	db	0
	bjmp command_load_avr_flash
s_commands_DAE:
	db	0
	bjmp command_dump_avr_eeprom
s_commands_VAE:
	db	0
	bjmp command_verify_avr_eeprom
s_commands_LAE:
	db	0
	bjmp command_load_avr_eeprom
endif
s_commands_WP:
	db	'1', s_commands_WP1 - s_commands
	db	'3', s_commands_WP3 - s_commands
if	USE_I2C
	db	'G', s_commands_WPG - s_commands
endif
	db	-1
if	USE_1WIRE
s_commands_1W:
	db	'R', s_commands_1WR - s_commands
	db	'1', s_commands_1W1 - s_commands
	db	-1
s_commands_1WR:
	db	0
	bjmp command_1wire_rw
s_commands_1W1:
	db	0
	bjmp command_1wire_ds1821_exit_thermostat
endif
s_commands_WP1:
	db	0
	bjmp command_write_P1
s_commands_WP3:
	db	0
	bjmp command_write_P3
if	USE_I2C
s_commands_WPG:
	db	0
	bjmp command_write_pagemask
endif
if	DEBUG
s_commands_DR:
	db	0
	bjmp command_dump_host_RAM
s_commands_DP:
	db	0
	bjmp command_dump_host_ROM
s_commands_LR:
	db	0
	bjmp command_load_host_RAM
s_commands_VR:
	db	0
	bjmp command_verify_host_RAM
endif
; cały powyższy obszar musi dać się zaadresować 8-bitowym indeksem (względem s_commands)
s_commands_end:
if (s_commands_end - s_commands) >= (100h - USE_HELP)
$error(commands table too long)
endif

s_error_extarg:	db	"EXTARG",0
s_error_badcmd:	db	"BADCMD",0
s_error_extspc:	db	"EXTSPC",0
s_error_notspc:	db	"NOTSPC",0
s_error_nothex:	db	"NOTHEX",0
s_error_argreq:	db	"ARGREQ",0
s_error_illopt:	db	"ILLOPT",0
s_error_i2cerr:	db	"I2C KO",0
s_error_1w_err:	db	"1-WIRE KO",0
s_error_spierr:	db	"SPI KO",0
s_error_avrerr:	db	"AVR KO",0
s_error_odd_address:	db	"ODD ADDRESS IN 16-BIT MODE",0
s_spi_org:	db	'ADDRESS BITS:',0
s_prompt:	db	13,10,"> ",0
s_welcome:	db	"AVR/EEPROM PROGRAMMER VERSION 0.1  Copyright (C) 2022 Aleksander Mazur",0

;===========================================================

total_program_size:

END
