;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			ata.asm																							    ;;;;
;;;;																																								;;;;
;;;;		The goal is to provide support for [P/S]ATA hard drives.  				  																	  			;;;;
;;;;																																			Eric Hamilton		;;;;
;;;;																																			5/27/2024	  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ATAR_DCR1			 	equ 0x3F6		; 
ATAR_DCR2			 	equ 0x3F7		;
ATAR_PRI_DATA0			equ 0x1F0		;
ATAR_PRI_ERRORS			equ 0x1F1		;
ATAR_PRI_SECTOR_COUNT	equ 0x1F2		;
ATAR_PRI_SECTOR_NUM		equ 0x1F3		;
ATAR_PRI_CYL_LOW		equ 0x1F4		;
ATAR_PRI_CYL_HIGH		equ 0x1F5		;
ATAR_PRI_DRV_HEAD		equ 0x1F6		;
ATAR_PRI_STATUS_CMD		equ 0x1F7		;

extern printline
extern printstrf
extern print_hex_byte
extern print_hex_word
extern print_hex_dword
extern ata_identify_drives

extern empty_string

section .text


ata_identify_drives:
	
	mov dx, ATAR_PRI_DRV_HEAD
	mov al, 0xa0		; for the master drive
	out dx, al
	
	mov cx, 16
	mov dx, 0x0600
	clear_screen_loop:
		mov esi, empty_string
		call printline
		inc dh
		dec cx
	jnz clear_screen_loop
	
	mov cx, 4
	ata_identify_zero_loop:
		mov dx, ATAR_PRI_SECTOR_COUNT
		xor al, al
		out dx, al
		inc dx
		dec cx
	jnz ata_identify_zero_loop
	
	mov dx, ATAR_PRI_STATUS_CMD
	mov al, 0xec		; identify command
	out dx, al
	
	in al, dx
	test al, al
	jnz ata_id_drive_exists
	
	mov dx, 0x0600
	mov al, 0x0f
	mov esi, DRIVE_DOES_NOT_EXIST
	call printstrf
	jmp ata_id_exit
	
	ata_id_drive_exists:
	
	mov edi, hard_drive_id_data
	
	mov dx, ATAR_PRI_DATA0		; always should have been this one anyway...
	mov cx, 0x100
	ata_identify_drives_loop:
		in ax, dx
		stosw
		dec cx
	jnz ata_identify_drives_loop

	mov esi, hard_drive_id_data
	
	mov cx, 0x100
	mov dx, 0x0600
	ata_identify_print_loop:
		lodsw
		
		push ecx
		mov cx, ax
		call print_hex_word
		add dx, 5
		cmp dl, 75
		jbe bypass_nextline
		inc dh
		xor dl, dl
		bypass_nextline:
		pop ecx
		dec cx
	jnz ata_identify_print_loop
	
	ata_id_exit:
	
	ret

section .data
	MWDMA_STR	db		"Multiword DMA Mode: ", 0
	UDMA_STR	db		"Ultra DMA Mode: ", 0
	MAX_LBA		db		"Maximum LBA: ", 0

	DRIVE_DOES_NOT_EXIST db		"Drive Does Not Exist", 0
section .bss
	hard_drive_id_data resw 256
