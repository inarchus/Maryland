;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			pit.asm																	    ;;;;
;;;;																																		;;;;
;;;;		The goal is to provide a driver for the programmable interval timer (PIT)				  										;;;;
;;;;																													Eric Hamilton		;;;;
;;;;																													CR: 5/27/2024  		;;;;
;;;;						Next Step: Allow changing the time and determine precise timings using this feature.							;;;;
;;;;																																 		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


PIT_CHANNEL_0 		equ		0x00
PIT_CHANNEL_1 		equ		0x40
PIT_CHANNEL_2 		equ		0x80
PIT_READ_BACK 		equ		0xC0

PIT_ACCESS_LOW		equ		0x10
PIT_ACCESS_HIGH		equ		0x20

PIT_OP_MODE_2		equ		0x04
PIT_OP_MODE_3		equ		0x06

PIT_16BITS			equ 	0x00
PIT_4BITBCD			equ 	0x01

extern read_pit
extern configure_pit				; void __fastcall configure_pit(int reload_value)
extern pit_interrupt_irq0
extern print_hex_word
extern print_hex_dword
extern pit_interrupt_table_entry

extern set_interrupt_callback

section .text

pit_interrupt_irq0:
	push eax
	push edx
	push esi
	
	inc dword [current_tick]
	mov dx, 0x1840
	push ecx
	mov ecx, [current_tick]
	call print_hex_dword
	pop ecx
	
	; end of interrupt
	mov al, 0x20
	out 0x20, al

	pop esi
	pop edx	
	pop eax
	
	iretd

; void __fastcall configure_pit(int reload_value)
configure_pit:
	push edx
	push eax

	mov dx, 0x43
	mov al, PIT_16BITS | PIT_OP_MODE_3 | PIT_ACCESS_LOW | PIT_ACCESS_HIGH | PIT_CHANNEL_0
	cli 
	out dx, al
	;           time in ms = reload_value * 3000 / 3579545 (from osdev)... 
	; specify the reload value, let's try for the slowest possible tick at first... low and then high byte
	mov dx, 0x40
	mov al, cl		;  this is the timing low word
	out dx, al
	mov al, ch		; this is the timing high word
	out dx, al
	
	mov al, 0
	out dx, al
	out dx, al
	
	push ecx
	mov ecx, 0x20				; set ecx to 0 because this is the 0th PIC interrupt
	mov edx, pit_interrupt_irq0
	call set_interrupt_callback
	
	sti		; as long as we mask the pit IRQ, this doesn't blow everything up.  
	pop ecx
	pop eax
	pop edx
	ret
	

read_pit:
	cli 
	mov dx, 0x43
	mov al, 0
	out dx, al
	
	xor eax, eax 	; set to zero because we're going to be filling ax with bits, don't want to let the high word get involved
	mov dx, 0x40
	in al, dx		; input the low byte
	xchg al, ah		; exchange ah and al so that we can input into al again (cannot do directly into ah)
	in al, dx 		; input into al, but now the bytes are flipped
	xchg al, ah		; flip them back.  

	mov [current_tick], eax
	sti	
	ret



section .data
	current_tick dd 0