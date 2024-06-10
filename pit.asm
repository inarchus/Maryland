;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			pit.asm																							    ;;;;
;;;;																																								;;;;
;;;;		The goal is to provide a driver for the programmable interval timer (PIT)				  																;;;;
;;;;																																			Eric Hamilton		;;;;
;;;;																																			5/27/2024	  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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
extern configure_pit
extern pit_interrupt_irq0
extern print_hex_word

section .text

configure_pit:
	push ebp
	mov ebp, esp

	; mov eax, [ebp - 12] ; the argument for the configuration is contained in al
	
	mov dx, 0x43
	mov al, PIT_16BITS | PIT_OP_MODE_3 | PIT_ACCESS_LOW | PIT_ACCESS_HIGH | PIT_CHANNEL_0
	;cli 
	out dx, al
	
	; specify the reload value, let's try for the slowest possible tick at first... low and then high byte
	mov dx, 0x40
	mov al, 0xff
	out dx, al
	mov al, 0xff
	out dx, al
	
	;sti
	
	leave
	ret
	

read_pit:
	mov dx, 0x43
	mov al, 11000010b
	cli 
	out dx, al
	
	xor eax, eax 	; set to zero because we're going to be filling ax with bits, don't want to let the high word get involved
	mov dx, 0x40
	in al, dx		; input the low byte
	xchg al, ah		; exchange ah and al so that we can input into al again (cannot do directly into ah)
	in al, dx 		; input into al, but now the bytes are flipped
	xchg al, ah		; flip them back.  

	mov [current_tick], ax
	
	ret


pit_interrupt_irq0:
	cli
	push eax
	push edx
	
	mov dx, 0x43
	mov al, 11000010b
	out dx, al
	
	xor eax, eax 	; set to zero because we're going to be filling ax with bits, don't want to let the high word get involved
	mov dx, 0x40
	in al, dx		; input the low byte
	xchg al, ah		; exchange ah and al so that we can input into al again (cannot do directly into ah)
	in al, dx 		; input into al, but now the bytes are flipped
	xchg al, ah		; flip them back.  

	inc dword [current_tick]
	; mov ax, [current_tick]
	mov dx, 0x1735
	call print_hex_word

	mov ax, [current_tick + 2]
	mov dx, 0x1730
	call print_hex_word

	pop edx	
	pop eax
	
	sti
	iret
	
section .data
	current_tick dd 0