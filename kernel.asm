;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    				kernel.asm																					    ;;;;
;;;;																																								;;;;
;;;;		This code is the entry point and provides basic functionality for a 32-bit kernel of Maryland															;;;;
;;;;																																			Eric Hamilton		;;;;
;;;;																																						  		;;;;
;;;;																																						  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; still to do with keyboard driver: fix the function keys, scroll lock, pause, caps lock probably too
; shift + space doesn't seem to work, keypad enter isn't working perfectly either.  F[i] keys not implemented
; get gdb + qemu working for faster debugging
; figure out how to control where on the floppy everything goes.  
;	try to get PIO working for the floppy drive read command as well, bypass the need for DMA
; 	add support for floppy controller version 0x81 rather than 0x90 described on osdev.net [no idea where to find documentation for that]
; 	
;	here's a list of QEMU options that seems to be not documented in the official QEMU site anymore
;	https://qemu.weilnetz.de/w32/2012/2012-12-04/qemu-doc.html
[bits 32]

extern empty_string
extern kernel_entry
extern cgetline
extern cprintline
extern cstrings_equal
extern hex_dump
extern print_string
extern getchar_pressed
extern print_decimal

extern clear_screen

extern extended_code_str

extern single_scan_code_map
extern getchar_pressed
extern string_length
extern main_shell
extern printline
extern printlinef
extern printstr
extern printstrf
extern strings_equal
extern print_hex_word
extern chex_to_number
extern startswith

extern nibble_to_hexchar
extern print_hex_dword 			; C -> ASM
extern display_stack_values
extern print_hex_byte
extern print_hex_word
extern print_hex_dword
extern hex_str_to_value
extern display_hex_byte
extern display_ascii_characters

; from rtc.asm
extern rtc_display_datetime
extern rtc_get_tick
extern rtc_enable
;extern rtc_display_byte

; from pit.asm
extern pit_interrupt_irq0
extern pit_wait
extern configure_pit
;extern pit_interrupt_table_entry

; from pic8259.asm
extern configure_pic
extern display_pic_registers

; from interrupts.asm
extern configure_interrupt_descriptor_table
extern set_interrupt_callback

section .text
kernel_entry:
	mov esp, 0x0a0000		; set the stack up to 10 MB so that we have plenty of room
	mov ax, 0x10			; 0x10 is the data segment
	mov es, ax
	mov ds, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	call clear_screen
	
	xor dx, dx
	mov esi, protected_mode_string
	call printline
	
	call configure_interrupt_descriptor_table		; calls lidt
	; we can add some safety checks to determine if sse exists on the machine.  
	call enable_sse			; currently really enabling MMX more than SSE, but we should see what is possible.  
	
	call configure_pit		; Programmable Interval Timer IRQ0
	call rtc_enable			; Real Time Clock IRQ 8

	; configure the PIC to use the PIT, Floppy Drive and RTC for now, add more features
	call configure_pic		; PICs allow IRQs to flow from hardware to the processor as interrupts

	push instring
	call main_shell

clear_screen:
	push ecx
	push edx
	push esi 
	
	mov cx, 24
	xor dx, dx
	mov esi, empty_string
	
	clear_screen_loop:
		inc dh
		call printline
		dec cx
	jnz clear_screen_loop
	
	pop esi
	pop edx
	pop ecx
	
	ret
	


; https://wiki.osdev.org/CPU_Registers_x86
; reference for mmx instruction sets https://docs.oracle.com/cd/E18752_01/html/817-5477/eojdc.html
enable_sse:
	; doesn't seem to work with the i386 emulation even in pentium 3 or 4 mode, must investigate further
	
	mov eax, cr0
	and al, ~0x04 	; clears bit 3, clear coprocessor emulation CR0.EM
	or al, 0x02		; set bit 2, set coprocessor monitoring  CR0.MP
	mov cr0, eax	; re-set the cr0 register
	
	mov eax, cr4
	or ax, 0x0600	; or with bits 9 and 10, set CR4.OSFXSR and CR4.OSXMMEXCPT at the same time
	mov cr4, eax
	
	ldmxcsr [mxcsr_reg_value] ; somehow this instruction doesn't explode, but the problem is that it also doesn't seem to work entirely.  
	
	; we're testing which instructions work here, this is not actually doing anything beyond figuring out which instructions generate #UD or not.
	; these instructions do work however, giving us about 8 additional 32 bit registers or 16 if we're creative.  
	movd mm0, eax
	; pinsrd xmm0, eax, 2, would be beautiful to have essentially unlimited scratch space...
	; this works but only if you use pinsrw and it will take the low word of eax and put it in position 2 from 0-7.  Why doesn't it take ax? who knows...
	mov eax, 173829
	pinsrw xmm3, eax, 2 ; this works, but we have to be careful because pinsrd doesn't, so sse2 is not enabled.  
	movaps xmm0, xmm1
	pextrw eax, xmm3, 2
		
	ret
	

