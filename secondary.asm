;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			secondary.asm																					    ;;;;
;;;;																																								;;;;
;;;;		This code is the secondary stage 16-bit bootloader which allows hexdumps, floppy reads, etc																;;;;
;;;;																																			Eric Hamilton		;;;;
;;;;																																						  		;;;;
;;;;																																						  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	

[bits 16]
[segment 0x8000]

extern kernel_entry
extern kernel_loader_entry
extern single_scan_code_map
extern translate_scancode
extern string_length
extern pit_interrupt_irq0

section .text

init:
	xor ax, ax
	mov es, ax
	mov ds, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov sp, 0x6fff ; set up the stack so that it can descend.  
	
	mov di, new_string
	xor dx, dx
	call writeline_to_screen

	; enable ps/2 port?
	mov al, 0xAE
	out 0x64, al
	
	main_loop:
		mov dx, 0x1700 ; mov dh, 23 ; mov dl, 0
		call move_cursor_to_position 		; mov ah, 0x02 		; int 0x10 ; move the cursor to the position
		
		mov di, input_line
		call getline
		
		; clear the input line
		mov dx, 0x1700
		mov di, empty_string
		call writeline_to_screen

		; write the line to the zero line to note the previous command
		mov di, input_line
		xor dx, dx
		call writeline_to_screen
	
		mov di, input_line
		mov si, halt_string
		call startswith
		test ax, ax
		jnz end_program
	
		call menu_options
	
		jmp main_loop

	end_program:
		hlt
		jmp init



menu_options:
	test_set_location: ; not currently used but we'll do it for symmetry
		mov di, input_line
		mov si, write_string
		call startswith
		test ax, ax
		jz test_get_location
		call set_location
	test_get_location:
		mov di, input_line
		mov si, read_string
		call startswith
		test ax, ax
		jz test_loadf
		call get_location
	test_loadf:
		mov di, input_line
		mov si, loadf_string
		call startswith
		test ax, ax
		jz test_writef
		call load_from_floppy
	test_writef:
		mov di, input_line
		mov si, writef_string
		call startswith
		test ax, ax
		jz test_hex
		call write_floppy
	test_hex:
		mov di, input_line
		mov si, hex_dump_str
		call startswith
		test ax, ax
		jz test_exec
		call display_hexdump
	test_exec:
		mov di, input_line
		mov si, exec_string
		call startswith
		test ax, ax
		jz test_regdump
		call execute_from_location
	test_regdump:
		mov di, input_line
		mov si, reg_dump_string
		call startswith
		test ax, ax
		jz test_enable_a20
		call display_regdump
	test_enable_a20:
		mov di, input_line
		mov si, enable_a20_cmd
		call startswith
		test ax, ax
		jz test_disable_a20
		call a20_enable
		call a20_verify
	test_disable_a20:
		mov di, input_line
		mov si, disable_a20_cmd
		call startswith
		test ax, ax
		jz test_check_a20
		call a20_disable
		call a20_verify
	test_check_a20:
		mov di, input_line
		mov si, verify_a20_cmd
		call startswith
		test ax, ax
		jz test_enter_protected
		call a20_verify
	test_enter_protected:
		mov di, input_line
		mov si, enter_protected_mode_str
		call startswith
		test ax, ax
		jz test_measure_low_ram
		call enter_protected_mode
	test_measure_low_ram:
		mov di, input_line
		mov si, measure_low_ram_string
		call startswith
		test ax, ax
		jz test_measure_high_memory
		call measure_low_memory		
	test_measure_high_memory:
		mov di, input_line
		mov si, measure_high_ram_string
		call startswith
		test ax, ax
		jz test_get_cpuid
		call measure_high_memory
	test_get_cpuid:
		mov di, input_line
		mov si, cpuid_string
		call startswith
		test ax, ax
		jz menu_options_ret
		call get_cpu_info		
	menu_options_ret:
		ret


