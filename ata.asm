;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			ata.asm															    ;;;;
;;;;																																;;;;
;;;;		The goal is to provide support for [P/S]ATA hard drives.  				  									  			;;;;
;;;;				For a list of commands:		https://wiki.osdev.org/ATA_Command_Matrix						Eric Hamilton		;;;;
;;;;						also check the ATA documentation Ch7. D1699r6a.pdf									6/18/2024	  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

ATAR_SEC_ALT_STATUS		equ 0x376		; you know the difference i think is that it's F rather than 7 so... literally 0111 vs 1000 in the second nibble.  
ATAR_SEC_DCR2			equ 0x377		; we could or with a single bit to go from secondary to primary.
ATAR_SEC_DATA0			equ 0x170		;
ATAR_SEC_ERRORS			equ 0x171		;
ATAR_SEC_SECTOR_COUNT	equ 0x172		;
ATAR_SEC_SECTOR_NUM		equ 0x173		;
ATAR_SEC_CYL_LOW		equ 0x174		;
ATAR_SEC_CYL_HIGH		equ 0x175		;
ATAR_SEC_DRV_HEAD		equ 0x176		;
ATAR_SEC_STATUS_CMD		equ 0x177		;


extern printline
extern printstrf
extern print_hex_byte
extern print_hex_word
extern print_hex_dword
extern ata_identify_drives
extern ata_display_status
extern ata_read_sector_lba
extern ata_write_sector_lba

extern empty_string
extern extended_code_str

section .text

ATA_CMD_RESET				equ		0x08		
ATA_CMD_READ_SECTORS 		equ		0x20		; reads in 8 bit mode
ATA_CMD_WRITE_SECTORS 		equ		0x30		; writes in bytes
ATA_CMD_READ_SECTORS_EXT 	equ		0x24		; reads in 16 bit mode
ATA_CMD_WRITE_SECTORS_EXT	equ		0x34				
ATA_CMD_WRITE_DMA_EXT		equ		0x01		;;;;; have to figure out how to  do busmastering dma ;;;;; or it with the command to get DMA from PIO
												; DMA only available in 16 bit mode.  
ATA_CMD_CACHE_FLUSH			equ 	0xe7

ATA_LBA48_MASTER			equ		0x40
ATA_LBA48_SLAVE				equ		0x50
ATA_LBA28					equ 	0xa0		; or this with the LBA48 to get LBA28

ATA_BUSY					equ 	1000_0000b
ATA_READY					equ 	0100_0000b
ATA_DRIVE_FAULT				equ 	0010_0000b
ATA_SERVICE_REQ				equ 	0001_0000b

ATA_DRQ						equ 	0000_1000b
ATA_CORRECTED				equ 	0000_0100b		; always set to zero as far as we know.  
ATA_INDEX					equ 	0000_0010b		; also always set to zero
ATA_ERROR					equ 	0000_0001b		; check that there is no error


ata_reset:
	;; ecx contains the ata-controller either 0 or 1 in cl
	and cl, 1
	test cl, cl
	
	jnz .reset_secondary_controller
		mov dx, ATAR_PRI_STATUS_CMD
		jmp .ata_continue_reset
	.reset_secondary_controller:
		mov dx, ATAR_SEC_STATUS_CMD
	.ata_continue_reset:
	
	mov al, ATA_CMD_RESET
	out dx, al
	ret


ata_is_ready:
	; ah will be zero if we're ready to write, al will contain a copy of the actual bits from the command status register
	mov dx, ATAR_PRI_STATUS_CMD
	mov cx, 4					; read the byte four times to introduce a delay and allow it to reset, i don't know that's just what they do
	.in_status_loop:
		in al, dx				; get the resulting status
		dec cx
	jnz .in_status_loop
	
	mov ah, al
	and ah, ATA_BUSY | ATA_READY | ATA_DRIVE_FAULT | ATA_DRQ | ATA_ERROR
	xor ah, ATA_READY
	
	ret

ata_display_status:
	pushad

	call ata_is_ready
	
	mov esi, ata_status_strings
	mov dx, 0x1500
	mov cx, 8
	.display_loop:
		test al, 1
		push eax
		mov al, 0x07					; set to light gray
		jz .bypass_format_set
		mov al, 0x0a					; set to light green
		.bypass_format_set:
		call printstrf

		add esi, 6						; go to the next string
		add dx, 6
		pop eax
		shr al, 1
		dec cx							; count to 8
	jnz .display_loop
	
	popad
	ret


ata_set_sectors:
	mov dx, ATAR_PRI_SECTOR_COUNT
	mov ax, di
	shr ax, 8						; get the high byte
	out dx, al						; load it 

	cmp bl, ATA_CMD_READ_SECTORS
	je bypass_set_high_sectors

		lea esi, [ebp + 7]			; start with the high sector counts
		call ata_set_sector_counts
	
	bypass_set_high_sectors:
	mov dx, ATAR_PRI_SECTOR_COUNT
	mov ax, di
	out dx, al
	
	lea esi, [ebp + 4]				; finish with the low sector counts
	call ata_set_sector_counts
	ret