move_cursor_to_position: 
	; https://wiki.osdev.org/Text_Mode_Cursor
	; put the cursor position in dx
	call calculate_position
	push edx
	push eax
	push ebx
	mov ebx, 0x0e0f
	
	mov edx, 0x03d4
	push eax
	mov al, bl
	out dx, al ; 0x03d4 : 0x0f
	pop eax

	inc dx
	out dx, al ; 0x03d5 : low word of position address

	dec dx
	mov al, bh
	out dx, al ; 0x03d4 : 0x0e

	inc dx
	shr ax, 8
	out dx, al ; 0x03d5 : high word of position address

	pop ebx
	pop eax
	pop edx
	ret


BACKSPACE equ 0x08

cgetline:
	push ebp
	mov ebp, esp
	push edi
	push edx

	mov edi, [ebp + 8]
	mov edx, [ebp + 12]
	call getline

	mov eax, edi
	
	pop edx
	pop edi

	leave
	ret
	
	
getline:
	; edi will have the pointer to the string
	; dx will have the position to move the cursor
	call move_cursor_to_position
	mov ecx, 1024 ; do not exceed the size of the string
	getline_loop:
		push ecx
		push edx
		call getchar_pressed
		cmp al, BACKSPACE
		je getline_backspace
		cmp al, 0x0a
		je getline_return
		stosb
		pop edx 
		push edx
		call printchar
		pop edx
		inc dl
		cmp dl, 80
		jb getline_no_linefeed
			mov dl, 0
			inc dh
		getline_no_linefeed:
		push edx
		getline_resume:
		call move_cursor_to_position
		pop edx
		pop ecx
		loop getline_loop
	
	getline_return:
		pop edx
		pop ecx
		mov byte [edi], 0x0
	ret

	getline_backspace:
		mov ax, 0x0f20
		pop edx
		test dl, dl
		jz getline_backspace_previous_line
		dec dl
		jmp getline_backspace_no_line_reset
		getline_backspace_previous_line:
		mov dl, 79
		dec dh
		getline_backspace_no_line_reset:
		push edx
		call printchar
		dec edi
		jmp getline_resume


cstrings_equal:
	push ebp
	mov ebp, esp
	push esi
	push edi
	push ebx

	mov esi, [ebp + 12]
	mov edi, [ebp + 8]

	jmp strings_equal_cstart
