[bits 16]
global hdboot_entry
;; The goal here is to load current ata sector 2, 3, 4, 5 since 1, 2, 6, 7 are used for boot sectors and file system info blocks. 

secondary_boot_address		equ		0x8000

section .text
hdboot_entry:
cli 				; disable interrupts for safety

mov ax, 0x0003 				; set up color text vga mode
int 0x10

mov cx, 0x0607 				; standard blinking text cursor
mov ah, 1					; enable cursor
int 0x10

mov ah, 0x02 				; set cursor position
xor bh, bh   				; display page (set to zero for now)
xor dx, dx					; dh = row, dl = col
int 0x10	

xor bx, bx
mov es, bx					; zero out the es register

mov ax, 0x0237				; read 55 sectors = 63 - 8
mov cx, 0x0009				; cylinder = 0, sector = "9" which is shifted up 1 from the 0-indexed sector counts
mov dx, 0x0080				; dh = head = 0, two more cylinder bits, set to zero; dl = drive number, set to 0x80 for primary drive
mov bx, secondary_boot_address		; give the address to load
int 0x13					; call the bios interrupt to load the next sectors.  

mov bp, system_ready
mov cx, sys_ready_len
mov bx, 0x000f 				; 01 = first page, 0f = white
mov dx, 0x0100
mov ax, 0x1300 				; output a string
int 0x10

xor ah, ah					; get a key and then jump to the secondary stage
int 0x16

jmp secondary_boot_address

section .data
	system_ready	db	'System Ready.', 0
	sys_ready_len	equ $ - system_ready

section .bpb_boot_sector
	dw		0xeb5a					; jump to position 90 relative
	db		0x90					; nop
	db 		'MARYLAND'				; OEM Name identifier, 8 bytes
	dw		{bytes_per_sector}		; bytes per sector
	db		{sectors_per_cluster}	; sectors per cluster, 4096 bytes per cluster
	dw		{reserved_sectors}		; a reserved sector count
	db		{num_fa_tables}			; num FATs [FAT in this case is File Allocation Table not the entire format]
	dw		0						; for fat32 volumes, set this to zero
	dw		{total_sectors_16}		; total sectors of fat12 or fat16, 0 if fat32
	db		0xf8					; magic code bits for hard drive
	dw 		0						; 16-bit count of sectors occupied by one FAT // 0 for fat32.
	dw		{sectors_per_track}		; fill in with python script after reading drive
	dw		{heads}					; number of heads
	dd		{hidden_sectors}		; hidden sectors, 
	dd		{total_sectors_32}		; fat32 total sector count
	dd		{fat32_table_size}		; number of sectors in a fat table
	dw		{extended_flags}		; extended flags
	dw		0						; revision number
	dd		{root_cluster}			; first cluster of the root directory
	dw		{fsinfo_sector}			; fsinfo structure location
	dw		6						; backup boot sector location
	dd		0,0,0					; 12 bytes of reserved 0's
	db		{bios_drive_number}		; either 0x80 or 0x00
	db		0						; reserved byte zero
	db		{extended_boot_sig}		; 0x29 if either of the next two fields are valid
	dd		{serial_number}			; 
	db		{volume_name}			; must be 11-byte name of the volume
	db		"FAT32   "				; must be 8 bytes so include the 3 spaces

section .boot_signature
	dw 0xaa55
