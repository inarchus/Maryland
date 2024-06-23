;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                    			keyboard.asm					      ;;;;
;;;;																	  ;;;;
;;;;	Implements the ps2 functionality and IRQ1 for the keyboard        ;;;;
;;;;		translates the scancodes to ascii or some other code for use  ;;;;
;;;;																	  ;;;;
;;;;		     										Eric Hamilton	  ;;;;
;;;; 													CR: 6/21/2024  	  ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extern getchar
extern getchar_pressed
extern ps2_keyboard_irq1
extern keyboard_flags

; from kernel.asm
extern display_hex_byte
extern print_hex_dword
extern printstr
extern printchar

; from interrupts.asm
extern set_interrupt_callback

section .text

E0_EXTENDED_CODE 	equ 	0x01
E1_EXTENDED_CODE 	equ		0x02

ps2_keyboard_irq1:
	cli
	pushad	
	
	; we'll read all of the characters into a raw buffer, without any separation
	; the reason for this is that sometimes if you type fast enough, two scancodes
	; neither of them extended i.e. 0xe0 are sent, so the first one will be processed
	; the second one can get lost if it's grouped with the first scancode.  
	
	movzx ebx, byte [raw_scancode_write]			; store temporarily the original location. We'll start processing from here. 
	lea edi, [raw_scancode_buffer + ebx]
	
	mov cl, byte [raw_scancode_write]
	
	.read_scancode_loop:		; just read all of the scancodes into the buffer, don't worry about what they are yet
		in al, 0x64				; is there a character to read?
		test al, 1				
		jz .end_keyboard_irq1
		in al, 0x60				; read it in (alternatively could use insw)
		test al, al 			; ensure it's not null but it shouldn't be anyway
		jz .read_scancode_loop	; if it is bypass all things and go back to read the next character
		stosb					; store al into current_scancode, increment esi to the next character.  
		inc cl					; allow it to overflow if necessary. 
		jno .read_scancode_loop
		mov esi, raw_scancode_buffer
	jmp .read_scancode_loop
	
	.end_keyboard_irq1:
	mov byte [raw_scancode_write], cl		; update the index
		
	; end of interrupt
	mov al, 0x20
	out 0x20, al

	popad
	sti
	iretd


process_scancodes:
	pushad
	movzx ebx, byte [start_process_raw_scwr]		; this is the current position of the next scancode to process.  

	movzx ecx, byte [queue_write_index]				; this is the index for edi/scancode_queue

	lea esi, [raw_scancode_buffer + ebx]			; reset to the start location of the current scancodes
	lea edi, dword [scancode_queue + 8 * ecx]		; load into edi the current place to write a new scancode

	mov bh, byte [raw_scancode_write]				; this is the current position of the write index, should be zero
	
	cmp bl, bh										; if it's already equal, don't load anything, don't process any new symbols
	je .skip_process_loop
	mov dx, 0x1400
	
	.process_loop:									; loop while bl != bh
		mov [edi], dword 0							; zero out the scancode queue
		mov [edi + 4], dword 0						; 

		cmp byte [esi], 0xe0						; do not lodsb otherwise we'll have to do some more complicated calculations
		je .process_extended_code
		
		lodsb										; load esi -> al from the raw_scancode_buffer
		stosb										; store al -> edi to the scancode_queue
		add edi, 7									; add  7 to edi to make up for the rest of the characters unused
		
		jmp .continue_process_loop
		
		.process_extended_code:
			lodsw
			stosw
			
			;cmp byte [esi], 0xe0
			;jne .bypass_double_extended_e0
			;	lodsw
			;	stosw
			;.bypass_double_extended_e0:
			
			add edi, 6
			
		.continue_process_loop:
		
		inc bl
		jno .no_reset_esi
			mov esi, raw_scancode_buffer
		.no_reset_esi:
		
		inc cl
		jno .no_reset_edi
			mov edi, scancode_queue
		.no_reset_edi:
		
		cmp bl, bh									; bl = currently reading location, bh = next write location for scancode, stop if equal
	jne .process_loop
	
	mov byte [start_process_raw_scwr], bh
	mov byte [queue_write_index], cl
	
	.skip_process_loop:
	
	popad
	ret

increment_buffer_index:
	inc byte [queue_write_index]
	jno .bypass_reset_edi
		mov edi, scancode_queue			; reset the edi to the first element in the scancode_queue
	.bypass_reset_edi:
	ret