strings_equal:
	push ebp
	mov ebp, esp
	push esi
	push edi
	push ebx
	strings_equal_cstart:
	
	xor ecx, ecx
	
	strings_equal_compare_loop:
		lodsb
		mov bl, [edi]
		inc edi
		cmp al, bl
		jne strings_equal_failed
		test bl, bl
		jz strings_equal_end_compare
		test al, al
		jz strings_equal_end_compare
		inc ecx
	jmp strings_equal_compare_loop
	
	strings_equal_end_compare:
		cmp al, bl
		jne strings_equal_failed
		mov eax, 1
		jmp strings_equal_success
	strings_equal_failed:
		xor eax, eax
	strings_equal_success:
	pop ebx
	pop edi
	pop esi	
	leave
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; chex_to_number(stack1) -> eax				modifies(eax)										  ;;;; 	
;;;; 	hex string in the first stack argument														  ;;;; 	
;;;;	returns the value in eax									 								  ;;;; 	
;;;;		Sets the carry flag if there is an error				 								  ;;;; 	
;;;;		Maximum of 8 hex characters								 								  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
chex_to_number:
	push ebp
	mov ebp, esp

	push esi
	mov esi, [ebp + 12]
	
	mov dx, 0x0030
	call printstr
	
	call hex_string_to_number
	pop esi
	
	leave
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; hex_string_to_number(rsi) -> eax			modifies(eax)										  ;;;; 	
;;;; 	hex string in rsi																			  ;;;; 	
;;;;	returns the value in eax									 								  ;;;; 	
;;;;		Sets the carry flag if there is an error				 								  ;;;; 	
;;;;		Maximum of 8 hex characters								 								  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hex_string_to_number:
	push ecx
	push ebx							; use ebx as the temporary data storage
	push esi

	xor ebx, ebx
	mov ecx, 8
	hex_string_to_number_loop:
		lodsb							; loads a byte from rsi into al
		test al, al						; check for null termination
		jz hex_string_to_number_end		; end if found \0
		cmp al, '0'
		jb hex_string_to_number_error	
		sub al, '0'
		cmp al, 0x0a					; if it's below 0xa, then it's a number
		jb bypass_letter_checks
		cmp al, 0x16
		jbe hex_string_to_number_lower_case
		cmp al, 0x31
		jb hex_string_to_number_error
		cmp al, 0x36
		ja hex_string_to_number_error
		sub al, 0x20					; the difference is actually 0x27 but we'll subtract 7 in the next step
		hex_string_to_number_lower_case:
		sub al, 0x07					; the difference between 0x11 and 0x16 versus 0x0a to 0x0f is 7
		bypass_letter_checks:			; it was a number rather than a letter
		shr ebx, 4						; each hex digit is 4 bytes
		add bl, al
		dec ecx
		test ecx, ecx
	jnz hex_string_to_number_loop
	
	hex_string_to_number_error:
		stc

	hex_string_to_number_end:
		pop esi
		mov eax, ebx
		pop ebx
		pop ecx

	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; startswith(stack 1, stack 2) -> eax				1 if st1 starts with st2, 0 otherwise		  ;;;; 	
;;;; 	hex string in rsi																			  ;;;; 	
;;;;	returns the value in eax									 								  ;;;; 	
;;;;		Sets the carry flag if there is an error				 								  ;;;; 	
;;;;		Maximum of 8 hex characters								 								  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
startswith:
	push ebp 
	mov ebp, esp
	push esi
	push edi
	push ebx
	mov edi, [ebp + 12] ; 
	mov esi, [ebp + 8]  ; 
	
	startswith_loop:
		lodsb					; get the next character of the big string
		mov bl, [edi]			; get the substring character
		test bl, bl				; if it's null success
		jz startswith_success
		inc edi
		cmp al, bl				; 
		jne startswith_failure	; if the two strings differ in that character
		test al, al
	jnz startswith_loop
	
	startswith_failure:
		xor eax, eax
		jmp startswith_bypass_success
	startswith_success:	
		mov eax, 1
	startswith_bypass_success:
	pop ebx
	pop edi
	pop	esi
	leave
	ret


cprintline:
	push ebp
	mov ebp, esp
	
	mov esi, [ebp + 8]
	mov edx, [ebp + 12]
	
	call printline
	
	leave
	ret
	
print_string:
	push ebp
	mov ebp, esp
	
	mov esi, [ebp + 8]
	mov edx, [ebp + 12]
	
	call printstr
	
	leave
	ret

printline:
	push eax
	mov al, 0x0f
	call printlinef
	pop eax
	ret

printstr:
	push eax
	mov al, 0x0f
	call printstrf
	pop eax
	ret
	
printlinef:
	; al has the format
	push ebp
	mov ebp, esp
	mov byte [ebp - 2], al
	mov byte [ebp - 4], 1
	jmp printline_start