get_cpu_info:
	push bp
	mov bp, sp
	
	sub sp, 16
	
	xor eax, eax
	cpuid
	
	mov [bp - 16], ebx
	mov [bp - 12], edx
	mov [bp - 8], ecx
	mov [bp - 4], dword 0x0
	

	mov dx, 0x0200
	lea di, [bp - 16]
	call writeline_to_screen
	
	add sp, 16
	leave
	ret

measure_high_memory:
	xor cx, cx
	xor dx, dx
	mov ax, 0xe801 		; memory detection
	int 0x15
	push dx
	mov ax, cx
	mov di, hex_out_str
	call word_to_hexstr
	mov dx, 0x0100 
	mov di, hex_out_str
	call writeline_to_screen
	pop dx
	mov ax, dx
	mov di, hex_out_str
	call word_to_hexstr
	mov dx, 0x0200 
	mov di, hex_out_str
	call writeline_to_screen
	
	ret


measure_low_memory:
	clc
	int 0x12
	mov di, hex_out_str
	call word_to_hexstr
	
	mov dx, 0x0100 
	mov di, hex_out_str
	call writeline_to_screen
		
	ret


enter_protected_mode:
	call a20_verify
	test ax, ax
	jnz epm_pass_a20_enable
	call a20_enable
	epm_pass_a20_enable:
	
	cli ; disable interrupts
	
	; call get_char	
	;mov eax, gdt_end
	xor ax, ax
	mov ds, ax
	lgdt [gdt_end]
	
	; call get_char
	mov eax, cr0
	or al, 1
	mov cr0, eax
	
	; call get_char
	jmp 0x8:kernel_entry
	
	enter_protected_mode_return:
	ret

get_char:
	wait_for_a1:		; waiting for the a character (probably could make it the same position since it is)
	wait_for_char:		; waiting for the status register's first bit to be 1
	in al, 0x64			; get the status register from the ps2 keyboard
	and al, 1			; test for the first bit to be 1
	jz wait_for_char	; jump back if not
	in al, 0x60			; get the scan code
	cmp al, 0x1e		; test the scan code (A pressed)
	jne wait_for_a1		; jump if not.  
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

a20_verify:
	; returns the status in ax 0 = disabled, 1 = enabled
	push dx
	
	in al, 0x92
	test al, 2
	jnz a20_verify_enabled

	xor dx, dx
	mov di, a20disstr
	call writeline_to_screen
	xor ax, ax
	jmp a20_verify_exit
	a20_verify_enabled:

	xor dx, dx
	mov di, a20enstr
	call writeline_to_screen
	inc ax
	a20_verify_exit:
	pop dx
	ret

a20_enable:							;https://wiki.osdev.org/A20_Line
	push ax
	in al, 0x92						; special a20 enable port
	test al, 2						; bit 1 must be set to true
	jnz a20_enable_already_enabled
	or al, 2
	and al, 0xFE
	out 0x92, al
	a20_enable_already_enabled:
	pop ax
	ret
	
a20_disable:
	push ax
	in al, 0x92
	test al, 2
	jz a20_disable_already_disabled
	and al, 0xfc ; 0b1111_1100
	out 0x92, al
	a20_disable_already_disabled:
	pop ax
	ret


display_regdump:
	; save the stack pointer first since that's going to change a lot during the output process
	mov [register_values + 8], sp
	
	; save the flags next
	push ax 							; save ax
	pushf 								;
	pop ax								;
	mov [register_values + 28], ax		;
	pop ax								;
	
	push bp
	push bx
	mov bp, sp
	mov bx, [bp]
	mov [register_values + 30], bx ; currently contains the return address
	pop bx
	pop bp
	
	; ax, bx, cx, dx
	mov [register_values], ax
	mov [register_values + 2], bx
	mov [register_values + 4], cx
	mov [register_values + 6], dx

	; sp, bp, si, di
	mov [register_values + 10], bp
	mov [register_values + 12], si
	mov [register_values + 14], di
	
	; ss, cs, ds, es, fs, gs
	mov [register_values + 16], ss
	mov [register_values + 18], cs
	mov [register_values + 20], ds
	mov [register_values + 22], es
	mov [register_values + 24], fs
	mov [register_values + 26], gs

	push cx
	push dx

	mov cx, 22
	clear_rows_loop:
		mov di, empty_string
		mov dh, 22
		sub dh, cl
		inc dh
		xor dl, dl
		call writeline_to_screen
		loop clear_rows_loop

	mov cx, 16

	push bx
	push ax
	push si

	mov si, reg_names
	mov bx, register_values
	regdump_display_loop:
		push cx
		mov ax, [bx]
		add bx, 2
		
		mov di, si
		mov dh, 16
		sub dh, cl
		inc dh
		xor dl, dl
		call write_string_to_screen
		
		mov di, hex_out_str
		call word_to_hexstr
		
		push dx
		mov dh, 16
		sub dh, cl
		inc dh
		mov dl, 4
		call writeline_to_screen
		pop dx
		
		add si, 3
		pop cx
	loop regdump_display_loop
	pop si
	pop ax
	pop bx
	pop dx
	pop cx
	ret

