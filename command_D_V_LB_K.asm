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
; Copyright (c) 2024 Aleksander Mazur
;
; Procedury obsługi poleceń:
; - D [begin-address [end-address]] - zrzut pamięci programu
; - V - weryfikacja pamięci programu
; - LB - ładowanie pamięci programu (bez weryfikacji, na ślepo)
; - K - kasowanie pamięci programu
; Czyli obsługa W79E2051 i W79E4051

;-----------------------------------------------------------
; D [begin-address [end-address]]
if	USE_HELP_DESC
	dw	s_help_D
endif
command_dump_icp51_flash:
	; domyślnie D 0 7FF
	acall icp51_init
	clr A
	mov R2, A
	mov R3, A
	mov R4, #7h
	mov R5, #0FFh
	acall get_address_range
	; mamy zakres zrzutu: R2:R3 bajtów poczynając od R4:R5
	mov DPTR, #cb_dump_icp51
	ajmp dump_hex_file

cb_dump_icp51:
	acall icp51_save_R7_send_R4R5
	; kod operacji odczytu z flasha
	mov A, icp51_cmd_read_flash
	acall icp51_send_7bits
	; gotowi do odczytu
	mov R0, #input
cb_dump_icp51_loop:
	acall icp51_recv_byte
	mov @R0, A
	inc R0
	djnz R1, cb_dump_icp51_loop2
	; wysyłamy bit 1 czyli zakończenie operacji odczytu
	acall icp51_send_bit1
	ajmp cb_ret_input_OK
cb_dump_icp51_loop2:
	; wysyłamy bit 0 czyli kontynuacja operacji odczytu
	clr C
	acall icp51_send_bit
	sjmp cb_dump_icp51_loop

;-----------------------------------------------------------
; V
if	USE_HELP_DESC
	dw	s_help_V
endif
command_verify_icp51_flash:
	acall ensure_no_args
	acall icp51_init
	mov DPTR, #cb_verify_icp51
	ajmp load_hex_file

cb_verify_icp51:
	acall icp51_save_R7_send_R4R5
	; kod operacji odczytu z flasha
	mov A, icp51_cmd_read_flash
	acall icp51_send_7bits
	; gotowi do odczytu
cb_verify_icp51_loop:
	acall icp51_recv_byte
	mov R2, A
	mov A, @R0
	cjne A, AR2, cb_verify_icp51_fail
	inc R0
	djnz R1, cb_verify_icp51_loop2
	; wysyłamy bit 1 czyli zakończenie operacji odczytu
	acall icp51_send_bit1
	ajmp cb_lv_code_G
cb_verify_icp51_fail:
	; wysyłamy bit 1 czyli zakończenie operacji odczytu
	acall icp51_send_bit1
	ajmp cb_lv_code_V
cb_verify_icp51_loop2:
	; wysyłamy bit 0 czyli kontynuacja operacji odczytu
	clr C
	acall icp51_send_bit
	sjmp cb_verify_icp51_loop

;-----------------------------------------------------------
; LB
if	USE_HELP_DESC
	dw	s_help_LB
endif
command_load_icp51_flash:
	acall ensure_no_args
	acall icp51_init
	mov DPTR, #cb_load_icp51
	ajmp load_hex_file

cb_load_icp51:
	acall icp51_save_R7_send_R4R5
	; kod operacji zapisu do flasha
	mov A, #21h
	acall icp51_send_7bits
	; gotowi do zapisu
cb_load_icp51_loop:
	mov A, @R0
	acall icp51_send_byte
	inc R0
	djnz R1, cb_load_icp51_loop2
	; wysyłamy bit 1 czyli zakończenie operacji zapisu
	acall icp51_send_bit1
	ajmp cb_lv_code_G
cb_load_icp51_loop2:
	; wysyłamy bit 0 czyli kontynuacja operacji zapisu
	clr C
	acall icp51_send_bit
	sjmp cb_load_icp51_loop

;-----------------------------------------------------------
; K [kod operacji]
if	USE_HELP_DESC
	dw	s_help_K
endif
command_icp51_chip_erase:
	mov R2, #0
	mov R3, #22h	; kod operacji kasowania tylko flasha
	acall get_hex_arg
	jc command_icp51_chip_erase_noargs
	; przyjmujemy tylko 1 bajt z kodem operacji (np. 26h = kasuj wszystko)
	mov A, R2
	jz command_icp51_chip_erase_ok
	ajmp error_extarg
command_icp51_chip_erase_ok:
	acall ensure_no_args
command_icp51_chip_erase_noargs:
	acall icp51_init
	; wysyłamy 00,00,R3,1 (8+8+7+1 bitów) ale ostatni bit bardzo długo
	clr A
	acall icp51_send_byte
	clr A
	acall icp51_send_byte
	mov A, R3
	acall icp51_send_7bits
	clr A
	acall icp51_send_byte
	setb C
	ajmp icp51_send_bit_slow

;===========================================================
; Procedury wspólne

; W razie błędu wypisuje komunikat i nie wraca!
; Niszczy A, C, R6, R7
icp51_init:
	jb flag_icp51_init, icp51_init_OK
	; wysyłamy 5AA5
	mov A, #5Ah
	acall icp51_send_byte
	mov A, #0A5h
	acall icp51_send_byte
	; odczytujemy bajt sygnatury - po wysłaniu 00,00,0B (8+8+7 bitów) powinniśmy dostać DA
	clr A
	acall icp51_send_byte
	clr A
	acall icp51_send_byte
	mov A, #0Bh
	acall icp51_send_7bits
	acall icp51_recv_byte
	acall icp51_send_bit1
	cjne A, #0DAh, icp51_init_not_DA
	setb flag_icp51_init
icp51_init_OK:
	ret
icp51_init_not_DA:
	mov DPTR, #s_error_icp51err
	bjmp print_error_then_prompt

; Przepisuje R7 do R1 i wysyła R4 i R5 do mikrokontrolera
; Niszczy A, C, R6, R7, R1
icp51_save_R7_send_R4R5:
	mov A, R7
	mov R1, A
	; starszy bajt adresu
	mov A, R4
	acall icp51_send_byte
	; młodszy bajt adresu
	mov A, R5
	ajmp icp51_send_byte
