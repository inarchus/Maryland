; barely functional, currently it faults on both VMWare and VirtualBox, though it works on QEMU for now.  
;  https://cpctech.cpcwiki.de/docs/i8272/8272sp.htm
;

FDA_SRA         equ 0x3F0	;  read-only STATUS_REGISTER_A
FDA_SRB         equ 0x3F1	;  read-only STATUS_REGISTER_B
FDA_DOR 	    equ 0x3F2	; DIGITAL_OUTPUT_REGISTER
FDA_TDR	        equ 0x3F3	; TAPE_DRIVE_REGISTER
FDA_MSR         equ 0x3F4	;  read-only  MAIN_STATUS_REGISTER
FDA_DSR         equ 0x3F4	;  write-only DATARATE_SELECT_REGISTER
FDA_FIFO        equ 0x3F5	; DATA_FIFO
FDA_DIR         equ 0x3F7	;  read-only DIGITAL_INPUT_REGISTER
FDA_CCR 	    equ 0x3F7   ;  write-only CONFIGURATION_CONTROL_REGISTER

; Note: IO port 0x3F6 is the ATA (hard disk) Alternate Status register, and is not used by any floppy controller. Of course it is.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; DOR Bits ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FD_MOTD		equ 0x80	; Set to turn drive 3's motor ON
FD_MOTC		equ 0x40	; Set to turn drive 2's motor ON
FD_MOTB		equ 0x20	; Set to turn drive 1's motor ON
FD_MOTA		equ 0x10	; Set to turn drive 0's motor ON
FD_IRQ		equ 0x08	; Set to enable IRQs and DMA
FD_RESET	equ 0x04	; Clear = enter reset mode, Set = normal operation
FD_DSEL1	equ 0x02	; "Select" drive number for next access
FD_DSEL0	equ 0x01	; "Select" drive number for next access

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; MSR Bits ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
						;	Mnemonic	bit number	value	meaning/usage
FD_RQM		equ 0x80	;	RQM	7	0x80	Set if it's OK (or mandatory) to exchange bytes with the FIFO IO port
FD_DIO		equ 0x40	;	DIO	6	0x40	Set if FIFO IO port expects an IN opcode
FD_NDMA 	equ 0x20	;	NDMA	5	0x20	Set in Execution phase of PIO mode read/write commands only.
FD_CB   	equ 0x10	;	CB	4	0x10	Command Busy: set when command byte received, cleared at end of Result phase
FD_D3SEEK	equ 0x08	;	ACTD	3	8	Drive 3 is seeking
FD_D2SEEK	equ 0x04	;	ACTC	2	4	Drive 2 is seeking
FD_D1SEEK	equ 0x02	;	ACTB	1	2	Drive 1 is seeking
FD_D0SEEK	equ 0x01	;	ACTA	0	1	Drive 0 is seeking

FD_RW_MFM			equ 		0x40		; MFM magnetic encoding mode, set it for r/w operations
FD_RW_MT			equ 		0x80		; multitrack mode

FCMD_READ_TRACK		equ 		2
FD_WRITE_DATA		equ			5
FD_READ_DATA		equ 		6
FCMD_RECALIBRATE	equ			7
SENSE_INTERRUPT		equ			8
FCMD_SEEK			equ			15
FCMD_VERSION 		equ			16
FCMD_CONFIGURE		equ 		19
FCMD_LOCK			equ 		20

FLOPPY_DRIVE_CMOS_REGISTER	equ 	0x10

