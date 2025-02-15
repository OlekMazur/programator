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
; Procedury obsługi poleceń LR i VR
; LR zapisuje dane do RAMu hosta, a VR weryfikuje je

;-----------------------------------------------------------
; LR
if	USE_HELP_DESC
	dw	s_help_LR
endif
command_load_host_RAM:
	setb F0
	sjmp command_lv_host_RAM

;-----------------------------------------------------------
; VR
if	USE_HELP_DESC
	dw	s_help_VR
endif
command_verify_host_RAM:
	clr F0
command_lv_host_RAM:
	mov DPTR, #cb_lv_host_RAM
	ajmp load_hex_file

; Callback dla load_hex_file
; F0=1 -> load
; F0=0 -> verify
cb_lv_host_RAM:
	mov A, R4
	jnz cb_lv_code_A	; adresy w RAM >= 100h nie są dostępne
	mov A, R5
	mov R1, A
	; load -> kopiowanie R7 bajtów spod R0 do R1
	; verify -> porównywanie R7 bajtów od R0 z tymi od R1
cb_lv_host_RAM_loop:
	mov A, @R0	; A = kolejny bajt z bufora odebranego z rekordu Intel Hex
	jnb F0, cb_lv_host_RAM_no_copy
	mov @R1, A
cb_lv_host_RAM_no_copy:
	mov R2, A
	mov A, @R1
	cjne A, AR2, cb_lv_code_V
	inc R0
	inc R1
	djnz R7, cb_lv_host_RAM_loop
	sjmp cb_lv_code_G

cb_lv_code_A:
	mov A, #'A'
	ret
