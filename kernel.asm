[bits 32]

extern kernel_loader_entry
extern single_scan_code_map
extern getchar_pressed
extern translate_scancode
;extern calculate_position
	; position desired in dx, returned in ax as offset
;extern move_cursor_to_position
	; cursor position in dx

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


	kernel_print_preloop:
	
	call getchar
	mov dx, 0x0040
	test ah, 1
	jz skip_print
	test al, al
	jz skip_print
	cmp al, 0x1b
	je exit_loop
	call printchar
	skip_print:
	
	jmp kernel_print_preloop
	exit_loop:
	
	mov dx, word 0x0100
	continue_getlining:
	
	mov edi, instring
	
	push edx
	call getline
	mov edx, [esp]
	add dh, 1
	mov esi, instring
	call printstr
	pop edx
	jmp continue_getlining
	

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


getchar_pressed:
	call getchar
	cmp al, 0x58
	ja getchar_pressed
	and al, 0x7f
	test al, al
	jz getchar_pressed
	ret
	
getchar:
	wait_for_char:
		in al, 0x64
		test al, 1
		jz wait_for_char
	in al, 0x60
	call translate_scancode
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
		stosb
		cmp byte [edi - 1], 0x0a
		je getline_return
		mov edx, [esp]
		call printchar
		pop edx		
		inc dl
		cmp dl, 80
		jb getline_no_linefeed
			mov dl, 0
			inc dh
		getline_no_linefeed:
		push edx
		call move_cursor_to_position
		pop edx
		pop ecx
		loop getline_loop
		
	getline_return:
		pop edx
		pop ecx
		mov byte [edi - 1], 0x0

	ret

printline:
	ret
printstr:
	; esi is the string to be printed, null terminated
	; dx has the position
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
	
	pop esi
	pop edi
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


calculate_position:
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


translate_scancode:
	; send the scancode in al (for now just single bytes)
	; eax = [- - - - - - - -] [- - - - - - - -] [- - - - - - - PR] [al ascii]
	; PR = Press (1) or Release (0)
	xor ah, ah
	cmp al, 0x59 ; top press scancode is 0x58
	jl translate_scancode_press
		sub al, 0x80 	; release codes differ by 0x80 from press codes
		jmp translate_scancode_cont
	translate_scancode_press:
		or ah, 1
	; check if it's bigger than 0x58 and return error code.  
	translate_scancode_cont:
	cmp al, 0x58
	ja translate_scancode_error
	push ebx
	movzx ebx, al
	mov al, [single_scan_code_map + ebx]
	pop ebx
	ret

	translate_scancode_error:
		; set error code before return maybe...
		mov al, 0x00
		ret


section .data
	protected_mode_string db "We have entered protected mode.", 0
						 ; null   esc     1     2
	; current bugs: ` (tick) the Y key and the \ key don't work.  
	single_scan_code_map db 0x00, 0x1b,	0x31, 0x32,		; 0x00 - 0x03
						; 3 	4	 5	   6
						db 0x33, 0x34, 0x35, 0x36,		; 0x04 - 0x07
						; 7		8	 9	   0
						db 0x37, 0x38, 0x39, 0x30,		; 0x08 - 0x0b
						; -	 	=	back   tab
						db 0x2d, 0x3d, 0x08, 0x09,		; 0x0c - 0x0f
						; Q		W 	E		R		[returns capitals]
						db 0x51, 0x57, 0x45, 0x52, 		; 0x10 - 0x13
						; T 	Y	U		I
						db 0x54, 0x59, 0x55, 0x49, 		; 0x14 - 0x17
						; O 	P   [		]
						db 0x4f, 0x50, 0x5b, 0x5d,		; 0x18 - 0x1b
						; ent, LCTRL, A, S 
						db 0x10, 0x80, 0x41, 0x53,		; 0x1c - 0x1f -- 0x80 is a flipped top bit, meaning that we have some extended code
						; D, F, G, H
						db 0x44, 0x46, 0x47, 0x48,		; 0x20
						; J K L (actual semicolon ;)
						db 0x4a, 0x4b, 0x4c, 0x3b,		; 0x24
						; 'quot	` (tick) left-shift	 \
						db 0x27, 0x60, 0x80, 0x5c,		; 0x28 not sure why this needs to be duplicated, i think this one can be zero.  
						db 0x27, 0x60, 0x80, 0x5c,		; 0x2c
						; Z		X	C	V
						db 0x5a, 0x58, 0x43, 0x56,
						; B N M ,
						db 0x42, 0x4e, 0x4d, 0x2c,
						; . / [R shift] [keypad]*
						db 0x2e, 0x2f, 0x80, 0x2a,
						; left-alt space capslock f1
						db 0x80, 0x20, 0x80, 0x80,
						; f2, f3, f4, f5
						db 0x80, 0x80, 0x80, 0x80, 
						; f6, f7, f8, f9
						db 0x80, 0x80, 0x80, 0x80, 
						; f10, numlock, scroll-lock, keypad 7
						db 0x80, 0x80, 0x80, 0x37, 
						; keypad-8, keypad-9, keypad-minus, keypad-4
						db 0x38, 0x39, 0x2d, 0x34,
						; keypad 5, keypad 6, keypad +, keypad 1
						db 0x35, 0x36, 0x2b, 0x31,
						; keypad 2, keypad 3, keypad 0, keypad .
						db 0x32, 0x33, 0x30, 0x2e,
						; null, null, null, F11
						db 0x00, 0x00, 0x00, 0x80,
						; F12, null, null, null
						db 0x80, 0x00, 0x00, 0x00, 
	cursor_position		dw 0x0100
section .bss
	instring resb 1024