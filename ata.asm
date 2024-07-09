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

; from kernel.asm
extern printline
extern printstrf
extern printchar
extern print_hex_byte
extern print_hex_word
extern print_hex_dword


extern ata_identify_drives
extern ata_identify_drive

extern ata_display_status
extern ata_read_sector_lba
extern ata_write_sector_lba

extern clear_screen

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

		lea esi, [ebp + 12]			; start with the high sector counts
		call ata_set_sector_counts
	
	bypass_set_high_sectors:
	mov dx, ATAR_PRI_SECTOR_COUNT
	mov ax, di
	out dx, al
	; this next one is weird, we're starting at +9 rather than +8 because we load 3 bytes at a time, not 4.  
	lea esi, [ebp + 9]				; finish with the low sector counts
	call ata_set_sector_counts
	ret


ata_write_sector_lba:
	;; ecx is the controller and drive 	[cl = controller << 1 | drive]
	;; edx contains number of sectors to write.  
	;; on the stack we'll push a 64 bit long word of the LBA or CHS depending on the mode selected, top two bytes should be zero.  We will store it in mm0
	;; pass as the second stack argument the address to write to. [32 bits this time]
	;; the difference between LBA28 and LBA48 is or-ing with 0xa0 (for lba 28)
	push ebp
	mov ebp, esp
	pushad
	
	push ecx
	push edx

	mov ecx, [ebp + 4]		; return address
	mov edx, 0x0500
	call print_hex_dword
	
	mov ecx, [ebp + 8]		
	mov edx, 0x050c
	call print_hex_dword
	
	
	mov ecx, [ebp + 12]
	mov edx, 0x0518
	call print_hex_dword

	mov ecx, [ebp + 16]
	mov edx, 0x0522
	call print_hex_dword

	
	pop edx
	pop ecx
		
	mov edi, edx		; keep edx in edi so that we can modify edx for out instructions
	
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
	mov esi, [ebp + 16]				; set esi to the source of the data
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
	
	push ecx
	push edx

	mov ecx, [ebp + 4]		; return address
	mov edx, 0x0500
	call print_hex_dword
	
	mov ecx, [ebp + 8]		
	mov edx, 0x050c
	call print_hex_dword
	
	
	mov ecx, [ebp + 12]
	mov edx, 0x0518
	call print_hex_dword

	mov ecx, [ebp + 16]
	mov edx, 0x0522
	call print_hex_dword

	
	pop edx
	pop ecx
	
	mov edi, edx		; keep edx in edi so that we can modify edx for out instructions
	
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
	
	; have to wait until the data is ready...
	mov dx, ATAR_DCR1
	.wait_until_drq:
		in al, dx
		test al, 0x08 ; 0000_1000b
	jz .wait_until_drq	
	
	; read the data 
	mov cx, 256
	mov edi, [ebp + 16]				; set edi to the location where the data will be written
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

ata_identify_drive:
	;; ecx = controller << 1 | drive
	;; edx = pointer to the data
	push edx
	
	test cl, 0x02		; test to see if the controller is 1.  
	jnz .set_secondary_drive_cmd
	mov dx, ATAR_PRI_STATUS_CMD
	jmp .bypass_secondary_drive_set
	.set_secondary_drive_cmd:
	mov dx, ATAR_SEC_STATUS_CMD
	.bypass_secondary_drive_set:
	
	mov al, 0xec		; identify command
	out dx, al
	
	in al, dx
	test al, al
	jnz .drive_exists
	
	xor eax, eax		; set eax to zero 
	pop edx
	
	jmp .id_exit
	
	.drive_exists:
	pop edx
	
	mov edi, edx
	
	test cl, 0x02
	jnz .set_secondary_data
	mov dx, ATAR_PRI_DATA0
	jmp .bypass_secondary_data
	.set_secondary_data:
	mov dx, ATAR_SEC_DATA0
	.bypass_secondary_data:
	
	mov cx, 0x100
	.id_loop:
		in ax, dx
		stosw
		dec cx
	jnz .id_loop
	
	mov eax, 1
	
	.id_exit:
	
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

	call clear_screen
	
	mov al, 0x0f
	mov esi, LOG_SEC_COUNT			; words 10-19
	mov dx, 0x0500
	call printstrf
	
	mov ecx, [hard_drive_id_data + 2 * 102]		; since it's little endian take the bigger number first
	mov dx, 0x0512
	call print_hex_dword
	
	mov ecx, [hard_drive_id_data + 2 * 100]		; now look at the smaller one
	add dx, 9
	call print_hex_dword
	
	mov al, 0x0f
	mov esi, LOG_SEC_SIZE
	add dx, 0x10
	call printstrf
	
	mov ecx, [hard_drive_id_data + 2 * 117]
	add dx, 0x18
	call print_hex_dword
	
	mov al, 0x0f
	mov esi, PHYS_SEC_RATIO
	mov dx, 0x0600
	call printstrf
	
	add dx, 22		; decimal 22 not hex.
	mov ecx, [hard_drive_id_data + 2 * 106]
	call print_hex_word

	mov al, 0x0f
	mov esi, SERIAL_NUM	
	mov dx, 0x0300
	call printstrf

	mov ecx, 10	; 10 words, not bytes, just remember
	lea edx, [hard_drive_id_data + 2 * 10]
	push edx 
	mov dx, 0x0310
	call print_ata_string
	add esp, 4
	
	
	
	mov al, 0x0f
	mov esi, FIRMWARE_VER	
	mov dx, 0x0328
	call printstrf

	mov ecx, 4	
	lea edx, [hard_drive_id_data + 2 * 23]
	push edx 
	mov dx, 0x0338
	call print_ata_string
	add esp, 4
	
	mov al, 0x0f
	mov esi, MODEL_NUM	
	mov dx, 0x0400
	call printstrf

	mov ecx, 20
	lea edx, [hard_drive_id_data + 2 * 27]
	push edx 
	mov dx, 0x0410
	call print_ata_string
	add esp, 4
	
	
	ata_id_exit:
	
	ret
	