; FloppyCommands
;   READ_TRACK =                 2,		 // generates IRQ6
;   SPECIFY =                    3,      // * set drive parameters
;   SENSE_DRIVE_STATUS =         4,
;   WRITE_DATA =                 5,      // * write to the disk
;   READ_DATA =                  6,      // * read from the disk
;   RECALIBRATE =                7,      // * seek to cylinder 0
;   SENSE_INTERRUPT =            8,      // * ack IRQ6, get status of last command
;   WRITE_DELETED_DATA =         9,
;   READ_ID =                    10,	// generates IRQ6
;   READ_DELETED_DATA =          12,
;   FORMAT_TRACK =               13,     // *
;   DUMPREG =                    14,
;   SEEK =                       15,     // * seek both heads to cylinder X
;   VERSION =                    16,
;   SCAN_EQUAL =                 17,
;   PERPENDICULAR_MODE =         18,	// * used during initialization, once, maybe
;   CONFIGURE =                  19,     // * set controller parameters
;   LOCK =                       20,     // * protect controller params from a reset
;   VERIFY =                     22,
;   SCAN_LOW_OR_EQUAL =          25,
;   SCAN_HIGH_OR_EQUAL =         29

extern printstr
extern printstrf
extern printlinef
extern print_hex_dword
extern getchar_pressed
extern pit_wait

section .text
extern fdisk_display_msr
extern fdisk_init_controller
extern floppy_irq6_handler
extern fdisk_seek
extern fdisk_read_sector
extern fdisk_recalibrate
extern fdisk_version
extern fdisk_identify

fdisk_verify_ready:			;	modifies ax, returns in al
	push edx
	mov dx, FDA_MSR
	in al, dx
	and al, FD_RQM | FD_DIO
	xor al, FD_RQM
	test al, al
	mov ax, 1		; use the mov instead of xor to preserve the flags for the next cmovz
	jz fdisk_verify_bypass
	xor ax, ax
	fdisk_verify_bypass:
	pop edx
	ret
	

fdisk_version:
	; returns the version of the controller in al
	push edx
	mov dx, FDA_FIFO		; Send a Version command to the controller.
	mov al, FCMD_VERSION
	out dx, al
	in al, dx
	pop edx
	ret
	
fdisk_identify:
	; always displays zeros, no drives detected even though there are drives.  
	push edx

	cli
	mov dx, 0x70
	mov al, FLOPPY_DRIVE_CMOS_REGISTER | 0x80
	out dx, al
	
	; wait here write a wait function using the PIT	
	mov dx, 0x71
	in al, dx
	sti

	; mov ecx, eax
	; mov edx, 0x1500
	; call print_hex_dword
	
	push eax
	
	mov esi, primary_string
	mov dx, 0x122e
	call printstr
	
	pop eax

	and eax, 0x000000f0
	
	push eax
	
	mov dx, 0x1240
	lea esi, [drive_types + eax]
	call printstr
	
	mov dx, 0x132e
	mov esi, secondary_string
	call printstr

	pop eax
	and eax, 0x0000000f
	shl al, 4
	mov dx, 0x1340
	lea esi, [drive_types + eax]
	call printstr
	
	pop edx
	ret
	
	
fdisk_enable_dma:
    mov dx, 0x0a
	mov al, 0x06
	out dx, al			; mask DMA channel 2 and 0 (assuming 0 is already masked)
	
	mov dx, 0x0c
	mov al, 0xff
	out dx, al			; reset the master flip-flop

	mov dx, 0x04
	xor al, al 
	out dx, al			; address to 0 (low byte)
    
	mov dx, 0x04
	mov al, 0x10        ; address to 0x10 (high byte)
	out dx, al			; actually set the high byte

	mov dx, 0x0c
	mov al, 0xff
	out dx, al			; reset the master flip-flop

	mov dx, 0x05
	mov al, 0xff
    out dx, al		    ; count to 0x33ff (low byte)
	
	mov dx, 0x05
	mov al, 0x23
    out dx, al		    ; count to 0x33ff (high byte)
    
	mov dx, 0x81
	xor al, al
	out dx, al			; external page register to 0 for total address of 00 10 00
	
	mov dx, 0x0a
	mov al, 0x02
	out dx, al			; unmask DMA channel 2
	
	ret
	

