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
; Funkcje pomocnicze, głównie do obsługi wejścia (poleceń)

;-----------------------------------------------------------
; Wczytuje 2 opcjonalne argumenty z linii poleceń - 2 liczby szesnastkowe.
; Pierwszą do R4:R5, drugą do R2:R3.
; Rejestry te powinny być zainicjowane domyślnymi wartościami na odwrót,
; tj. domyślna wartość pierwszej w R2:R3, a drugiej w R4:R5.
; R1 = adres znaku przed liczbą (spodziewana spacja)
; R0 = adres pierwszego miejsca za linią poleceń
; Nie wraca, jeśli wystąpi błąd.
get_2_hex_numbers:
	; wczytujemy argument 1 do R2:R3
	acall get_hex_arg
	; zamiana R2:R3 z R4:R5
	mov A, R3
	xch A, R5
	mov R3, A
	mov A, R2
	xch A, R4
	mov R2, A
	; wczytujemy argument 2 do R2:R3
	acall get_hex_arg
	; nie powinno być żadnych więcej argumentów
	;ajmp ensure_no_args
;-----------------------------------------------------------
; Wraca tylko jeśli polecenie nie ma argumentów.
; W przeciwnym razie wypisuje błąd i wraca do pętli głównej.
; Niszczy A, C
ensure_no_args:
	acall get_args_len
	jz ret1
error_extarg:
	mov DPTR, #s_error_extarg
	ajmp print_error_then_prompt

;-----------------------------------------------------------
; Wywołuje get_2_hex_numbers i subtract_address_range
get_address_range:
	acall get_2_hex_numbers
	;sjmp subtract_address_range
;-----------------------------------------------------------
; Odejmuje adres początkowy (R4:R5) od końcowego (R2:R3);
; jeśli wynik jest ujemny -> wypisuje błąd i nie wraca;
; jeśli wynik jest prawidłowy, nadpisuje adres końcowy liczbą bajtów
; w zakresie od R4:R5 do R2:R3 włącznie, tj. R2:R3 = R2:R3 - R4:R5 + 1.
; Niszczy A, C
subtract_address_range:
	clr C
	mov A, R3
	subb A, R5
	mov R3, A
	mov A, R2
	subb A, R4
	mov R2, A
	jc error_illopt_fwd
	mov A, R3
	add A, #1
	mov R3, A
	mov A, R2
	addc A, #0
	mov R2, A
	ret
error_illopt_fwd:
	ajmp error_illopt

;-----------------------------------------------------------
; Oblicza długość argumentów w linii poleceń, tj.
; A = R0 - R1
; Niszczy C
get_args_len:
	mov A, R0
	clr C
	subb A, R1
ret1:
	ret

;-----------------------------------------------------------
; Dekoduje cyfrę szesnastkową podaną w ASCII
; A = znak ASCII
; Zwraca C=0 i wartość cyfry w A, lub C=1 jeśli to nie cyfra (wtedy A trzyma starą wartość!)
convert_hex_digit:
	cjne A, #'0', convert_hex_digit2
convert_hex_digit2:
	jc ret4	; A < '0' -> błąd
	cjne A, #'9' + 1, convert_hex_digit3
convert_hex_digit3:
	jc convert_hex_digit_09	; '0' <= A < '9' + 1 -> 0..9
	cjne A, #'A', convert_hex_digit4
convert_hex_digit4:
	jc ret4	; '9' + 1 <= A < 'A' -> błąd
	cjne A, #'F' + 1, convert_hex_digit5
convert_hex_digit5:
	jc convert_hex_digit_AF	; 'A' <= A < 'F' + 1 -> A..F
	; A >= 'F' + 1 -> błąd
	setb C
ret4:
	ret
convert_hex_digit_AF:
	add A, #'0' - 'A' + 10
convert_hex_digit_09:
	add A, #0 - '0'
	clr C
	ret

if	USE_SPI
;-----------------------------------------------------------
; Konwertuje liczbę w A (< 100) na BCD
; Niszczy B
convert_to_bcd:
	mov B, #10
	div AB
	swap A
	orl A, B
	ret
endif

;-----------------------------------------------------------
; Wypisuje rekordy Hex dla obszaru pamięci o długości R2:R3 od R4:R5
; (R2:R3=0000 oznacza pełne 64KB).
; Niszczy A, B, C, R0
; Uaktualnia R4/R5, zeruje R2/R3
; DPTR = callback dostający w R7 potrzebną ilość bajtów od adresu R4:R5
;  i zwracający przez R0 adres, gdzie te dane wczytał. C=0 gdy sukces.
;  W razie błędu callback może przerwać zrzut zwracając C=1 i liczbę
;  pozostałych do zrzucenia (nieudanych) bajtów w R7, a w DPTR komunikat błędu.
;  Nie może zniszczyć R2, R3, R4, R5, B, a jeśli zwraca C=0, to też DPTR.
dump_hex_file:
	mov A, R2
	orl A, R3
	jz dump_hex_file_loop_limit	; 0 -> 64KB