word_to_hexstr_no_prefix:
	push ax
	push bx
	push cx
	push di
	sub di, 2
	jmp word_to_hex_bypass_prefix
word_to_hexstr:
	; put the value in the ax register
	; put a string of appropriate length in di, i guess technically it only needs 7 max with the null terminator too.  
	push ax
	push bx
	push cx
	push di

	mov word [di], '0x'
	
	word_to_hex_bypass_prefix:
	mov byte [di + 6], 0  			; set the null terminator 
	add di, 5
	mov cx, 4
	word_to_hexstr_loop:
		mov bx, ax
		and bx, 0xF 			; get the lowest current nibble
		add bl, '0'
		cmp bl, '0' + 10
		jb word_to_hexstr_bypass
		add bl, 'a' - 10 - '0'
		word_to_hexstr_bypass:
		mov [di], bl
		shr ax, 4
		dec di
	loop word_to_hexstr_loop
	pop di	
	pop cx
	pop bx
	pop ax
	ret


display_hexdump:
	; di is already inputline
	push di
	push ax
	push bx
	mov ax, hex_dump_str_len
	call hexchar_address_to_value
	mov di, ax
	call hex_dump
	pop bx
	pop ax
	pop di
	ret


execute_from_location:
	mov ax, 4						; 'exec ' should start at index 4 for searching for the address
	call hexchar_address_to_value	;
	add sp, 4 ; 'unwind' the call stack manually
	test bx, 0x000f					; if there is no segment
	jnz exec_loc_bypass				; do a near call
	push bx							; else do a far call with segment
	push ax
	retf
	exec_loc_bypass:
	push ax
	ret


load_from_floppy:
	;  	     	       disk  drive  track sector  n_sectors	dest_seg	location
	; format: fdload 	DD    VV      TT     SS	  NN		   			SEG:ADDR
	; set the disk and drive by default to start, allow Track:Sector Num_Sectors SEG:ADDR
	push bp
	push es
	mov bp, sp
	
	mov ax, 7
	call hexchar_address_to_value
	mov ah, bl
	push ax
	
	mov ax, cx
	call hexchar_address_to_value
	mov es, bx
	mov bx, ax
	mov ah, 0x02			; read from floppy ah = 2 - two sectors al = 1
	mov al, 0x01
	xor dx, dx				; dx high word is the head (side of the disk, 1 indexed, lies, 0 indexed), low word is the drive  (0 indexed = fda, 1 = fdb)

	pop cx					; cx high word is the track, low word is the sector
	
	int 0x13	 				; read from floppy disk drive
	
	; call read_floppy
	pop es
	pop bp
	ret
	
read_floppy:
	; input al as the number of sectors to read
	; di is the destination index
	; si is the TT:SS of track and sector in high and low word

	xor ah, ah				
	mov ah, 0x02
	mov dx, 0x0000 			; dx high word is the head (side of the disk, 1 indexed, lies, 0 indexed), low word is the drive  (0 indexed = fda, 1 = fdb)
	mov cx, si 				; cx high word is the track, low word is the sector
	xor bx, bx				; clear the segment for the initial assembly reads
read_floppy_exec:
	mov es, bx
	mov bx, di 				; bx contains the location to write in the segment es:bx
	int 0x13	 				; read from floppy disk drive
	ret
	
	
