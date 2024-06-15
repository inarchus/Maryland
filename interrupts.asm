;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			interrupts.asm																					    ;;;;
;;;;																																								;;;;
;;;;		The goal is to provide interrupt functionality for the operating system rather than having it interspersed throughout the kernel code.					;;;;
;;;;																																			Eric Hamilton		;;;;
;;;;																																			6/15/2024	  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Here is an example of a table entry.  
;		pit_interrupt_table_entry:
;			dw low word of pit_interrupt_irq0										; low word of the address
;			dw 0x0008													; code segment
;			db 0 														; reserved////
;			db 1_00_0_1110b 											; flags
;			dw high word of pit_interrupt_irq0							; high word of the address of the interrupt handler.  


extern printstrf
extern print_hex_byte
extern print_hex_word
extern print_hex_dword

extern configure_interrupt_descriptor_table
extern set_interrupt_callback

section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; generic_fault																					  ;;;; 	
;;;; 	This interrupt callback is called when an interrupt for the 0x0 - 0x1f interrupts are called  ;;;; 	
;;;;		These interrupts are reserved by the processor for faults								  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
generic_fault:
	iretd
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; generic_pic_interrupt																			  ;;;; 	
;;;; 	This interrupt should be called when we don't have an interrupt for a specific PIC controller ;;;; 	
;;;;			Recall that we must signal the PIC with out 0x20, 0x20 to enable future interrupts	  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
generic_master_pic_interrupt:
	push eax
	push edx
	mov dx, 0x20
	mov al, 0x20
	out dx, al ; we must send the ACK to the Master PIC

	pop edx
	pop eax
	iretd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; generic_slave_pic_interrupt																  	  ;;;; 	
;;;; 	This interrupt should be called when we don't have an interrupt for a specific PIC controller ;;;; 	
;;;;			Recall that we must signal the PIC with out 0xa0, 0x20 to enable future interrupts	  ;;;; 	
;;;;			from the slave and then another out 0xa0, 0x20 to enable future interrupts from mstr  ;;;; 	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
generic_slave_pic_interrupt:
	push eax
	push edx
	
	mov al, 0x20
	mov dx, 0xa0	; send the slave ACK first.
	out dx, al 
	mov dx, 0x20
	out dx, al 		; we must send the ACK to the Master PIC

	pop edx
	pop eax
	iretd



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; generic_interrupt																			  	  ;;;; 	
;;;; 	This interrupt should be called when we don't have an interrupt for an interrupt code		  ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
generic_interrupt:
	push ecx
	push edx
	
	pop edx
	pop ecx

	iretd


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; configure_interrupt_descriptor_table															  ;;;; 	
;;;; 	This function will set all of the interrupts to generics so that we can then set them to      ;;;; 	
;;;;		proper functions when we declare them in other files.  This may also give modularity,     ;;;; 	
;;;;		so we can enable and disable various interrupts and callbacks or set new callbacks during ;;;; 	
;;;;		runtime.  																			      ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
configure_interrupt_descriptor_table:
	cli
	
	mov edi, interrupt_descriptors
	
	mov ah, [idt_default_flags]	; set the default flags
	xor al, al					; reserved set to zero
	shl eax, 16
	mov ax, [idt_code_segment]	; set to the default code segment
	
	mov ecx, 256		; configure processor interrupts
	mov edx, generic_fault
	define_fault_loop:
		cmp ecx, 224
		ja skip_pic_user_int
		mov edx, generic_master_pic_interrupt
		cmp ecx, 216
		ja skip_pic_user_int
		mov edx, generic_slave_pic_interrupt
		cmp ecx, 208
		ja skip_pic_user_int
		jb bypass_set_flags
		
			push ebx
			mov bl, [idt_ring3_flags]
			shl bl, 16
			or eax, ebx
			pop ebx
		
		bypass_set_flags:
		mov edx, generic_interrupt
		skip_pic_user_int:
		mov word [edi], dx
		add edi, 2
		stosd
		ror edx, 16
		mov word [edi], dx
		add edi, 2
		ror edx, 16
		dec ecx
	jnz define_fault_loop
	
	lidt [idt_desc_struct]				; load the struct describing the table
	
	sti
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; set_interrupt_callback																			  ;;;; 	
;;;; 	This interrupt should be called when we don't have an interrupt for a specific PIC controller ;;;; 	
;;;;																 								  ;;;; 	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set_interrupt_callback:
	; fastcall so ecx should have the interrupt number, edx will have the callback pointer
	cli						; disable interrupts so that we can perform surgery on the idt
	push edi
	push edx
	
	and ecx, 0x000000ff		; just to be safe, make sure that ecx is actually just cl which is the interrupt number, otherwise we could run into major issues
	
	lea edi, [interrupt_descriptors + 8 * ecx]	; calculate the location of the interrupt in the table and load it.  
	; generally we'll leave the rest of it unperturbed, we'll simply modify the pointer of the callback and then reload the idt
	
	mov word [edi], dx			; move the low word of the address into the bottom of this structure
	shr edx, 16
	add edi, 6
	mov word [edi], dx			; move the upper word of the address into the last two bytes of this 8 byte object.  
	
	lidt [idt_desc_struct]				; load the struct describing the table, test to see whether this is necessary.  

	pop edx
	pop edi
	
	sti
	ret

section .data
	idt_code_segment		dw		0x0008
	idt_default_flags		db		1_00_0_1110b
	idt_ring3_flags			db		0_11_0_0000b
	cascade_str db "Cascade Received", 0

	idt_desc_struct:				; this is a structure which describes the descriptor table
		dw 0x07ff					; 256 descriptors * 8 bytes = 2048 = 0x0800
								    ; the descriptor size subtracts one for whatever reason
		dd interrupt_descriptors	; this is a pointer to the descriptor table itself
section .bss
	interrupt_descriptors 	resq	256
	