dump_hex_file_loop:
	; R4:R5 = bieżący adres zrzutu (aktualizowane przez dump_hex)
	; R2:R3 = ile bajtów pozostało zrzucić
	mov A, R2
	jnz dump_hex_file_loop_limit	; zostało > 255 bajtów
	mov A, R3
	jz dump_hex_file_finish
	cjne A, #input_end - input, dump_hex_file_loop2
dump_hex_file_loop2:
	jc dump_hex_file_loop_all	; zostało < 20 bajtów
dump_hex_file_loop_limit:
	mov A, #input_end - input	; nie więcej niż 20h bajtów naraz w jednej linii
dump_hex_file_loop_all:
	mov B, A	; w B przechowujemy długość na potem (R7 zostanie wyzerowany przez dump_hex)
	mov R7, A
	; wywołujemy callback, który ustawi nam R0
	clr A
	acall jmp_dptr
	jnc dump_hex_file_loop_ok
	; procedura z callbacka napotkała błąd - w R7 jest liczba bajtów, których nie udało się pobrać
	mov A, B
	clr C
	subb A, R7	; A = liczba bajtów, które udało się pobrać
	jnz dump_hex_file_part
dump_hex_file_error:
	; w DPTR musi już być komunikat błędu
	ajmp print_error_then_prompt
dump_hex_file_part:
	mov B, A
	setb C
dump_hex_file_loop_ok:
	push PSW	; zachowujemy flagę C - jeśli jest tam 1, to po wypisaniu rekordu idziemy do print_error_then_prompt
	mov R7, B
	mov R6, #0	; rekord typu 0
	acall dump_hex_rec
	; R2:R3 -= B
	mov A, R3
	clr C
	subb A, B
	mov R3, A
	jnc dump_hex_file_no_carry1
	dec R2
dump_hex_file_no_carry1:
	; R4:R5 += B
	mov A, R5
	add A, B
	mov R5, A
	jnc dump_hex_file_no_carry2
	inc R4
dump_hex_file_no_carry2:
	pop PSW
	jnc dump_hex_file_loop
	; w DPTR musi już być komunikat błędu
	ajmp print_error_then_prompt
dump_hex_file_finish:
	; koniec zrzutu - jeszcze tylko rekord typu 01 (:00000001FF)
	clr A
	mov R4, A
	mov R5, A
	mov R7, A
	inc A
	mov R6, A
	; R0 jest nieważny gdy długość (R7) = 0
;-----------------------------------------------------------
; Wypisuje linię (rekord) Intel Hex.
; R0 = adres danych do zrzucenia w pamięci
; R4:R5 = adres danych źródłowych (do wypisania)
; R6 = typ rekordu
; R7 = długość zrzutu
; Niszczy A, C, R6
; Zeruje R7, aktualizuje R0
dump_hex_rec:
	; :llaaaattdddddd...ddxx
	acall uart_send_colon
	mov A, R7
	acall uart_send_hex_byte
	mov A, R4
	acall uart_send_hex_byte
	mov A, R5
	acall uart_send_hex_byte
	mov A, R6
	acall uart_send_hex_byte
	; teraz w R6 będziemy liczyć sumę kontrolną
	mov A, R7
	add A, R4
	add A, R5
	add A, R6
	mov R6, A
	mov A, R7
	jz dump_hex_checksum
dump_hex_loop:
	mov A, @R0
	acall uart_send_hex_byte
	mov A, @R0
	add A, R6
	mov R6, A
	inc R0
	djnz R7, dump_hex_loop
dump_hex_checksum:
	mov A, R6
	cpl A
	inc A
	; A = "two’s complement"
	acall uart_send_hex_byte
	; możnaby tak, ale zniszczylibyśmy DPTR
	;mov DPTR, #s_enter
	;ajmp uart_send_rom
uart_send_crlf:
	mov A, #13
	acall uart_send_char
	mov A, #10
	ajmp uart_send_char