write_floppy:
	mov dx, 0x28
	mov di, writef_string
	call string_length
	mov cx, ax
	mov bp, di
	mov bx, 0x010f 
	mov ax, 0x1300
	int 0x10
	ret

get_location:
	; di has the input string
	; read has an offset of 4 or so.  
	push bp
	mov bp, sp
	; create some local variable space (10 bytes)
	push ax
	push di
	
	mov ax, 4						; starting offset to bypass 'read '
	call hexchar_address_to_value
	push ax
	mov ax, bx
	lea di, hex_out_str
	call word_to_hexstr_no_prefix
	
	mov dx, 0x0200
	lea di, hex_out_str
	call writeline_to_screen
	pop ax
	push bx
	push ax
	push es
	and bl, 0x0f
	jnz get_location_bypass_segment
		mov es, bx
	get_location_bypass_segment:
	mov bx, ax
	mov ax, [es:bx]
	lea di, hex_out_str
	call word_to_hexstr_no_prefix
	pop es

	mov dx, 0x0100
	mov di, read_location_str
	call writeline_to_screen

	mov dx, 0x011a
	lea di, hex_out_str
	call write_string_to_screen

	pop ax
	; ax should contain the value to convert back to hex for no reason...
	lea di, hex_out_str
	call word_to_hexstr_no_prefix
	
	mov dx, 0x0112
	lea di, hex_out_str
	call write_string_to_screen

	pop bx
	push bx
	and bl, 0x0f
	jz hatf_skip_es
		mov bx, es
	hatf_skip_es:
	
	pop bx
	mov ax, bx
	cmp bl, 0x0f
	jne get_loc_use_segment
	mov ax, es
	get_loc_use_segment:
		
	lea di, hex_out_str
	call word_to_hexstr_no_prefix
	
	mov dx, 0x010d
	lea di, hex_out_str
	call write_string_to_screen
	
	pop di
	pop ax
	pop bp
	ret

set_location:
	; di has the input string
	; write has an offset of 5 or so.  
	mov ax, 5						; starting offset to bypass 'write '
	call hexchar_address_to_value
	; bx will have the segment or 0x000f, ax will have the location
	; then we need to use cx which hopefully works to get the next value
	push dx

	push ax
	push bx

	mov ax, cx
	call hexchar_address_to_value
	mov dx, ax
	pop bx
	pop ax

	push es
	push es
	pop fs
	test bx, 0x000f
	jnz set_location_skip_segment
	mov fs, bx
	set_location_skip_segment:
	mov bx, ax
	mov word [fs:bx], dx
	pop fs

	pop dx
	ret
	

string_compare:
	; compare si vs di
	ret

startswith:
	; di starts with si, return in ax 1 if true, 0 if false
	call string_length
	mov bx, ax		; ax has the result move it to bx
	push si			; push si to exchange the strings
	mov si, di			; exchange
	push bx			; ensure it doesn't get overwritten
	call string_length	;
	pop bx			; get the length back into bx if it's been modified
	pop si			; 
	
	cmp ax, bx		; ax has the length of the "longer string"
	jge startswith_begin_loop
	xor ax, ax		; if not then return 0
	ret
	
	startswith_begin_loop:
	
	; the string length is in bx load it into cx and loop
	
	push di
	push si
	
	mov cx, bx
	startswith_loop:	
		mov al, byte [di]
		mov bl, byte [si]
		cmp al, bl
		je startswith_inc_and_loop
			xor ax, ax
			jmp startswith_end
		startswith_inc_and_loop:
			inc di
			inc si
	loop startswith_loop
		mov ax, 1
	startswith_end:
		pop si
		pop di
		ret