printstrf:
	; al has the format
	; esi is the string to be printed, null terminated
	; dx has the position
	push ebp
	mov ebp, esp
	mov byte [ebp - 2], al
	mov byte [ebp - 4], 0
	printline_start:
	sub esp, 4
	push ebx
	push edx
	call calculate_position
	shl eax, 1
	push edi
	push esi
	
	mov edi, 0xb8000	; graphics buffer
	add edi, eax		; the position should never exceed ax
	mov ah, [ebp - 2]	; format
	printstr_loop:
		lodsb
		stosw
		test al, al
		jnz printstr_loop
	
	push ecx
	mov bl, [ebp - 4]
	test bl, bl
	jz printstr_bypass
	mov eax, edi
	sub eax, 0xb8000
	mov bl, 80
	div bl
	movzx ax, ah
	mov cx, 80
	movzx ecx, cx
	sub cx, ax
	mov ax, 0x0f20 ; white formatted space
	printline_loop:
		stosw
	loop printline_loop	

	printstr_bypass:
	pop ecx
	pop esi
	pop edi
	pop edx
	pop ebx
	mov esp, ebp
	pop ebp
	ret

printchar:		; modifies ah, no return
	; dx has the position
	; al has the character
	mov ah, 0x0f
	push ebx
	push eax
	jmp print_char_no_format
printcharf:
	; ah has the format
	push ebx
	push eax
	print_char_no_format:
		call calculate_position
		shl eax, 1
		movzx ebx, ax
		pop eax
		mov [0xb8000 + ebx], ax
		pop ebx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; calculate_position(dx) -> eax			preserves(ebx, edx)							  			  ;;;; 
;;;; 	dh = row, dl = column																		  ;;;; 	
;;;;	returns the value in eax = 80 * dh + dl						 								  ;;;; 
;;;;	Used to calculate the memory offset for displaying text to the screen in the b8000 range	  ;;;; 	
;;;; 	does not apply the multiply shl 2 because some commands need it and others don't.  			  ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
calculate_position:
	xor eax, eax		
	push ebx
	movzx eax, dh
	mov bl, 80			; the number of columns per row
	mul bl				; multiply dh * col_per_row to get the offset
	movzx ebx, dl		; do this to preserve edx as is
	add eax, ebx		; dh * col_per_row + dl to get the total offset
	pop ebx				; preserve ebx
	ret


getchar_pressed:
	call getchar
	test ah, 0x01
	jz getchar_pressed	; if zero then the character is a release
	test ah, 0x02		; if non-zero then it is a special character, not an ascii symbol
	jnz getchar_pressed
	cmp al, 0x80		; probably should set the 0x02 flag in ah but we'll fix that later as usual
	jae getchar_pressed 	; this is an F1-F12 key, or some other key which is not translatable into ascii
	
	ret
	
