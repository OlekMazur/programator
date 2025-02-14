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

using	0

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
flag_timer:				dbit 1	; czy timer 0 zgłosił przerwanie
flag_tx_busy:			dbit 1	; czy bufor nadawczy UART jest zajęty
flag_rx_busy:			dbit 1	; czy nasz pomocniczy bufor odbiorczy UART (uart_rx_buffer) jest zajęty
if	ICP51_W79EX051
flag_icp51_init:		dbit 1	; czy mikrokontroler jest już w trybie programowania, gotowy na komendy
endif
if	USE_AT89CX051
flag_at89cx051_init:	dbit 1	; czy zostało już stwierdzone, że jest podłączony mikrokontroler
flag_at89cx051_nobsy:	dbit 1	; czy programować bez sprawdzania flagi RDY/BSY (P3.1)
endif
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
uart_rx_buffer:			ds 1	; pomocniczy bufor na znak odebrany z UART
spi_address_bits:		ds 1	; wykryta liczba bitów adresu pamięci 93XXY6X (najmłodszy bit: 1=tryb 8-bitowy, 0=tryb 16-bitowy)
if	USE_I2C
i2c_eeprom_page_mask:	ds 1	; maska bitów, które są wyzerowane na krawędzi strony (np. 00000111b -> strona 8-bajtowa)
endif
if	ICP51_W79EX051
icp51_cmd_read_flash:	ds 1	; kod operacji odczytu używany w poleceniach D i V (normalnie 00h)
endif
if	USE_AT89CX051
at89cx051_addr_H_mask:	ds 1	; maska znaczących bitów w at89cx051_addr_H (1KB -> 11b, 2KB -> 111b, 4KB -> 1111b)
at89cx051_addr_H:		ds 1	; stan wewnętrznego rejestru adresu w AT89CX051
at89cx051_addr_L:		ds 1	; stan wewnętrznego rejestru adresu w AT89CX051
endif
temp:				ds 1
; bufor na znaki przyjmowanego polecenia albo na (binarne) bajty danych
; z rekordu HEX - odbieranego albo przygotowywanego do wysyłki
input:				ds 32
input_end:

stack:		; początek stosu (rosnącego w górę)

;===========================================================

cseg

org	RESET

start:	; nie tylko po hardware'owym resecie tu trafiamy
	clr A
	mov PSW, A
	mov R0, A
zero_RAM:
	mov @R0, A
	djnz R0, zero_RAM
	dec A	; TL1=TH1=0FFh dla 57600 bodów przy SMOD1=1
	sjmp jump_over_timer0

org	TIMER0
	clr TR0			; 12 cykli
	setb flag_timer	; 12 cykli
	reti			; 24 cykle

