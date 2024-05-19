[bits 16]
[segment 0x8000]

section .text

init:
	xor ax, ax
	mov es, ax
	mov ds, ax
	mov ss, ax
	mov sp, 0x7ffe ; set up the stack so that it can descend.  
	
	mov di, new_string
	xor dx, dx
	call writeline_to_screen

	; enable ps/2 port?
	mov al, 0xAE
	out 0x64, al
	
	main_loop:
		
		mov dx, 0x1700 ; mov dh, 23 ; mov dl, 0
		mov ah, 0x02
		int 0x10 ; move the cursor to the position
		
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
		jmp end_program


menu_options:
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
		jz menu_options_ret
		call display_regdump				
	menu_options_ret:
		ret


display_regdump:
	; save the stack pointer first since that's going to change a lot during the output process
	mov [register_values + 8], sp
	push bp
	push bx
	mov bp, sp
	mov bx, [bp + 4]
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

	push ax
	pushf
	pop ax
	mov [register_values + 28], ax
	pop ax	
	
	
	
	ret

value_to_hex:

	ret


display_hexdump:
	; di is already inputline
	push di
	mov ax, hex_dump_str_len
	call hexchar_address_to_value
	mov di, ax
	call hex_dump
	pop di
	ret


execute_from_location:
	ret

load_from_floppy:
	;  	     	       disk  drive  track sector  n_sectors	dest_seg	location
	; format: fdload DD    VV      TT     SS	NN		   EEEE	LLLL
	; call read_floppy
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
	mov dx, 0x28
	mov di, read_string
	call string_length
	mov cx, ax
	mov bp, di
	mov bx, 0x010f 
	mov ax, 0x1300
	int 0x10
	ret

set_location:
	mov dx, 0x28
	mov di, write_string
	call string_length
	mov cx, ax
	mov bp, di
	mov bx, 0x010f 
	mov ax, 0x1300
	int 0x10
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
	; ax will have an offset
	push si
	mov si, di
	
	add si, ax
	
	next_non_hex:
		mov al, byte [si] 				; scan through non hex 
		call hexchar_to_int
		inc si
		test ah, ah
	jnz next_non_hex

	dec si ; go back one because it's a hex character
	push bx
	xor bx, bx
	mov cx, 4
	next_hex:
		push cx
		mov al, byte [si] 		; scan through non hex 
		call hexchar_to_int
		test ah, ah
		jnz exit_hexchar_addr_to_val_fail
		shl bx, 4				; the first shift left will multiply zero by 16
		add bx, ax			; add the value into bx
		inc si
		pop cx
		loop next_hex

	jmp bypass_hatvf
	exit_hexchar_addr_to_val_fail:
		pop cx
	
	bypass_hatvf:

		mov ax, bx
		pop bx
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
	xor ax, ax ; ensure that al is set to zero
	mov cx, 0xffff
	repnz scasb
	not cx
	dec cx
	mov ax, cx
	pop cx
	pop di
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


hex_dump:
	; di should contain the address of the 512 block to read.
	mov cx, 512
	mov dx, 0x0100
	sub dx, 3
	
	push si
	
	hex_dump_loop:
		push cx
		push di
		push dx
		
		mov dl, [di]
		lea si, [out_num + 1]
		call convert_nibble_to_ascii
		
		mov dl, [di]
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
		mov ah, 0x02
		int 0x10 ; move the cursor to the position				
		
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
		
		mov ah, 0x0a	; output character
		mov bx, 0x000f	; setting color to white
		mov cx, 1 ; number of times to write the character
		int 0x10 ; character should already be in al
		
		;; display the hex code in al to the screen on line 24

		pop ax

		skip_out:
		
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
		mov ah, 0x02
		int 0x10 ; move the cursor to the position

		mov ah, 0x0a	; output character
		mov al, 0x20 ; space
		mov bx, 0x000f	; setting color to white
		mov cx, 1 ; number of times to write the character
		int 0x10 ; character should already be in al

		pop bx
		dec bx ; counter the increment later.
		push bx

		jmp skip_out


calculate_address_from_position:
	; dx has the position (dh = row, dl = col)
	; returns in ax
	push bx
	movzx ax, dh
	mov bl, 80
	mul bl
	movzx bx, dl
	add ax, bx
	pop bx
	ret

writechar_with_format:
	; ah will have the format
	push cx
	mov cx, 0xff
	jmp writechar_bypass_push
writechar:
	push cx ;0
	xor cx, cx ; set cx to zero for now
	writechar_bypass_push:
	; al will have the character
	; dx has the position (dh = row, dl = col)
	push ax ;1
	push bx ;2
	call calculate_address_from_position
	mov bx, ax
	
	push si ;3
	mov si, es
	push si ;4
	mov si, 0xb800
	mov es, si
	test cx, cx

	jz writechar_byte
		mov [es:bx], ax
	jmp writechar_unwind
	writechar_byte:
		mov [es:bx], al
		inc bx
		mov byte [es:bx], 0x0f ; default format, perhaps set this
	writechar_unwind:

	pop si ;4
	mov es, si
	pop si ;3
	
	pop bx ;2
	pop ax ;1
	pop cx ;0
	ret


writeline_to_screen:
	push sp
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

	call calculate_address_from_position
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
	pop sp
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

	reg_dump_string db 'regdump', 0
	reg_dump_string_len equ $ - reg_dump_string

	special_string db "This is a special string that I want to test out", 0

	boot_segment equ 0x800

section .bss
	input_line resb 80
	register_values resw 16