wait_for_scancode:
	call process_scancodes
	
	xor eax, eax
	push ebx
	mov bl, [queue_write_index]		; there is a condition where if 256 extra characters are typed then it will match again...
	mov bh, [queue_read_index]
	cmp bl, bh
	je .bypass_increment
	inc eax
	.bypass_increment:
	pop ebx
	ret
	
	
get_next_scancode:
	call process_scancodes

	movzx ebx, byte [queue_read_index]
	mov eax, dword [scancode_queue + 8 * ebx]
	mov ebx, dword [scancode_queue + 8 * ebx + 4]
	inc byte [queue_read_index]
	ret
	
	
getchar_pressed:
	call getchar
	mov eax, [getchar_val]		; obviously this shouldn't need to be done, the result should come back to us in eax.
	
	test ah, 0x01
	jz getchar_pressed	; if zero then the character is a release
	test ah, 0x02		; if non-zero then it is a special character, not an ascii symbol
	jnz getchar_pressed
	cmp al, 0x80		; probably should set the 0x02 flag in ah but we'll fix that later as usual
	jae getchar_pressed ; this is an F1-F12 key, or some other key which is not translatable into ascii
	

	
	ret
	
getchar:
	; for the return of the ascii and extended codes [ah = codes][al = ascii or special code]
	; for the return of additional data
	push ebp
	mov ebp, esp
	sub esp, 8
	
	.wait_for_char:
		call wait_for_scancode
		test eax, eax
		jz .wait_for_char
	
	;; get a single code because most codes are singletons
	
	call get_next_scancode
	mov dword [ebp - 4], eax
	mov dword [ebp - 8], ebx
	;; displays
	push edx
	
	mov edx, 0x1808
	call display_hex_byte
	
	push ecx
	mov ecx, dword [ebp - 4]
	mov edx, 0x180c
	call print_hex_dword
	pop ecx
	pop edx
	;; end displays

	;; test to see if the code is 0xE1 or 0xE0
	cmp al, 0xe0
	je .check_single_extended_codes
	cmp al, 0xe1
	je .check_higher_extended_codes
	cmp al, 0x0
	je .getchar_exit
	
	xor ah, ah
	call check_control_keys 
	test ah, 2
	jnz .getchar_exit

	;; if we get here, then it is a singleton code, not extended
	mov ebx, eax
	call set_pressed_or_released

	movzx ebx, al 							; save the scancode in bl
	mov al, [single_scan_code_map + ebx]	; get the ascii code or special code
	call shift_translate					; tests for the shift code and does all shift translations.

	push edx
	mov edx, 0x1800
	call display_hex_byte
	pop edx
	mov dword [getchar_val], eax
	jmp .getchar_exit
	
	.check_single_extended_codes:
		mov ebx,  dword [ebp - 4]			; get the original scancode again, local variable on stack.
		
		mov esi, extended_keycodes
		xor eax, eax			; set the rest of eax to zero
		.test_single_loop:
			lodsb
			test al, al
			jz .getchar_exit
			shl ax, 8
			mov al, 0xe0			; first scancode for most of the extended keys
			cmp ax, bx				; compare the scancodes including the zeros
			je .found_single_code_pressed
			or ax, 0x8000			; 
			cmp ax, bx				; compare the scancodes including the zeros
			je .found_single_code_released

			add esi, 5
		jmp .test_single_loop
		
		mov ax, 0x0280				; special character, unidentified
		jmp .getchar_exit
		
		.found_single_code_pressed:
			xor eax, eax
			mov ah, 1
			jmp .continue_single_code
		.found_single_code_released:
			xor eax, eax
		.continue_single_code:
			add esi, 4			; ignore the scancode string
			lodsb				; get the next byte after the identity string which is the new fake-ascii code we've invented for those letters.  
			or ah, 0x02			; set special character

			mov ebx, dword [ebp - 4]
			mov [getchar_val], eax		; again this shouldn't be necessary
			
			jmp .getchar_exit
	
	.check_higher_extended_codes:
			
	.getchar_exit:
	add esp, 8		; cleanup the stack
	leave			; restore ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; set_pressed_or_released(al, ah) -> ah			modifies(ah)									  ;;;; 	