;-----------------------------------------------------------
; Wczytuje rekord Intel Hex do #input
; Jeśli uda się wczytać dane z rekordu, zwraca C=0 i:
; - rozmiar wczytanych danych w R7
; - adres początkowy w R4:R5
; - początek bufora w RAM w R0 (czyli #input)
; W razie błędu zwraca C=1 i niezerowy kod błędu (znak do wypisania) w A.
; Jeśli napotkaliśmy rekord końcowy, to danych nie ma, ale jest sukces
; - wówczas zwraca C=1 i A=0. Należy wtedy wrócić do pętli głównej programu.
; W innych przypadkach można wołać niniejszą funkcję jeszcze raz - ona
;  zignoruje wszystko do następnego dwukropka i będzie próbowała
;  zinterpretować następny rekord.
; Kody błędów:
; "H–Invalid Intel Hex record format: Intel Hex record contains a nonhex character."
; "L–Invalid Intel Hex record length: Intel Hex record length exceeds
;  allowable length [20 bytes (type 0); 0 bytes (type 1 EOF)]."
; "S–Invalid checksum in Intel Hex record: Intel Hex record contains a
;  checksum that does not correspond to its hex record. This error is
;  caused by manual edits to the Intel Hex file or a compiler error."
; "R–Invalid Intel Hex record type: ROM loader only accepts Intel Hex
;  record types 00 and 01 in standard Intel Hex format; make sure the
;  assembler/compiler is not configured for Intel Extended Hex or HEX-386 format."
; Niszczy A, C, R0, R2, R3, R4, R5, R6, R7
receive_hex_rec:
	; "All characters are discarded before the header character <:> is read."
	; "All characters following the record checksum and prior to the next <:> are discarded."
	acall uart_receive_char
	cjne A, #':', receive_hex_rec
	; :llaaaattdddddd...ddxx
	acall receive_hex_byte
	jc receive_hex_rec_error_H	; nie hex
	cjne A, #input_end - input + 1, receive_hex_rec2
receive_hex_rec2:
	jnc receive_hex_rec_error_L	; za długi rekord
	mov R3, A	; R3 = długość rekordu (na potrzeby pętli poniżej)
	mov R7, A	; R7 = długość rekordu (do zwrócenia)
	acall receive_hex_byte
	jc receive_hex_rec_error_H	; nie hex
	mov R4, A	; R4 = starszy bajt adresu początkowego
	acall receive_hex_byte
	jc receive_hex_rec_error_H	; nie hex
	mov R5, A	; R5 = młodszy bajt adresu początkowego
	acall receive_hex_byte
	jc receive_hex_rec_error_H	; nie hex
	; A = typ rekordu (0 - dane, 1 - koniec)
	jz receive_hex_rec_payload
	setb C
	dec A
	jz ret7	; A=0 i C=1 oznacza EOF
	; nieprawidłowy typ rekordu
	mov A, #'R'
ret7:
	ret
receive_hex_rec_payload:
	; w R6 policzymy sobie sumę kontrolną
	mov A, R7
	add A, R4
	add A, R5
	mov R6, A
	mov R0, #input	; R0 = pozycja w buforze
	mov A, R7
	jz receive_hex_rec_checksum
receive_hex_rec_loop:
	acall receive_hex_byte
	jc receive_hex_rec_error_H	; nie hex
	mov @R0, A
	add A, R6
	mov R6, A	; aktualizacja sumy kontrolnej
	inc R0
	djnz R3, receive_hex_rec_loop
receive_hex_rec_checksum:
	; wszystkie bajty odebrane, teraz powinna być suma kontrolna
	acall receive_hex_byte
	jc receive_hex_rec_error_H	; nie hex
	add A, R6
	jnz receive_hex_rec_error_S
	mov R0, #input
receive_hex_rec_eof:
	clr C
	ret
receive_hex_rec_error_H:
	; C=1
	mov A, #'H'
	ret
receive_hex_rec_error_L:
	setb C
	mov A, #'L'
	ret
receive_hex_rec_error_S:
	setb C
	mov A, #'S'
	ret

;-----------------------------------------------------------
; Wczytuje dwucyfrową liczbę szesnastkową jako bajt
; Zwraca C=0 i liczbę w A, albo C=1, jeśli napotkano nieprawidłowe znaki.
; Niszczy A, C, R2
receive_hex_byte:
	acall uart_receive_char
	acall convert_hex_digit
	jc ret8
	swap A
	mov R2, A
	acall uart_receive_char
	acall convert_hex_digit
	orl A, R2
ret8:
	ret

;-----------------------------------------------------------
; Uogólniona procedura przetwarzania rekordów Intel Hex
; DPTR = callback dostający każdorazowo R7 bajtów (>0) zaczynając od R0
;  do wpisania pod adres R4:R5
; Callback musi zwrócić znak ACK/NAK w A.
; Niezależnie od kodu (sukcesu/porażki) o ewentualnej kontynuacji
;  decyduje użytkownik po drugiej stronie portu szeregowego.
; Chyba, że callback zwróci A=0 - wtedy funkcja przerywa działanie bez ACK/NAK.
load_hex_file:
	acall ensure_no_args
load_hex_file_loop:
	acall receive_hex_rec
	jc load_hex_file_check
	; pod R0 jest R7 bajtów do zapisu pod adres R4:R5
	; (adres z R4:R5 jest w dziedzinie specyficznej dla callbacka)
	mov A, R7
	jz load_hex_rec_empty	; zabezpieczenie przed rekordem o zerowej długości
	clr A
	acall jmp_dptr
load_hex_file_check:
	jz ret8
load_hex_file_error:
	; w A jest znak ACK/NAK
	acall uart_send_char
	sjmp load_hex_file_loop
load_hex_rec_empty:
	mov A, #'G'
	sjmp load_hex_file_error

;-----------------------------------------------------------
; Dekoduje liczbę szesnastkową podaną w ASCII do rejestrów R2:R3.
; R1 = adres znaku przed liczbą (spodziewana spacja)
; R0 = adres pierwszego miejsca za argumentem
; Jeśli nie ma żadnego argumentu (R0==R1), zwraca C=1 nie ruszając R2/R3.
; Jeśli argument jest, ale zły, to funkcja nie wraca.
; W przeciwnym razie zwraca C=0 i liczbę w R2:R3 oraz przesuwa R1
;  na pierwszą pozycję za zdekodowaną liczbę.
; Niszczy A, B, C, R7
get_hex_arg:
	acall get_args_len
	setb C
	jz ret3		; brak argumentu
	mov R7, A	; R7 = długość tekstu, której nie możemy przekroczyć
	; pierwszy znak powinien być spacją
	cjne @R1, #' ', error_notspc
	djnz R7, get_hex_arg_ok
	; za spacją nic nie ma
error_extspc:
	mov DPTR, #s_error_extspc
	ajmp print_error_then_prompt
get_hex_arg_ok:
	inc R1
	; zerujemy R2:R3, bo będziemy or'ować
	clr A
	mov R2, A
	mov R3, A
get_hex_arg_loop:
	mov A, @R1
	cjne A, #' ', get_hex_arg_loop_nospc
	; wychodzimy z R1 wskazującym na spację, C=0 w wyniku cjne
	; TODO: jeśli to jest druga spacja zaraz za pierwszą (bez żadnej cyfry), to powinien być błąd E:NOTHEX
ret3:
	ret
get_hex_arg_loop_nospc:
	acall convert_hex_digit
	jc error_nothex
	inc R1	; przechodzimy za właśnie przetworzoną cyfrę
	mov B, A	; B = wczytana cyfra Y (0-F)
	; R2:R3 = UV:WX -> VW:XY
	mov A, R3	; A = WX
	swap A		; A = XW
	push ACC
	anl A, #0F0h	; A = X0
	orl A, B	; A = XY
	mov R3, A	; R3 = XY
	mov A, R2	; A = UV
	swap A		; A = VU
	anl A, #0F0h	; A = V0
	mov B, A	; B = V0
	pop ACC		; A = XW
	anl A, #0Fh	; A = 0W
	orl A, B	; A = VW
	mov R2, A	; R2 = VW
	djnz R7, get_hex_arg_loop
	clr C
	ret
error_notspc:
	mov DPTR, #s_error_notspc
	ajmp print_error_then_prompt
error_nothex:
	mov DPTR, #s_error_nothex
	ajmp print_error_then_prompt

if ICP51_W79EX051 or USE_1WIRE or USE_I2C
;-----------------------------------------------------------
; Dekoduje dwucyfrową liczbę szesnastkową podaną w ASCII i zwraca C=0,
; albo - jeśli na pierwszej pozycji jest inny znak niż cyfra szesnastkowa
; - zwraca kod tego znaku i C=1. Jeśli R1==R0, zwraca C=1 i A=0.
; Jeśli zamiast drugiej cyfry jest nieprawidłowy znak, to nie wraca.
; R1 = adres pierwszego znaku do zdekodowania
; R0 = adres pierwszego miejsca za argumentem
; Niszczy A, C, R7, przesuwa R1 za zdekodowane znaki
get_hex_or_char:
	acall get_args_len
	setb C
	jz ret5		; koniec argumentów
	mov A, @R1
	inc R1
	acall convert_hex_digit
	jc ret5		; nie-cyfra
	swap A
	mov R7, A
	acall get_args_len
	jz error_argreq_fwd	; brak drugiej cyfry
	mov A, @R1
	inc R1
	acall convert_hex_digit
	jc error_nothex	; drugi znak to nie cyfra
	orl A, R7
ret5:
	ret
error_argreq_fwd:
	ajmp error_argreq

endif