fdisk_init_controller:
	
	; If you don't want to bother having to send another Configure command after every Reset procedure, then:
	; Send a better Configure command to the controller. A suggestion would be: drive polling mode off, FIFO on, threshold = 8, implied seek on, precompensation 0. 
	; Send a Lock command.
	; Do a Controller Reset procedure.
	; Send a Recalibrate command to each of the drives.

	push ebx
	
	call fdisk_verify_ready
	test al, al
	jz fdisk_init_controller_exit
	
	call fdisk_version
	cmp al, 0x90
	
	jne fdisk_init_controller_exit
	mov dx, FDA_FIFO
	mov al, FCMD_CONFIGURE
	out dx, al
	
	xor al, al 			; set byte to zero
	out dx, al			;  
	
	mov al, 0111_0111b 	; (implied seek ENable << 6) | (fifo DISable << 5) | (drive polling mode DISable << 4) | thresh_val (= threshold - 1)
						; set threshold = 8 - 1 so that we get 8 bytes at a time.  
	out dx, al			; find documentation for these bits.  
	
	xor al, al 			; precompensation = 0
	out dx, al	
	
	mov dx, FDA_DOR
	;         Drive A motor on | Enable IRQ & DMA | RESET OFF | Select drive 1.  
	mov al, 0001_1111b
	out dx, al

	; enabling DMA
	call fdisk_enable_dma

	fdisk_init_controller_exit:
	
	call fdisk_display_msr
		
	pop ebx
	ret
	

;; fast call so put the drive number in cl
fdisk_recalibrate:
	push eax
	push edx
	
	mov dx, FDA_FIFO
	mov al, FCMD_RECALIBRATE
	out dx, al
	; currently this causes a fault and reboot.  
	; mov dx, FDA_FIFO
	; mov al, 0 ; cl
	; out dx, al
	
	pop edx
	pop eax	
	ret

fdisk_seek:
	; use __fastcall or pass argument in ecx = [ch = head_num, cl = cylinder_num, dl = drive]
	push edx
	
	mov dx, FDA_FIFO
	mov al, FCMD_SEEK
	out dx, al
	
	mov al, ch 	; head_num 
	shl al, 2  	; 
	pop edx
	or al, dl
	push edx
	out dx, al
	
	mov al, cl	; cylinder_num
	out dx, al
	pop edx
	
	ret
	

fdisk_dma_read_init:
    mov dx, 0x0a
	mov al, 0x06
	out dx, al		; mask DMA channel 2 and 0 (assuming 0 is already masked)
	
	inc dx			; go to the 0x0b port
	mov al, 0x56	; single transfer, address increment, autoinit, read, channel2) (01010110)
	out dx, al
	
	dec dx
	mov al, 0x02
	out dx, al		; unmask DMA channel 2

    ret


fdisk_display_msr:
	push edx
	push eax
	push ecx
	push esi
	
	mov dx, FDA_MSR
	in al, dx			; read the main status register
	
	mov esi, msr_strings
	mov cx, 8
	
	mov dx, 0x1600		; can change this in the future
	
	fdisk_display_msr_loop:
		test al, 1
		push eax
		mov al, 0x07					; set to light gray
		jz fdisk_dmsrloop_bypass_set	
		mov al, 0x0a					; set to light green
		fdisk_dmsrloop_bypass_set:
	
		call printstrf

		add edx, 5
		add esi, 5	; go to the next string
		pop eax
		shr al, 1
		dec cx		; count to 8
	jnz fdisk_display_msr_loop

	pop esi
	pop ecx
	pop eax
	pop edx
	ret