hexchar_address_to_value:
	; di will have the location of the string
	; ax will have a returned value
	; bx will have the segment 
	; cx will have the last index 
	push si
	push di
	mov si, di
	mov bx, 0x000f	; if this is returned then the segment is not set
	push bx
	
	add si, ax
	
	next_non_hex:
		mov al, byte [si] 				; scan through non hex 
		call hexchar_to_int
		inc si
		test ah, ah
	jnz next_non_hex

	dec si ; go back one because it's a hex character
	xor bx, bx
	mov cx, 4
	next_hex:
		push cx
		mov al, byte [si] 		; scan through hex 
		cmp al, ':'				; if we find a colon, count that as the segment
		je hatv_found_colon
		call hexchar_to_int
		test ah, ah
		jnz exit_hexchar_addr_to_val_fail
		shl bx, 4				; the first shift left will multiply zero by 16
		add bx, ax				; add the value into bx
		inc si
		pop cx
		loop next_hex
		
	mov al, byte [si] 		; scan through hex 
	cmp al, ':'
	je hatv_found_colon_bypass_pop
	jmp bypass_hatvf

	hatv_found_colon:
		
		; mov di, found_colon_string
		; mov dx, 0x0400
		; call writeline_to_screen
		
		pop cx			; finish the loop by popping cx
	hatv_found_colon_bypass_pop:
		inc si			; go past the colon and start with the next hex
		add sp, 2		; pop the old value for bx, but don't overwrite bx
		push bx			; push the segment address
		xor bx, bx		; start over again with the calculation
		mov cx, 4		; restart the loop looking for 4 hexits
		jmp next_hex

	exit_hexchar_addr_to_val_fail:
		pop cx			; restore cx, jumping out of the loop so won't pop cx
	bypass_hatvf:
		mov ax, bx		; mov the result from bx into ax
		pop bx			; popping bx restores the segment or 0x000f
		pop di			; restore di if it's been modified
		mov cx, si		; calculate the index of the last address we've reached
		sub cx, di		; subtract the initial index of the string
		pop si
	ret

hexchar_to_int:
	; si should be the location of the character
	; ax will have the value upon return or 0xffff for error
	xor ax, ax
	push bx
	xor bh, bh 
	mov bl, [si]
		; check for ascii numbers
		cmp bl, '0'
		jl check_letter
		cmp bl, '9'
		jg check_letter
		sub bl, '0'
		mov ax, bx
		pop bx
		ret
	check_letter:
		cmp bl, 'A'
		jl hexchar_to_int_return_error
		cmp bl, 'f'
		jg hexchar_to_int_return_error
		cmp bl, 'F'
		jle check_uppercase
		cmp bl, 'a'
		jge check_lowercase
		jmp hexchar_to_int_return_error
	check_lowercase:
		sub bl, 0x20 ; part of the other subtraction to convert to upper case
	check_uppercase:
		sub bl, 0x37 ; subtract 0x41 - 0x0a because it starts at 10 upto f
		mov ax, bx
		pop bx
		ret
	hexchar_to_int_return_error:
		mov ax, 0xffff
		pop bx
		ret

string_length:
	; si should be the string to count
	; length of string returned in ax (without the null terminator)
	push di
	push cx
	mov di, si
	xor eax, eax 	; ensure that al is set to zero
	mov cx, 0xffff	; limit of 65535 length
	repnz scasb
	not cx
	dec cx
	mov ax, cx
	pop cx
	pop di
	ret


hex_dump:
	; di should contain the address of the 512 block to read.
	mov cx, 512
	mov dx, 0x0100
	sub dx, 3
	
	push fs
	push si
	
	test bx, 0x000f
	jnz hexdump_bypass_segment
	mov fs, bx
	hexdump_bypass_segment:
	
	hex_dump_loop:
		push cx
		push di
		push dx
		
		mov dl, [fs:di]
		lea si, [out_num + 1]
		call convert_nibble_to_ascii
		
		mov dl, [fs:di]
		shr dl, 4
		lea si, [out_num]
		call convert_nibble_to_ascii
		
		pop dx
		add dx, 3
		cmp dl, 72
		jne hexdump_no_line_reset
			inc dh
			xor dl, dl
		hexdump_no_line_reset:
		
		mov di, out_num
		call write_string_to_screen

		pop di
		pop cx
		inc di
		loop hex_dump_loop
	
	pop si
	pop fs
	
	ret