;;;; 	sets the pressed flag in ah, bit 0.															  ;;;; 	
;;;;	returns the value in ah										 								  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set_pressed_or_released:
	or ah, 1				; set pressed by default
	cmp al, 0x80
	jb pressed_key
		sub al, 0x80		; subtract 0x80 to get the pressed equivalent code and test for that. 
		and ah, ~0x01		; unset the pressed code
	pressed_key:
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; shift_translate(al, ah) -> eax			modifies(eax)									  		  ;;;; 	
;;;;		if shift changes the character, this function will determine if shift is pressed		  ;;;; 	
;;;;																 								  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
shift_translate:
	;	evaluates keyboard_flags for shift and then applies the proper transformation of ascii to the element in al. 
	; 	modifies eax
	push esi
	push ebx
	test word [keyboard_flags], 0x0003
	jz .shift_translate_end

	cmp al, 'a'
	jb .shift_translate_check_special
	cmp al, 'z'
	ja .shift_translate_check_special
	sub al, 0x20
	jmp .shift_translate_end
	
	.shift_translate_check_special:
	mov ebx, eax						; make a copy of the eax register
	mov esi, shift_symbol_translations	; 
	
	.shift_translate_loop:
		lodsw
		test ax, ax
		jz .shift_translate_end
		cmp al, bl
		je .shift_translate_found
	jmp .shift_translate_loop
	
	mov eax, ebx
	jmp .shift_translate_end
	
	.shift_translate_found:
		mov bl, ah
		mov eax, ebx
	.shift_translate_end:
	pop ebx
	pop esi
	ret


check_extended_control_keys:
	
	cmp al, 0x1c 						; keypad enter pressed
	jne ceckeys_kdiv
	mov al, 0x0a						; set newline
	and ah, 0xfd						; unset special character
	ret
	
	ceckeys_kdiv:
	cmp al, 0x35 						; keypad enter pressed
	jne ceckeys_check2
	mov al, 0x2f						; set newline
	and ah, 0xfd						; unset special character
	ret
	
	ceckeys_check2:
	cmp al, 0x1d						; right control pressed
	jne ceckeys_check3
	or word [keyboard_flags], 0x0008 ;  turn on bit 3
	ret
	
	ceckeys_check3:
	cmp al, 0x38						; right control pressed
	jne cec_return
	or word [keyboard_flags], 0x0020 ;  turn on bit 5
	ret
	
	cec_return:
	ret
	

check_control_keys:
	or ah, 0x02
	
	cmp al, 0x2a 	; left shift pressed
	jne getchar_bypass_check_p1
	or word [keyboard_flags], 0x0001 ;  turn on bit 0
	ret
	
	getchar_bypass_check_p1:
	cmp al, 0x36 	; right shift pressed
	jne getchar_bypass_check_p2
	or word [keyboard_flags], 0x0002 ;  turn on bit 1
	ret

	getchar_bypass_check_p2:
	cmp al, 0x1d 	; left control pressed
	jne getchar_bypass_check_p3
	or word [keyboard_flags], 0x0004 ;  turn on bit 2
	ret

	getchar_bypass_check_p3:
	cmp al, 0x38 	; left alt pressed	
	jne getchar_bypass_check_r0
	or word [keyboard_flags], 0x0010 ;  turn on bit 4
	ret

	getchar_bypass_check_r0:
	cmp al, 0xaa 	; left shift released
	jne getchar_bypass_checkr1
	and word [keyboard_flags], 0xFFFE ;  turn off bit 0	
	ret

	getchar_bypass_checkr1:
	cmp al, 0xb6 	; right shift released
	jne getchar_bypass_checkr2
	and word [keyboard_flags], 0xFFFD ;  turn off bit 1	
	ret

	getchar_bypass_checkr2:
	cmp al, 0x9d 	; left control released
	jne getchar_bypass_checkr3
	and word [keyboard_flags], 0xFFFB ;  turn off bit 2
	ret

	getchar_bypass_checkr3:
	cmp al, 0xb8 	; left alt released	
	jne getchar_bypass_checks
	and word [keyboard_flags], 0xFFEF ;  turn off bit 4
	ret
	

	getchar_bypass_checks:
	and ah, 0xFD ;  not special
	mov bl, al ; save the original scancode
	
	ret



section .data
	%include "ps2map.asm"
	keyboard_flags 			dw 0x0000 ; [ - - - - - CAPL SCRL ] [-, -, RALT, LALT, RCTRL, LCTRL, RSHIFT, LSHIFT] ; where to put insert?
	queue_write_index		db 0x0
	queue_read_index		db 0x0
	raw_scancode_write		db 0x0
	raw_scancode_read		db 0x0
	start_process_raw_scwr	db 0x0
	getchar_val				dd 0x0
section .bss
	scancode_queue			resq 256
	raw_scancode_buffer		resb 256	; just let it overflow...  
	
	