getchar:
	xor eax, eax		; for the return of the ascii and extended codes [ah = codes][al = ascii or special code]
	xor ebx, ebx		; for the return of the 

	wait_for_char:	
		in al, 0x64
		test al, 1
		jz wait_for_char
	
	;; get a single code because most codes are singletons
	in al, 0x60
	;; test to see if the code is 0xE1 or 0xE0
	
	cmp al, 0xe0
	je getchar_extended_scancode
	cmp al, 0xe1
	je getchar_super_extended_scancode
	
	call check_control_keys 
	test ah, 2
	jnz getchar_exit
	
	;; if we get here, then it is a singleton code, not extended
	mov ebx, eax
	push ebx
	call set_pressed_or_released

	push edx
	mov edx, 0x1808
	call display_hex_byte
	pop edx

	movzx ebx, al 			; save the scancode in bl
	mov al, [single_scan_code_map + ebx]	; get the ascii code or special code
	call shift_translate					; tests for the shift code and does all shift translations.

	push edx
	mov edx, 0x1800
	call display_hex_byte
	pop edx
	
	pop ebx
	jmp getchar_exit						; and that's all she wrote
	
	getchar_extended_scancode:
		; take the next scancode in
		in al, 0x60
		
		;; check for the two weird ones, printscreen up and down will be either 0x2a or 0xb7 which don't match with any other scancodes...
		cmp al, 0x2a
		je check_printscreen_press
		cmp al, 0xb7
		je check_printscreen_release
		
		call set_pressed_or_released
		
		mov ebx, eax  ;; save the scancode for future use
		push esi
		mov esi, extended_keycodes
		push ecx
		single_extended_scancode_loop:
			lodsb			; load a scancode into al
			test al, al		; if it's null exit
			jz exit_scancode_single_extended
			push eax
			lodsd 			; loads the string into eax		
			mov edi, eax
			pop eax
			cmp al, bl		; compare it with the current scancode
			jne single_extended_scancode_loop

		or ah, 2
		call check_extended_control_keys
		pop ecx
		pop esi
		jmp getchar_exit
		
		exit_scancode_single_extended:
			; invalid code
			pop ecx
			pop esi
		exit_printscreen_check_failed:
			xor eax, eax
			not eax
			ret
			
		check_printscreen_press:
			; here we've scanned 0xe0 and then 0x2a
			;printscreen_down_keycode		db 0xE0, 0x2A, 0xE0, 0x37
			in al, 0x60
			cmp al, 0xe0
			jne exit_printscreen_check_failed
			in al, 0x60
			cmp al, 0x37
			jne exit_printscreen_check_failed
			or ah, 3	; pressed and special
			mov ebx, 'PRSC'
			ret
		check_printscreen_release:
			; here we've scanned 0xe0 and then 0xb7
			;printscreen_up_keycode			db 0xE0, 0xB7, 0xE0, 0xAA
			in al, 0x60
			cmp al, 0xe0
			jne exit_printscreen_check_failed
			in al, 0x60
			cmp al, 0xaa
			jne exit_printscreen_check_failed
			or ah, 2	; special
			mov ebx, 'PRSC'
			ret
	getchar_super_extended_scancode:
		;; remember that we've already scanned the 0xe1 so we need to check the rest.  
		;; pause_keycode					db 0xE1, 0x1D, 0x45, 0xE1, 0x9D, 0xC5
		push esi
		lea esi, [pause_keycode + 1]
		push ecx
		push ebx
		
		mov ecx, 5
		
		check_pause_loop:
			in al, 0x64
			test al, 1
			jz pause_check_failed
			lodsb
			mov bl, al
			in al, 0x60
			cmp al, bl
			jne pause_check_failed
			
		loop check_pause_loop
		
		mov ebx, 'PAUS'
		mov ax, 0x0380 ; special character pressed
		jmp pause_passed
		pause_check_failed:
			xor eax, eax
			not eax
		pause_passed:
			pop ebx
			pop ecx
			pop esi
			ret
		
	getchar_exit:
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


shift_translate:
	;	evaluates keyboard_flags for shift and then applies the proper transformation of ascii to the element in al. 
	; 	modifies eax
	push esi
	push ebx
	test word [keyboard_flags], 0x0003
	jz shift_translate_end

	cmp al, 'a'
	jb shift_translate_check_special
	cmp al, 'z'
	ja shift_translate_check_special
	sub al, 0x20
	jmp shift_translate_end
	
	shift_translate_check_special:
	mov ebx, eax
	mov esi, shift_symbol_translations
	
	shift_translate_loop:
		lodsw
		test ax, ax
		jz shift_translate_end
		cmp al, bl
		je shift_translate_found
	jmp shift_translate_loop
	
	shift_translate_found:
		mov bl, ah
		mov eax, ebx
	shift_translate_end:
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


display_ascii_characters:
	call clear_screen
	
	mov cx, 16
	
	mov al, 0
	mov dx, 0x0208
	ascii_row_legend_loop:
		call display_hex_byte
		inc al
		add dx, 4
		dec cx
	jnz ascii_row_legend_loop
	
	mov cx, 16
	mov al, 0
	mov dx, 0x0304
	ascii_col_legend_loop:
		call display_hex_byte
		add al, 0x10
		inc dh
		dec cx
	jnz ascii_col_legend_loop
	
	mov cx, 16
	mov dx, 0x0308
	ascii_outer_loop:
		push ecx
		push edx
		mov cx, 16
		ascii_inner_loop:
			mov ah, 0x0f
			call printcharf
			add dx, 4
			inc ax
			dec cx
		jnz ascii_inner_loop
		pop edx
		pop ecx
		add dh, 1
		dec cx
	jnz ascii_outer_loop
	
	ret


display_stack_values:
	push dword 0x0200
	push dword [esp + 4] ; actually 0
	call print_hex_dword
	add esp, 8
	
	push dword 0x0300
	push dword [esp + 8] ; actually 4
	call print_hex_dword
	add esp, 8

	push dword 0x0400
	push dword [esp + 12] ; actually 8
	call print_hex_dword
	add esp, 8

	push dword 0x0500
	push dword [esp + 16] ; actually 12
	call print_hex_dword
	add esp, 8
	
	ret

