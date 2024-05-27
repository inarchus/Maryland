global start
[BITS 16]

extern kernel_loader_entry

section .text

kernel_segment equ 0x700
load_address equ 0x1000

start:
	cli
	xor ax, ax
	mov ss, ax
	mov sp, ax
	mov bp, ax
	mov es, ax

	mov ax, 0x0003 				; set up color text vga mode
	int 0x10

	mov cx, 0x0607 				; standard blinking text cursor
	mov ah, 1
	int 0x10
	
	mov bx, out_string
	mov al, byte [bx]
	xor di, di
	mov ah, 0x02 				; set cursor position
	xor bh, bh   				; graphics mode (set to zero for now)
	mov dx, di
	push di
	int 0x10

	xor ax, ax
	mov es, ax
	mov dx, 0x0000 				; high word is row, low word is col (zero indexed)
	mov cx, out_string_len
	mov bx, 0x000f 				; 01 = first page, 0f = white
	mov bp, out_string 			; address is at es:bp, set es=0
	mov ax, 0x1300 				; output a string
	int 0x10
	
	mov ax, 0x0210				; read from floppy ah = 2 - sixteen sectors al = 0x10
	mov dx, 0x0000 				; dx high word is the head (side of the disk, 1 indexed, lies, 0 indexed), low word is the drive  (0 indexed = fda, 1 = fdb)
	mov cx, 0x0003				; cx high word is the track, low word is the sector
	mov bx, kernel_segment		; clear the segment for the initial assembly reads
	mov es, bx
	mov bx, load_address		; bx contains the location to write in the segment es:bx
	int 0x13	 				; read from floppy disk drive
	
	xor ax, ax
	mov es, ax
	mov dx, 0x0200 				; high word is row, low word is col (zero indexed)
	mov cx, press_key_len
	mov bx, 0x000f 				; 00 = first page, 0f = white
	mov bp, press_key
	mov ax, 0x1300 
	int 0x10
	
	xor ah, ah
	int 0x16

	jmp kernel_segment:load_address

	out_string db "Bootloader Detected... Loading from Floppy Disk", 0
	out_string_len equ $ - out_string
	press_key db "Press any key to jump into the next segment. ", 0
	press_key_len equ $ - press_key
