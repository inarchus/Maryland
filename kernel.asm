; still to do with keyboard driver: fix the function keys, scroll lock, pause, caps lock probably too
; shift + space doesn't seem to work, keypad enter isn't working perfectly either.  F[i] keys not implemented
; get gdb + qemu working for faster debugging
; figure out how to control where on the floppy everything goes.  
;	perhaps write a driver using the control registers
;	then another using dma ...
; see if it's possible to display an up-timer / time of day

[bits 32]

extern kernel_loader_entry
extern cgetline
extern cprintline

extern single_scan_code_map
extern getchar_pressed
extern string_length
extern main_shell
extern printstr
extern strings_equal

section .text
kernel_loader_entry:
	mov edi, 0xb8000
	mov esi, protected_mode_string
	mov ah, 0x0f
	kernel_print_loop:
		lodsb
		stosw
		test al, al
		jnz kernel_print_loop
	
	push instring
	call main_shell
	
;	mov dx, word 0x0100
;	continue_getlining:
;		mov edi, instring
;		push edx
;		inc dh
;		push edx
;		mov esi, empty_string
;		call printline
;		pop edx
;		call getline
;		mov dx, 0x0000
;		mov esi, instring
;		call printline
;		pop edx
;		inc dh
;		cmp dh, 0x17
;		jb skip_reset
;			xor dh, dh
;		skip_reset:
;	jmp continue_getlining
	

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


strings_equal:
	
	
	ret

cprintline:
	push ebp
	mov ebp, esp
	
	mov esi, [ebp + 8]
	mov edx, [ebp + 12]
	
	call printline
	
	leave
	ret

printline:
	push ebp
	mov ebp, esp
	mov byte [ebp - 4], 1
	jmp printline_start
printstr:
	; esi is the string to be printed, null terminated
	; dx has the position
	push ebp
	mov ebp, esp
	mov byte [ebp - 4], 0
	printline_start:
	sub esp, 4
	push edx
	call calculate_position
	shl eax, 1
	push edi
	push esi
	
	mov edi, 0xb8000	; graphics buffer
	add di, ax			; the position should never exceed ax
	mov ah, 0x0f		; format
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

	mov esp, ebp
	pop ebp
	ret

printchar:
	; dx has the position
	; al has the character
	mov ah, 0x0f
printcharf:
	; ah has the format
	push ebx
	push eax
	call calculate_position
	shl eax, 1
	movzx ebx, ax
	pop eax
	mov [0xb8000 + ebx], ax
	pop ebx
	ret

; calculate_position_with_shift:
	
calculate_position:
	; does not apply the multiply shl 2 because some commands need it and others don't.  
	;	Moving the cursor requires it to be the actual offset, displaying characters requires shl pos, 1
	; dx has the position (dh = row, dl = col)
	; returns in [e]ax
	xor eax, eax
	push ebx
	movzx eax, dh
	mov bl, 80
	mul bl
	movzx ebx, dl
	add eax, ebx
	pop ebx
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
	

display_hex_byte:
	; dx will have the position
	; al will have the byte
	; convert higher nibble and display
	push eax
	shr al, 4
	call get_nibble_hex
	call printchar

	pop eax
	push eax

	call get_nibble_hex
	inc edx
	call printchar
	pop eax
	ret
	
get_nibble_hex:
	; al contains nibble
	; al will contain the hex code
	and al, 0x0f
	cmp al, 0x09
	ja nibble_add_letter_code
	add al, '0'
	ret
	nibble_add_letter_code:
	add al, 'a' - 10
	ret
	
section .data
	%include "ps2map.asm"
	empty_string db 0
	protected_mode_string 	db 	"We have entered protected mode.", 0
	extended_code_str		db 	"We have just received an extended code", 0
	shift_down_string		db  "SHIFT", 0
	ctrl_down_string		db  "CTRL ", 0
	alt_down_string			db  " ALT ", 0
	up_string				db 	"-----", 0
	; keyboard flags
	keyboard_flags 		dw 0x0000 ; [ - - - - - CAPL SCRL ] [-, -, RALT, LALT, RCTRL, LCTRL, RSHIFT, LSHIFT] ; where to put insert?
	cursor_position		dw 0x0100
	scancode_queue 	dw 0
section .bss
	instring 		resb 1024