jump_over_timer0:
	orl PCON, #10000000b	; SMOD1 - "Set to select double baud rate in mode 1,2,3"
	; inicjacja timerów 0 i 1 (1 na potrzeby UART0)
	mov TMOD, #00100001b	; tryb 2 (8-bitowy z autoreloadem) dla timera 1 i tryb 1 (16-bitowy) dla timera 0
	mov TL1, A
	mov TH1, A
	mov TCON, #01000000b	; uruchomienie timera 1
	; inicjacja portu UART - tryb 1 (8-bitowy UART z baudrate'm sterowanym timerem 1); włączenie odbioru (REN=bit4)
	mov SCON, #01010000b
	sjmp jump_over_sint

org	SINT	; odbiór znaku przy RI=1, TI=0, RB8=1 trwa 144 cykle
	jbc RI, sint_received	; 24 cykle
sint_cont:
	jbc TI, sint_sent		; 24 cykle
	reti					; 24 cykle
sint_sent:
	; UART skończył wysyłać znak
	clr flag_tx_busy		; 12 cykli
	reti					; 24 cykle
sint_received:
	; UART skończył odbierać znak
	mov uart_rx_buffer, SBUF	; 24 cykle
	jnb RB8, sint_stop0		; 24 cykle
	setb flag_rx_busy		; 12 cykli
	sjmp sint_cont			; 24 cykle
sint_stop0:
	; "An incoming break character (defined as a received null character (00h) with the stop bit = 0) causes the ROM loader to be restarted"
	push ACC
	mov A, uart_rx_buffer
	jz sint_break
	pop ACC
	; zjadamy znak odebrany z wyzerowanym bitem stopu (nie ustawiamy flag_rx_busy)
	sjmp sint_cont
sint_break:
	; A=0
	; imitacja software'owego resetu
	mov IE, A
	;mov SCON, A
	;mov TCON, A
	mov SP, #stack - 1		; reset stosu - zapominamy, gdzie byliśmy
	push ACC	; start musi być pod adresem 0
	push ACC
	dec A
	mov P1, A
	mov P3, A
	reti
	;ajmp start	; to by było za proste, musimy zrobić reti
if start <> 0
$error(start must be at 0)
endif

;-----------------------------------------------------------
jump_over_sint:
	mov IE, #10010010b		; włączenie przerwań TIMER0 (ET0=bit1), SINT (ES0=bit4) i globalnej flagi przerwań (EA=bit7)
if	USE_I2C
	mov i2c_eeprom_page_mask, #00000111b	; domyślnie strony 8-bajtowe - słuszne dla AT24C01 i 02, od 04 w górę mają 16-bajtowe
endif
if	USE_AT89CX051
	mov at89cx051_addr_H_mask, #1111b	; załóżmy pesymistycznie, że licznik przekręca się dopiero co 4KB - słuszne dla każdego typu AT89CX051
endif
wait_for_cr:
	acall uart_receive_char
	cjne A, #13, wait_for_cr
	; wypisujemy powitanie
print_welcome:
	mov DPTR, #s_welcome
	sjmp print_message

;-----------------------------------------------------------
; Wypisz E: i komunikat spod DPTR
print_error_then_prompt:
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
	acall uart_send_char	; ostatnie echo - <CR>
	mov A, #10				; <LF>
	acall uart_send_char
	jnb F0, process_command
	; za długa linia polecenia
	ajmp error_badcmd
receive_command_not_CR:
	cjne R0, #input_end, receive_command_not_CR2
receive_command_not_CR2:
	; C = R0 < #input_end
	jc receive_command_no_overflow
	setb F0
receive_command_no_overflow:
	cjne A, #'a', receive_command_not_smA
receive_command_not_smA:
	jc receive_command_not_small
	cjne A, #'z' + 1, receive_command_not_smZ
receive_command_not_smZ:
	jnc receive_command_not_small
	add A, #'A' - 'a'	; "Lowercase alphabetic characters are converted to uppercase alphabetic."
	sjmp receive_command_char_OK	; zbędne z punktu widzenia poprawności, ale przyspiesza obsługę
receive_command_not_small:
	cjne A, #'0', receive_command_not_0
receive_command_not_0:
	jc receive_command_not_digit
	; dwukropek też jest dozwolony, a ma kod ASCII zaraz za 9
	cjne A, #':' + 1, receive_command_not_9
receive_command_not_9:
	jc receive_command_char_OK	; '0' <= A <= ':'
receive_command_not_digit:
	cjne A, #'A', receive_command_not_bigA
receive_command_not_bigA:
	jc receive_command_not_bigletter
	cjne A, #'Z' + 1, receive_command_not_bigZ
receive_command_not_bigZ:
	jc receive_command_char_OK	; 'A' <= A <= 'Z'
receive_command_not_bigletter:
	cjne A, #' ', receive_command_not_space
	sjmp receive_command_char_OK	; A = ' '
receive_command_not_space:
	cjne A, #9, receive_command_not_htab
	mov A, #' '	; "The horizontal tab character is converted to space"
	sjmp receive_command_char_OK	; zbędne z punktu widzenia poprawności, ale przyspiesza obsługę
receive_command_not_htab:
	cjne A, #8, receive_command_not_BS
	;mov A, #127	; "Backspaces (<BS>) are converted to delete characters"
	sjmp receive_command_backspace
receive_command_not_BS:
	cjne A, #127, receive_command	; koniec dopuszczalnych znaków
receive_command_backspace:	; obsługa DEL/BS
	cjne R0, #input, receive_command_del
	jb F0, receive_command_del2	; nasz bufor jest już pusty, ale był przepełniony, więc kasujmy dalej
	; nie mamy co kasować
	sjmp receive_command
receive_command_del:
	dec R0
receive_command_del2:
	; "The <delete> character is executed as a <BS> <space> <BS>"
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
	acall uart_send_char
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
	; R1==R0 -> jesteśmy na końcu komendy - przetwarzamy niby-znak 0
	clr A
	sjmp process_command_loop3
process_command_loop2:
	mov A, @R1
	inc R1
process_command_loop3:
	mov R3, A	; R3 = znak do przetworzenia przez maszynę stanów
	dec R2
process_command_map:
	inc R2
	mov A, R2	; A = offset mapowanego znaku
	inc R2		; R2 = offset za mapowanym znakiem
	movc A, @A + DPTR	; A = mapowany znak
	cjne A, AR3, process_command_unmatched
	; to ten znak - zakładamy, że nie może być -1 na wejściu (pętla receive_command nie akceptuje -1)
	jz process_command_matched	; 0 = cała komenda dopasowana
	; zmieniamy stan na następny
	mov A, R2
	movc A, @A + DPTR
	mov R2, A	; R2 = nowy stan
	sjmp process_command_loop
process_command_unmatched:
	; jeśli znak do przetworzenia (R3) jest spacją, to może kończyć komendę
	cjne R3, #' ', process_command_unmatched2
	; spacja pasuje do zera na liście przejść stanu
	jz process_command_matched_space	; 0 = cała komenda dopasowana
process_command_unmatched2:
	; nie ten znak
	jz error_badcmd	; 0
	inc A
	jnz process_command_map			; nie 0 i nie -1
error_badcmd:
	; znak nie pasuje do żadnego mapowania w bieżącym stanie
	mov DPTR, #s_error_badcmd
	ajmp print_error_then_prompt
process_command_matched_space:
	; R1 musi pokazywać na spację, a nie za spacją
	dec R1
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
; R0 = adres pierwszego znaku za linią polecenia - jeśli R0==R1, to nie ma argumentów

if	ICP51_W79EX051
if	USE_AT89CX051
$error(ICP51_W79EX051 and USE_AT89CX051 are mutually exclusive)
endif
$include (w79ex051.asm)
$include (command_NR_NT.asm)
elseif	USE_AT89CX051
$include (command_D_V_L_K.asm)
endif

if	USE_AVR
$include (command_DAE_VAE_LAE_DA_VA_LA_KA.asm)
$include (avr.asm)
endif

if	ICP51_W79EX051
$include (command_D_V_LB_K.asm)
endif

if	DEBUG
$include (command_DR.asm)
$include (command_DP.asm)
$include (command_LR_VR.asm)
endif

$include (common.asm)

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

if	USE_I2C
$include (command_I2C.asm)
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
;    jeśli USE_HELP_DESC, to 2 bajty przed celem skoku musi być adres jednolinijkowego helpa
; stan początkowy przed rozpoznaniem pierwszego znaku
if	USE_HELP
	db	'H', s_commands_H - s_commands
endif
	db	'R', s_commands_R - s_commands
	db	'W', s_commands_W - s_commands
	db	'D', s_commands_D - s_commands
	db	'V', s_commands_V - s_commands
	db	'L', s_commands_L - s_commands
	db	'K', s_commands_K - s_commands
if	ICP51_W79EX051
	db	'N', s_commands_N - s_commands
endif
if	USE_1WIRE
	db	'1', s_commands_1 - s_commands
endif
if	USE_I2C
	db	'I', s_commands_I - s_commands
endif
	db	0
	ret	; pusta komenda niech nie robi nic zamiast pisać E:BADCMD
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
if	ICP51_W79EX051
	db	0
	bjmp command_dump_icp51_flash
elseif	USE_AT89CX051
	db	'S', s_commands_DS - s_commands
	db	0
	bjmp command_dump_at89cx051_flash
s_commands_DS:
	db	0
	bjmp command_dump_at89cx051_signature
else
	db	-1
endif
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
if	ICP51_W79EX051
	db	0
	bjmp command_verify_icp51_flash
elseif	USE_AT89CX051
	db	0
	bjmp command_verify_at89cx051_flash
else
	db	-1
endif
s_commands_K:
if	USE_AVR
	db	'A', s_commands_KA - s_commands
endif
if	ICP51_W79EX051
	db	0
	bjmp command_icp51_chip_erase
elseif	USE_AT89CX051
	db	0
	bjmp command_erase_at89cx051_flash
else
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
if	ICP51_W79EX051
	db	'B', s_commands_LB - s_commands
endif
if	USE_AT89CX051
	db	0
	bjmp command_load_at89cx051_flash
endif
	db	-1
s_commands_W:
	db	' ', s_commands_W_ - s_commands
	db	-1
if	USE_1WIRE
s_commands_1:
	db	'W', s_commands_1W - s_commands
	db	-1
endif
s_commands_R:
	db	0
	bjmp command_read
if	ICP51_W79EX051
s_commands_N:
	db	'R', s_commands_NR - s_commands
	db	'T', s_commands_NT - s_commands
	db	-1
s_commands_NR:
	db	0
	bjmp command_icp51_reset
s_commands_NT:
	db	0
	bjmp command_icp51_transfer
s_commands_W_R:
	db	'F', s_commands_W_RF - s_commands
	db	-1
s_commands_W_RF:
	db	0
	bjmp command_write_icp51_cmd_read_flash
s_commands_LB:
	db	0
	bjmp command_load_icp51_flash
endif
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
s_commands_W_:
	db	'P', s_commands_W_P - s_commands
if	ICP51_W79EX051
	db	'R', s_commands_W_R - s_commands
endif
if	USE_AT89CX051
	db	'A', s_commands_W_A - s_commands
	db	'N', s_commands_W_N - s_commands
endif
	db	-1
if	USE_AT89CX051
s_commands_W_A:
	db	'M', s_commands_W_AM - s_commands
	db	0
	bjmp command_write_at89cx051_address
s_commands_W_AM:
	db	0
	bjmp command_write_at89cx051_mask
s_commands_W_N:
	db	'B', s_commands_W_NB - s_commands
	db	-1
s_commands_W_NB:
	db	0
	bjmp command_write_at89cx051_nobsy
endif
s_commands_W_P:
	db	'1', s_commands_W_P1 - s_commands
	db	'3', s_commands_W_P3 - s_commands
if	USE_I2C
	db	'G', s_commands_W_PG - s_commands
endif
	db	-1
if	USE_1WIRE
s_commands_1W:
	db	'1', s_commands_1W1 - s_commands
	db	0
	bjmp command_1wire_transfer
s_commands_1W1:
	db	0
	bjmp command_1wire_ds1821_exit_thermostat
endif
s_commands_W_P1:
	db	0
	bjmp command_write_P1
s_commands_W_P3:
	db	0
	bjmp command_write_P3
if	USE_I2C
s_commands_W_PG:
	db	0
	bjmp command_write_pagemask
s_commands_I:
	db	'2', s_commands_I2 - s_commands
	db	-1
s_commands_I2:
	db	'C', s_commands_I2C - s_commands
	db	-1
s_commands_I2C:
	db	0
	ajmp command_i2c_transfer
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

;-----------------------------------------------------------

s_error_extarg:	db	"EXTARG",0
s_error_badcmd:	db	"BADCMD",0
s_error_extspc:	db	"EXTSPC",0
s_error_notspc:	db	"NOTSPC",0
s_error_nothex:	db	"NOTHEX",0
s_error_argreq:	db	"ARGREQ",0
s_error_illopt:	db	"ILLOPT",0
if	USE_I2C
s_error_i2cerr:	db	"I2C KO",0
endif
if	USE_1WIRE
s_error_1w_err:	db	"1-WIRE KO",0
s_error_1w_timeout:	db	"(TIMEOUT)",0
endif
if	USE_SPI
s_error_spierr:	db	"SPI KO",0
s_error_odd_address:	db	"ODD ADDRESS",0
s_spi_org:	db	"ADDRESS BITS:",0
endif
if	USE_AVR
s_error_avrerr:	db	"AVR KO",0
endif
if	ICP51_W79EX051
s_error_icp51err:	db	"ICP51 KO",0
endif
if	USE_AT89CX051
s_error_out_of_range:	db	"OUT OF RANGE ADDRESS",0
s_error_at89cx051err:	db	"AT89CX051 KO",0
endif
s_prompt:	db	13,10,"> ",0
s_welcome:	db	13,10
if	ICP51_W79EX051
s_welcome1:	db	"W79EX051"
elseif	USE_AT89CX051
s_welcome1:	db	"AT89CX051"
endif
if	(ICP51_W79EX051 or USE_AT89CX051) and USE_AVR
s_welcome2:	db	"/"
endif
if	USE_AVR
s_welcome3:	db	"AVR"
endif
s_welcome4:	db	" PROGRAMMER VERSION 1.2  Copyright (c) 2022-2025 Aleksander Mazur",0

if	USE_HELP_DESC
if	USE_HELP
s_help_H:	db	"Print this help",0
endif
if	USE_AVR
s_help_DAE:	db	"Dump AVR EEPROM",0
s_help_DA:	db	"Dump AVR flash",0
s_help_VAE:	db	"Verify AVR EEPROM",0
s_help_VA:	db	"Verify AVR flash",0
s_help_LAE:	db	"Load AVR EEPROM",0
s_help_LA:	db	"Load AVR flash",0
s_help_KA:	db	"Klear AVR (Chip Erase)",0
endif
if	DEBUG
s_help_DP:	db	"Dump internal flash",0
s_help_DR:	db	"Dump internal RAM",0
s_help_LR:	db	"Load internal RAM",0
s_help_VR:	db	"Verify internal RAM",0
endif
if	ICP51_W79EX051
s_help_D:	db	"Dump W79EX051",0
s_help_V:	db	"Verify W79EX051",0
s_help_LB:	db	"Load W79EX051 blindly",0
s_help_K:	db	"Klear W79EX051: 26=erase all, 22=AP flash (default), 62=NVM",0
s_help_NR:	db	"Reset W79EX051 & enter ICP mode",0
s_help_NT:	db	"Transfer to/from W79EX051 (no reset): NT 0000S0BRJ FB00S0CRZ RJ",0
endif
if	USE_AT89CX051
s_help_D_atmel:	db	"Dump AT89CX051 flash",0
s_help_DS_atmel:	db	"Dump AT89CX051 signature",0
s_help_V_atmel:	db	"Verify AT89CX051 flash",0
s_help_L_atmel:	db	"Load AT89CX051 flash",0
s_help_K_atmel:	db	"Klear AT89CX051 flash",0
s_help_W_AM:	db	"Set high order address mask (3,7,F)",0
s_help_W_A:		db	"Override address counter",0
s_help_W_NB:	db	"Whether L should ignore RDY/BSY",0
endif
if	USE_I2C
s_help_DX:	db	"Dump AT24CXX",0
s_help_VX:	db	"Verify AT24CXX",0
s_help_LX:	db	"Load AT24CXX",0
s_help_I2C:	db	"Transfer to/from I2C: A000SA1RKRN",0
endif
if	USE_SPI
s_help_DY:	db	"Dump 93XXY6Z",0
s_help_VY:	db	"Verify 93XXY6Z",0
s_help_LY:	db	"Load 93XXY6Z",0
endif
if	USE_1WIRE
s_help_1W:	db	"Transfer to/from 1-wire: 33RRRRRRRR",0
s_help_1W1:	db	"Exit thermostat mode of DS1821",0
endif
s_help_R:		db	"Read regs & show config",0
s_help_W_P1:	db	"Write to P1",0
s_help_W_P3:	db	"Write to P3",0
s_help_W_PG:	db	"Set PaGe mask: 7 for AT24C01/2, F for AT24C04 and bigger",0
s_help_W_RF:	db	"Set Read Flash code used by D&V commands",0
endif

;===========================================================

total_program_size:

END