ata_write_sector_lba:
	;; ecx is the controller and drive 	[cl = controller << 1 | drive]
	;; edx contains number of sectors to write.  
	;; on the stack we'll push a 64 bit long word of the LBA or CHS depending on the mode selected, top two bytes should be zero.  We will store it in mm0
	;; pass as the third stack argument the address to write to.
	;; the difference between LBA28 and LBA48 is or-ing with 0xa0 (for lba 28)
	push ebp
	mov ebp, esp
	pushad
	
	mov edi, edx		; keep edx in edi so that we can modify edx for out instructions
	
	push ebp
	mov ebp, esp
	
	;;;;;;;;;;; currently non-functional until we get more data from the drive and figure out what mode we're in assuming LBA 48... ;;;;;;;;;;;;;;;;;;
	and ecx, 0x00000003							; add a bit of safety to ensure that there's only the proper numbers used as offsets
	mov eax, [ata_drive_flags + 4 * ecx]		; must be modified when the controller is allowed to be non-zero
	;; check drive flags to ensure that it's LBA 48
	;; set bl to the read command, bh to the master-slave selection
	mov bl, ATA_CMD_WRITE_SECTORS_EXT	;; set these based on parameters
	mov bh, ATA_LBA48_MASTER			;; 
	;; test to make sure that the drive is ready
	
	;;;; now comes the hard part, figuring out how to set all of this so that we can determine which type of drive and sending the proper commands.  
	mov dx, ATAR_PRI_DRV_HEAD
	mov al, bh							;; setting this to the LBA28 vs LBA48 & master vs slave on the controller.  
	out dx, al
	
	call ata_set_sectors
	
	mov dx, ATAR_PRI_STATUS_CMD
	mov al, bl						; bl is the read command, either ATA_CMD_READ_SECTORS or ATA_CMD_READ_SECTORS_EXT
	out dx, al
	
	; read the data 
	mov esi, [ebp + 12]				; set esi to the source of the data
	mov dx, ATAR_PRI_DATA0			; set data register
	
	mov cx, 256
	.write_loop:
		outsw						; outputs the word from esi -> al on port dx and then increments esi
		dec cx						; it was recommended not to do this with rep outsw because it is too fast for the ata controller
	jnz .write_loop
	
	
	; insert a delay before re-reading the drive status... 
	call ata_is_ready

	; flush the cache
	mov dx, ATAR_PRI_STATUS_CMD
	mov al, ATA_CMD_CACHE_FLUSH
	out dx, al
	
	popad
	leave	
	ret


ata_read_sector_lba:
	;; ecx is the controller and drive 	[cl = controller << 1 | drive]
	;; edx contains number of sectors to read.  
	;; on the stack we'll push a 64 bit long word of the LBA or CHS depending on the mode selected, top two bytes should be zero.  We will store it in mm0
	;; pass as the third stack argument the address to write to.
	;; the difference between LBA28 and LBA48 is or-ing with 0xa0 (for lba 28)
	push ebp
	mov ebp, esp
	pushad
	
	mov edi, edx		; keep edx in edi so that we can modify edx for out instructions
	
	push ebp
	mov ebp, esp
	
	and ecx, 0x00000003							; add a bit of safety to ensure that there's only the proper numbers used as offsets
	mov eax, [ata_drive_flags + 4 * ecx]		; must be modified when the controller is allowed to be non-zero
	;; check drive flags to ensure that it's LBA 48
	;; set bl to the read command, bh to the master-slave selection
	mov bl, ATA_CMD_READ_SECTORS_EXT	;; set these based on parameters
	mov bh, ATA_LBA48_MASTER			;; 
	;; test to make sure that the drive is ready
	
	;;;; now comes the hard part, figuring out how to set all of this so that we can determine which type of drive and sending the proper commands.  
	mov dx, ATAR_PRI_DRV_HEAD
	mov al, bh							;; setting this to the LBA28 vs LBA48 & master vs slave on the controller.  
	out dx, al
	
	call ata_set_sectors
	
	mov dx, ATAR_PRI_STATUS_CMD
	mov al, bl						; bl is the read command, either ATA_CMD_READ_SECTORS or ATA_CMD_READ_SECTORS_EXT
	out dx, al
	
	; read the data 
	mov cx, 256
	mov edi, [ebp + 12]				; set edi to the location where the data will be written
	mov dx, ATAR_PRI_DATA0			; set data register
	rep insw						; repeat 256 times
	
	; insert a delay before re-reading the drive status... 
	call ata_is_ready
	
	popad
	leave	
	ret
	
ata_set_sector_counts:			; helper function to set the registers, call once for LBA28, twice for LBA48
	mov dx, ATAR_PRI_SECTOR_NUM
	mov cl, 3
	ata_read_set_reg_loop:
		lodsb					; load another byte from esi into al
		out dx, al				; out to the register
		inc dx					; increment to go to the next register.  
		dec cl
	jnz ata_read_set_reg_loop
	ret
	
ata_write_sector:

	ret


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

	ata_status_strings		db		"ERROR", 0
							db		"INDEX", 0
							db		"CORRZ", 0
							db		"DRQ  ", 0
							db		"SRV  ", 0
							db		"FAULT", 0
							db		"READY", 0
							db		"BUSY ", 0
section .bss
	hard_drive_id_data 	resw 256
	ata_drive_flags		resd 4