convert_nibble_to_ascii:
	and dl, 0x0F
	cmp dl, 10
	jl skip_add_letter
		add dl, 0x27 ; = 0x31 - 0xa (already has 10 in it)
	skip_add_letter:
	add dl, 0x30
	mov [si], dl
	ret

getchar_pressed:
	ret

getline:
	push cx
	push bx
	push ax
	mov cx, 78 ; maximum number of characters in a line

	xor bx, bx ; use bx as the counter on that line

	getline_loop:
		push cx
		push di
		push bx
		
		mov dh, 23
		mov dl, bl
		call move_cursor_to_position ;		mov ah, 0x02		int 0x10 ; move the cursor to the position				
		
		; call getchar_pressed
		
		xor ah, ah
		int 0x16 ; get a character (wait for input, result goes into al I think?)
		
		cmp al, 0xd ; compare for a carriage return
		je leave_getline
		cmp al, 0xa ; compare for a line return as well
		je leave_getline
		cmp al, 0x08 ; backspace
		je getline_backspace

		pop bx
		pop di
		mov byte [di + bx], al
		push di
		push bx
		push ax
		
		call writechar
		
		pop ax

		skip_out:
		
		push ax
		mov dl, al
		lea si, [out_num + 1]
		call convert_nibble_to_ascii
		
		mov dl, al
		shr dl, 4
		lea si, [out_num]
		call convert_nibble_to_ascii

		mov di, out_num
		mov dx, 0x1800
		call write_string_to_screen
		
		pop ax
		mov dl, ah
		lea si, [out_num + 1]
		call convert_nibble_to_ascii
		
		mov dl, ah
		shr dl, 4
		lea si, [out_num]
		call convert_nibble_to_ascii

		mov di, out_num
		mov dx, 0x1808
		call write_string_to_screen
		
		pop bx
		pop di
		pop cx
		inc bx
	loop getline_loop
	
	jmp leave_getline_set_null 
	
	leave_getline:
		pop bx
		pop di
		pop cx
	leave_getline_set_null:
		mov byte [di + bx], 0 ; zero index
	pop ax
	pop bx
	pop cx
	ret

	getline_backspace:
		pop bx
		pop di
		dec bx
		mov byte [di + bx], 0
		push di
		push bx
		
		mov dh, 23
		mov dl, bl
		call move_cursor_to_position

		mov al, 0x20
		call writechar

		pop bx
		dec bx ; counter the increment later.
		push bx

		jmp skip_out


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


writechar_with_format:
	; ah will have the format
	push cx 					;0cx
	mov cx, 0xff
	jmp writechar_bypass_push
writechar:
	push cx 					;0cx
	xor cx, cx ; set cx to zero for now
	writechar_bypass_push:
	; al will have the character
	; dx has the position (dh = row, dl = col)
	push es	;1es
	push bx ;3bx
	push ax ;2ax
	
	call calculate_position
	shl ax, 1		; multiply the address by 2 given the format:char words.  
	mov bx, ax	

	push word 0xb800 	; 4word
	pop es				; 4es

	pop ax

	test cx, cx
	jz writechar_byte
		mov [es:bx], ax
	jmp writechar_unwind
	writechar_byte:
		mov [es:bx], al
		inc bx
		mov byte [es:bx], 0x0f ; default format, perhaps set this
	writechar_unwind:

	pop bx ;3bx
	pop es ;1es
	pop cx ;0cx
	ret


writeline_to_screen:
	push bp
	mov bp, sp
	mov word [bp - 2], 0xffff
	jmp write_and_blank