;void __fastcall print_hex_word(unsigned short word, unsigned int position)
print_hex_dword:
	push edx
	push ecx
	shr ecx, 16
	call print_hex_word
	pop ecx
	add edx, 4
	call print_hex_word
	pop edx
	ret	

;void __fastcall print_hex_dword(unsigned int dword, unsigned int position)
print_hex_word:
	push edx
	push ecx
	shr ecx, 8
	call print_hex_byte
	add edx, 2
	pop ecx
	call print_hex_byte
	pop edx	
	ret

;void __fastcall print_hex_byte(byte dword, dword position)
print_hex_byte:
	push eax
	movzx eax, cl
	call display_hex_byte
	pop eax
	ret


print_decimal:
	; ecx contains the data, dx contains the position, eax will contain the format in ah (should we just write this in C?) my brain is having trouble for no reason
	push ebp
	mov ebp, esp
	sub esp, 16
	pushad	; let's cheat a little and just push everything	

	mov ah, 0x0f			; for now... just for testing

	mov [ebp - 16], ah		; save the format
	mov [ebp - 14], dx		; save the position
	lea edi, [ebp - 12]
	
	xor ebx, ebx
	mov bl, 10				; set the divisor to 10, because it's decimal
	
	mov eax, ecx 			; move the number to eax
	xor ecx, ecx
	
	test eax, eax 
	jnz bypass_zero_value
	mov ah, [ebp - 16]		; restore the format
	mov dx, [ebp - 14]
	mov al, '0'				; ascii for zero to add the offset
	call printcharf
	
	jmp print_decimal_exit	; exit from the function, we have printed a zero.  
	
	bypass_zero_value:
	
	count_digits_loop:
		xor edx, edx	; zero out edx for the next division
		div ebx
		mov [edi], edx
		inc edi
		inc ecx
		test eax, eax
	jnz count_digits_loop

	dec edi		; move back by one
	mov dx, [ebp - 14]
	mov ah, [ebp - 16]	; restore the format
	
	print_dec_loop:
		mov al, [edi]
		add al, '0'		; ascii for zero to add the offset
		call printcharf
		dec edi
		inc dx
		dec cl
		test cl, cl
	jnz print_dec_loop
	
	print_decimal_exit:
	
	popad ; pop everything at the end
	add esp, 16
	leave
	ret


display_hex_byte:
	; al will have the byte
	; dx will have the position
	; convert higher nibble and display
	push edx
	push eax
	shr al, 4
	xor ah, ah				; lowercase hex
	call get_nibble_hex
	call printchar
	pop eax
	push eax
	xor ah, ah
	call get_nibble_hex
	inc edx
	call printchar
	pop eax
	pop edx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; nibble_to_hexchar(al, ah) -> al			modifies(al)		[c-call]						  ;;;; 	
;;;; 	converts a nibble in al to an ascii hex character											  ;;;; 	
;;;;	the second parameter put into ah determines the case of the hex if a letter					  ;;;; 	
;;;;		experiment to determine if using esp is possible										  ;;;; 	
;;;;  		it seems to be legal with the offset adjusted										  	  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
nibble_to_hexchar:
	mov ah, [esp + 8]
	mov al, [esp + 4]
	call get_nibble_hex
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; get_nibble_hex(al, ah) -> al			modifies(al)		[asm-call]							  ;;;; 	
;;;; 	converts a nibble in al to an ascii hex character											  ;;;; 	
;;;;	the second parameter put into ah determines the case of the hex if a letter					  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
get_nibble_hex:
	; al contains nibble
	; al will contain the hex code
	and al, 0x0f
	cmp al, 0x09
	ja nibble_add_letter_code_lower
	add al, '0'
	ret
	nibble_add_letter_code_lower:
	test ah, ah
	jnz nibble_add_letter_code_upper
	add al, 'a' - 10
	ret
	nibble_add_letter_code_upper:
	add al, 'A' - 10
	ret