fdisk_read_sector:
	; 

	; rdi will contain the pointer to the destination 
	; we'll have to have (disk: drive) (track: sector)
		;  	     	       disk  drive  track sector  n_sectors	dest_seg	location
	; format: fdload 	DD    VV      TT     SS	  NN		   			SEG:ADDR
	; my guess is that disk is the floppy disk itself, drive is probably actually side? for 1.44 mb there's only 0 or 1 probably since there's only two sides
	; there are 80 tracks on the disk and 18 sectors per track, a sector is 512 bytes.  
	; set the disk and drive by default to start, allow Track:Sector Num_Sectors SEG:ADDR
	
	; First parameter byte = (head number << 2) | drive number (the drive number must match the currently selected drive!)
	; Second parameter byte = cylinder number
	; Third parameter byte = head number (yes, this is a repeat of the above value)
	; Fourth parameter byte = starting sector number
	; Fifth parameter byte = 2 (all floppy drives use 512bytes per sector)
	; Sixth parameter byte = EOT (end of track, the last sector number on the track)
	; Seventh parameter byte = 0x1b (GAP1 default size)
	; Eighth parameter byte = 0xff (all floppy drives use 512bytes per sector)

	movd mm0, edx
	
	push ebx
	push edx
	
	mov dx, 0x0400
	mov ecx, [ecx]
	call print_hex_dword
	
	pop edx
	
	push ecx
	mov ecx, edx
	mov dx, 0x040c
	call print_hex_dword

	call fdisk_dma_read_init
	
	pop ecx
	mov ecx, [ecx]			; ecx contains the address of a struct with the data needed for the operation
	
	push edx

	call fdisk_verify_ready
	test al, al
	jz exit_fdisk_read_sector

	mov dx, FDA_FIFO
	mov al, FD_RW_MFM | FD_RW_MT | FD_READ_DATA		; Read command = MT bit | MFM bit | 0x6
	out dx, al

	mov al, ch	 	; ch will contain the head number
	shl al, 2
	
	mov ebx, ecx 	; ecx's high word will contain the drive number
	shr ebx, 16
	
	or al, bl		; bl contains the head number 
	out dx, al
	
	mov al, cl		; cl will contain the track (cylinder)
	out dx, al
	
	mov al, bl		; bl contains the head number (again) 
	out dx, al
	
	movd eax, mm0	; edx->mm0->eax will contain the starting sector number, at least in al
	out dx, al
	
	mov al, 2		; 2 (apparently this means 512 bytes / sector, don't know what the other settings could be)
	out dx, al
	
	mov al, 18		; number of sectors per track
	out dx, al

	mov al, 0x1b	; GAP1 default size (not sure what this means)
	out dx, al

	mov al, 0xff	; 512 bytes per sector (not sure what this means precisely or other options are).
	out dx, al
	
	call fdisk_display_msr
	call getchar_pressed
	
	mov dx, FDA_MSR 	; check to make sure that RQM = 1
	fdisk_read_wait_for_msr:
		call fdisk_display_msr
		in al, dx
		test al, 0x80
	jz fdisk_read_wait_for_msr
	
	call fdisk_display_msr
	call getchar_pressed
	
	mov cx, 7
	fdisk_read_status_bytes:
		call fdisk_display_msr
		
		mov dx, FDA_FIFO
		in al, dx
		dec cx
	jnz fdisk_read_status_bytes
	
	mov edi, fdisk_sector_data
	
	call getchar_pressed
	
	mov ecx, [0x1000]
	mov dx, 0x0600
	call print_hex_dword
	
	mov dx, FDA_MSR
	fdisk_read_wait_for_msr2:
		in al, dx
		test al, 0x80
	jz fdisk_read_wait_for_msr2
	
	exit_fdisk_read_sector:
	
	pop edx
	pop ebx
	ret

section .data
	fdisk_read_start_string 		db	 'Starting Floppy Disk Read', 0
	msr_strings 	db 'ACTA', 0
					db 'ACTB', 0
					db 'ACTC', 0
					db 'ACTD', 0
					db 'BUSY', 0
					db 'NDMA', 0
					db 'DIO ', 0
					db 'RQM ', 0
	primary_string	  db "Primary Drive:", 0
	secondary_string  db "Secondary Drive:", 0
	drive_types	 	  db "No Drive       ", 0
					  db "360 KB, 5.25 in", 0
					  db "1.2 MB, 5.25 in", 0
					  db "720 KB, 5.25 in", 0
					  db "1.44 MB, 3.5 in", 0
					  db "2.88 MB, 3.5 in", 0
section .bss
	fdisk_sector_data 				resb 512