write_string_to_screen:
	; di will have the string
	; dx will have the position
	; write the line and then fill the rest with spaces to overwrite prior output
	push sp
	mov bp, sp
	mov word [bp - 2], 0x0000
	write_and_blank:
	mov word [bp - 4], di
	sub sp, 4
	push si ; (1)
	push ax ; (2)
	push cx
	push es ; (4) save es

	mov si, di
	call string_length ; call string length before changing es
	mov cx, ax

	call calculate_position
	mov di, ax
	shl di, 1

	mov ax, 0xb800
	mov es, ax
	mov ah, 0x0f
	
	test cx, cx
	jz bypass_writeline_loop ; make sure an empty string doesn't enter this loop.  
	
	writeline_loop:
		mov al, [si] ; can't use lodsb because the segment would be wrong
		stosw ; mov [es:di], ax  &&	; add di, 2
		inc si ; still have to take care of the incrementation of si manually
	loop writeline_loop
	
	bypass_writeline_loop:
	
	mov ax, [bp - 2]
	test ax, ax
	jz bypass_blankline
	
	pop es
	mov si, [bp - 4] ; string length uses si rather than di
	call string_length
	push es
	push ax
	mov ax, 0xb800 	; reset es to graphics segment
	mov es, ax 		; 
	pop ax
	mov cx, 80
	sub cx, ax
	mov ax, 0x0f20 ; white text, black background and a space
	line_erase_loop:
		stosw
	loop line_erase_loop

	bypass_blankline:
	
	pop es ; (4)
	pop cx
	pop ax ; (2)
	pop si ; (1)
	mov di, [bp - 4]
	add sp, 4
	pop bp
	ret

section .data
	reading_str db "reading", 0
	reading_str_len equ $ - reading_str
	out_num db 0, 0, 0x20, 0

	new_string db "We have successfully loaded a new segment from the floppy disk.", 0
	empty_string db 0
	halt_string db 'halt', 0

	write_string db 'write', 0		; set byte(s) in ram
	read_string db 'read', 0 		; read byte(s) from ram

	loadf_string db 'fdload', 0	; read from floppy disk
	writef_string db 'fdwrite', 0	; write to floppy disk
	
	exec_string db 'exec', 0		; execute by jumping to the location given

	hex_dump_str db 'hexdump', 0 	; get a hexdump of 512 bytes
	hex_dump_str_len equ $ - hex_dump_str
 
	verify_a20_cmd db "verify a20", 0
	enable_a20_cmd db "enable a20", 0
	disable_a20_cmd db "disable a20", 0

	enter_protected_mode_str db "enter protected mode", 0

	reg_dump_string db 'regdump', 0
	reg_dump_string_len equ $ - reg_dump_string

	special_string db "This is a special string that I want to test out", 0
	
	protected_mode_string db "We have entered protected mode", 0
	a20enstr 	db	"a20 is currently enabled.", 0
	a20disstr 	db	"a20 is currently disabled.", 0 
	
	reg_names db 'ax', 0, 'bx', 0, 'cx', 0, 'dx', 0, 'sp', 0, 'bp', 0, 'si', 0, 'di', 0, 'ss', 0, 'cs', 0, 'ds', 0, 'es', 0, 'fs', 0, 'gs', 0, 'fl', 0, 'ip', 0

	read_location_str db "The value at SSSS:AAAA is XXXX", 0

	found_colon_string db "We have found a colon", 0
	measure_low_ram_string db "measure low memory", 0
	measure_high_ram_string db "measure high memory", 0
	cpuid_string db "cpuid", 0

	gdtable:		; https://github.com/coreos/grub/blob/c6b9a0af3d7483d5b5c5f79caf7ced64298bd4ac/grub-core/kern/i386/realmode.S#L219 for reference
			dq 0 				; null descriptor
		gdt_code_seg:			; code descriptor
			dw 0xFFFF			; limit lowest 16 bits
			dw 0x0				; base lowest 16 bits
			db 0x0 				; base second part
			db 10011011b		; access bits
			db 1111_1100b		; low nibble = flags, high nibble = more of the limit
			db 0x0 				; high part of the base
		gdt_data_seg:			; data descriptor
			dw 0xFFFF			; limit lowest 16 bits
			dw 0x0				; base lowest 16 bits
			db 0x0 				; base second part
			db 10010011b		; access bits
			db 1111_1100b		; low nibble = flags, high nibble = more of the limit
			db 0x0 				; high part of the base
		gdt_end:
			gdtable_size 	dw 		$ - gdtable - 1 		; limit (Size of GDT)
							dd 		gdtable

section .bss
	input_line resb 80
	register_values resw 16
	hex_out_str resb 6