print_ata_string:
	; ecx will contain the number of characters
	; edx will be the edx location
	; first stack argument will contain a pointer to the start address
	; ATA strings may not be null terminated and are encoded backwards, i.e. "abcd" = [ba][dc], so we have to flip each byte in its word to get the correct order

	push ebp
	mov ebp, esp

	push ecx
	push edx
	push esi

	mov esi, [ebp - 4]
	.ata_string_loop:
		lodsw
		xchg al, ah
		call printchar
		xchg al, ah
		inc dx
		call printchar
		inc dx
		dec cx
	jnz .ata_string_loop
	
	pop esi
	pop edx
	pop ecx
	
	leave
	ret

section .data
	SERIAL_NUM		db		"Serial Number:", 0		; words 10-19 (ATA string)
	FIRMWARE_VER	db		"Firmware Rev.:", 0		; words 23-26 (ATA string)
	MODEL_NUM		db		"Model Num.:", 0		; words 27-46 (ATA string)
	FEATURE_SET_1	db		"Feature Set 1:",0 		; word 82 command and feature sets supported 1
	FEATURE_SET_2	db		"Feature Set 2:",0 		; word 83 command and feature sets supported 2
	FEATURE_SET_3	db		"Feature Set 3:",0 		; word 84 command and feature sets supported 3
	FEATURE_SET_4	db		"Feature Set 4:",0 		; word 85 command and feature sets supported 4
	FEATURE_SET_5	db		"Feature Set 5:",0		; word 86 command and feature sets supported 5
	FEATURE_SET_6	db		"Feature Set 6:",0 		; word 87 command and feature sets supported 6
	STREAM_MIN_SIZE	db		"Min. Req. Size:", 0 	; word 95 stream minimum request size
	STREAM_TR_DMA	db		"Transfer Time (DMA):", 0 ; word 96 stream transfer time (DMA)
	STREAM_AC_LAT	db		"Access Latency:",0		;; word 97 stream access latency DMA & PIO
	; word 98-99 Streaming Performance Granularity  (dword) / no idea what this is.  
	LOG_SEC_COUNT	db		"Logical Sectors: ", 0		; words 100-103 total number of logical sectors (qword)
	STREAM_TR_PIO 	db 		"Transfer Time (PIO):",0 	; streaming transfer time (PIO)
	PHYS_SEC_RATIO	db 		"Phys/Log. Sec. Size:", 0 ; word 106 physical sector size / logical sector size
	WW_NAME			db 		"World Wide Name:", 0	; words 108-111 world wide name ??
	LOG_SEC_SIZE	db		"Logical Sector Size:", 0 ; words 117-118, logical sector size (dword)
	; words 176-205, media serial number
	
	MWDMA_STR		db		"Multiword DMA Mode: ", 0	;
	UDMA_STR		db		"Ultra DMA Mode: ", 0 		; Ultra DMA modes supported/selected
	MAX_LBA			db		"Maximum LBA: ", 0			;

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