hex_ascii_to_value:
	cmp al, ':'
	je hex_ascii_to_value_ignore_letter
	cmp al, '_'
	je hex_ascii_to_value_ignore_letter

	mov ah, 1	

	cmp al, '0'
	jb hex_ascii_to_value_error
	cmp al, '9'
	ja hex_ascii_to_value_check_letter
	sub al, '0'
	ret
	hex_ascii_to_value_check_letter:
	cmp al, 'A'
	jb hex_ascii_to_value_error
	cmp al, 'F'
	ja hex_ascii_to_value_check_lower_case
	sub al, 'A' - 10
	ret
	hex_ascii_to_value_check_lower_case:
	cmp al, 'a'
	jb hex_ascii_to_value_error
	cmp al, 'f'
	ja hex_ascii_to_value_error
	sub al, 'a' - 10
	ret
	
	hex_ascii_to_value_ignore_letter:
		inc cx
	hex_ascii_to_value_error:
		xor ah, ah
	ret

;__fastcall unsigned int hex_str_to_value(char * p_string);
hex_str_to_value:
	push esi
	push ecx
	push ebx
	xor ebx, ebx			; keep the result in ebx until the return
	mov esi, ecx
	mov cx, 8				; 8 is the max size because after that there shouldn't be any more hex letters
	mov ah, 1
	hex_str_to_value_loop:
		lodsb
		test al, al
		jz hex_str_to_value_exit

		test ah, ah
		jz hstv_bypass_increment
			shl ebx, 4
		hstv_bypass_increment:
		call hex_ascii_to_value
		add bl, al
		dec cx
	jnz hex_str_to_value_loop
	
	hex_str_to_value_exit:
	mov eax, ebx
	pop ebx
	pop ecx
	pop esi
	ret


;void __fastcall hex_dump(unsigned char * starting_address)
hex_dump:
	push edx
	push ecx
	push ebx
	
	mov ebx, ecx
	
	mov dx, 0x0100
	mov esi, hexdump_str
	call printline
	
	mov dx, 0x010a
	call print_hex_dword
	
	mov cx, 21
	mov dx, 0x0200
	
	hex_dump_outer_loop:
		push ecx
		
		mov esi, empty_string
		call printline

		mov cx, 25
		hex_dump_inner_loop:
			mov al, [ebx]
			call display_hex_byte
			inc ebx
			add edx, 3
			dec cx
		jnz hex_dump_inner_loop
		
		inc dh
		xor dl, dl
		
		pop ecx
		dec cx
	jnz hex_dump_outer_loop	
	
	pop ebx	
	pop ecx
	pop edx
	ret


pit_wait:
	; ecx contains the wait count
	push eax
	mov eax, ecx
	add eax, [current_tick]
	
	pit_wait_loop:
		cmp [current_tick], eax
	jb pit_wait_loop
	pop eax
	ret
	

keyboard_irq1:
	push eax
	push edx
	push esi

	; end of interrupt
	mov al, 0x20
	out 0x20, al

	pop esi
	pop edx	
	pop eax
	
	iretd


mouse_interrupt_irq12:
	push eax
	push edx
	push esi
	
	mov dx, 0x0500
	mov esi, irq12_recieved_str
	call printline

	; end of interrupt
	mov al, 0x20
	out 0xa0, al
	out 0x20, al

	pop esi
	pop edx	
	pop eax
	
	iretd
	

general_fault_handler:
	add esp, 4
	iret


section .data
	%include "ps2map.asm"
	empty_string 			db 0
	hexdump_str			    db  "Hexdump: ", 0
	protected_mode_string 	db 	"We have entered protected mode.", 0
	extended_code_str		db 	"We have just received an extended code", 0
	irq12_recieved_str		db	"IRQ12 Received.", 0
	shift_down_string		db  "SHIFT", 0
	ctrl_down_string		db  "CTRL ", 0
	alt_down_string			db  " ALT ", 0
	up_string				db 	"-----", 0
	; keyboard flags
	keyboard_flags 			dw 0x0000 ; [ - - - - - CAPL SCRL ] [-, -, RALT, LALT, RCTRL, LCTRL, RSHIFT, LSHIFT] ; where to put insert?
	cursor_position			dw 0x0100
	scancode_queue 			dw 0
	mxcsr_reg_value			dd 0x0000_1F80
	current_tick 			dw 0x0



section .bss
	instring 		resb 1024
	; memory_block	resd 8192