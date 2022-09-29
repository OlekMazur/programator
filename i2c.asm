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
; Copyright (c) 2006, 2018, 2022 Aleksander Mazur
;
; Obsługa I2C / Two-Wire w trybie MASTER
; na podstawie "Interfacing AT24CXX Serial EEPROMs with AT89CX051 MCU" firmy Atmel

;-----------------------------------------------------------
; Opóźnienie adekwatne do szybkości działania I2C
i2c_delay	macro
	nop
endm

;-----------------------------------------------------------
; START na I2C
; zwraca C=1 jeśli wystąpił błąd
; niszczy A, C
i2c_start:
	; Send START, defined as high-to-low SDA with SCL high.
	; Return with SCL, SDA low.
	; Returns CY set if bus is not available.
	setb SCL
	setb SDA
	; Verify bus available.
	jnb SCL, i2c_error	; jump if not high
	jb SDA, i2c_start_cont
	; After an interruption in protocol, power loss or system reset, any
	; 2-wire part can be reset by following these steps:
	; 1. Clock up to 9 cycles.
	; 2. Look for SDA high in each cycle while SCL is high.
	; 3. Create a start condition.
	;push ACC
	mov A, #9		; bit count
i2c_reset_loop:
	clr SCL			; drop clock
	i2c_delay		; enforce SCL low and data setup
	setb SCL		; raise clock
	i2c_delay		; enforce SCL high
	jb SDA, i2c_start_cont_pop
	djnz ACC, i2c_reset_loop	; next bit
	;pop ACC
i2c_error:
	setb C			; set error flag
	ret
i2c_start_cont_pop:
	;pop ACC
i2c_start_cont:
	clr C			; clear error flag
	i2c_delay		; enforce setup delay and cycle delay
	clr SDA
	i2c_delay		; enforce hold delay
i2c_clr_SCL_ret:
	clr SCL
	ret

;-----------------------------------------------------------
; Odbiera bajt z I2C do akumulatora
; niszczy A, C, R6
i2c_shin:
	; Shift in a byte from the AT24Cxx, most significant bit first.
	; SCL expected low on entry. Return with SCL low.
	; Returns received data byte in A.
	setb SDA		; make SDA an input
	mov R6, #8		; bit count
i2c_shin_bit:
	i2c_delay		; enforce SCL low and data setup
	setb SCL		; raise clock
	i2c_delay		; enforce SCL high
	mov C, SDA		; input bit
	rlc A			; move bit into byte
	clr SCL			; drop clock
	djnz R6, i2c_shin_bit	; next bit
	ret

;-----------------------------------------------------------
; Wysyła bajt z akumulatora na I2C
; Niszczy A, C, R6
; Zwraca C=1 w razie błędu, C=0 po sukcesie
i2c_shout:
	; Shift out a byte to the AT24Cxx, most significant bit first.
	; SCL, SDA expected low on entry. Return with SCL low.
	; Called with data to send in A.
	; Returns CY set to indicate failure by slave to acknowledge.
	; Destroys A.
	mov	R6, #8		; bit counter
i2c_shout_bit:
	rlc A			; move bit into CY
	mov SDA, C		; output bit
	i2c_delay		; enforce SCL low and data setup
	setb SCL		; raise clock
	i2c_delay		; enforce SCL high
	clr SCL			; drop clock
	djnz R6, i2c_shout_bit	; next bit
	setb SDA		; release SDA for ACK
	i2c_delay		; enforce SCL low and tAA
	setb SCL		; raise ACK clock
	i2c_delay		; enforce SCL high
	mov C, SDA		; get ACK bit
	sjmp i2c_clr_SCL_ret	; drop ACK clock

;-----------------------------------------------------------
; ACK na I2C
i2c_ACK:
	; Clock out an acknowledge bit (low).
	; SCL expected low on entry. Return with SCL, SDA low.
	clr SDA			; ACK bit
	i2c_delay		; enforce SCL low and data setup
	setb SCL		; raise clock
	i2c_delay		; enforce SCL high
	sjmp i2c_clr_SCL_ret	; drop clock

;-----------------------------------------------------------
; NAK na I2C
i2c_NAK:
	; Clock out a negative acknowledge bit (high).
	; SCL expected low on entry. Return with SCL low, SDA high.
	setb SDA		; NAK bit
	i2c_delay		; enforce SCL low and data setup
	setb SCL		; raise clock
	i2c_delay		; enforce SCL high
	sjmp i2c_clr_SCL_ret	; drop clock

;-----------------------------------------------------------
; STOP na I2C
i2c_stop:
	; Send STOP, defined as low-to-high SDA with SCL high.
	; SCL expected low on entry. Return with SCL, SDA high.
	clr	SDA
	i2c_delay		; enforce SCL low and data setup
	setb SCL
	i2c_delay		; enforce setup delay
	setb SDA
	ret
