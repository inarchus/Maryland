; https://wiki.osdev.org/8259_PIC

PIC_MASTER_CMD	equ		0x20
PIC_SLAVE_CMD	equ		0xa0
PIC_MASTER_DATA	equ		0x21
PIC_SLAVE_DATA	equ		0xa1

PIC_READ_IRR    equ		0x0a
PIC_READ_ISR	equ		0x0b

PIC_MASTER_OFFSET equ	0x20		; in protected mode IRQ0-31 are reserved for processor faults
PIC_SLAVE_OFFSET  equ	0x28		; setting them to 32-47 will prevent this.  

; https://osdev.org/Interrupts#General_IBM-PC_Compatible_Interrupt_Information
PIC_MASTER_MASK   equ	10111110b
PIC_SLAVE_MASK	  equ   11101111b

extern configure_pic
extern display_pic_registers

section .text

configure_pic:
	cli 
	push edx
	push eax
	
	mov al, 0x11
	mov dx, PIC_MASTER_CMD
	out dx, al						; out PIC_MASTER_CMD, 0x11		; ICW4 | INIT
	mov dx, PIC_SLAVE_CMD
	out dx, al 						; out PIC_SLAVE_CMD, 0x11		; ICW4 | INIT
	
	; the next three things here are command words
	
	mov cx, 0x2820				; we should set the offset to something outside the standard exceptions
	call send_pic_word			; set them to interrupt status 0x20 - 0x27.  , set the slave to interrupts 0x28 - 0x2f
		
	; cascade mode, set the master pic to consider the cascade as IRQ2 (0x04) and the slave that its cascade out is (0x02)
	mov cx, 0x0204
	call send_pic_word
	
	mov cx, 0x0101					; send 0x01 = 8086 mode rather than 8080 mode
	call send_pic_word

	; this is not part of the ICW4 command words, it seems like after this is done, you can send another byte and it will 
	; 		set the masks...

	; set the masks so that PIT, Floppy and Mouse are enabled, currently keep keyboard interrupts disabled.  
	;; i think that 0's are enabled, 1 is 'masked'
	mov cx, 11111110_10111010b
	call send_pic_word
	
	pop eax
	pop edx	
	
	sti
	ret
	
send_pic_word:
	; send the masks in cx [ch = slave, cl = master]
	push edx
	push eax

	mov dx, PIC_MASTER_DATA
	mov al, cl				; out PIC_MASTER_DATA, 10111110b	; enable the PIT and the Floppy Disk
	out dx, al						
	mov dx, PIC_SLAVE_DATA
	mov al, ch				; out PIC_SLAVE_DATA, 11101111b	; enable the mouse for IRQs.  
	out dx, al			

	pop eax	
	pop edx
	ret
	
;In-Service Register (ISR) and the Interrupt Request Register (IRR)
display_pic_registers:
	;out PIC_MASTER_CMD, PIC_READ_IRR
	;out PIC_SLAVE_CMD, PIC_READ_IRR
	;out PIC_MASTER_CMD, PIC_READ_ISR
	;out PIC_SLAVE_CMD, PIC_READ_ISR
	
	ret
	
section .data

section .bss