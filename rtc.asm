
; https://osdev.org/RTC
;


RTC_CMOS_PORT_A		equ 	0x70
RTC_CMOS_PORT_B		equ 	0x71

RTC_SECONDS_REG		equ		0x00
RTC_MINUTES_REG		equ		0x02
RTC_HOURS_REG		equ 	0x04

RTC_DAY_OF_WEEK		equ		0x06
RTC_DAY_OF_MONTH	equ 	0x07
RTC_MONTH			equ		0x08
RTC_YEAR			equ		0x09
RTC_CENTURY			equ		0x32


extern printstrf
extern display_hex_byte
extern print_hex_byte
extern print_hex_dword

; from interrupts.asm
extern set_interrupt_callback

extern cmos_dump_registers
extern cmos_get_register

extern rtc_enable
extern rtc_display_datetime
extern rtc_get_tick				; returns a pointer to the low dword...
;extern rtc_display_byte
extern rtc_toggle_display

section .text

rtc_enable:
	cli									; double check that interrupts are disabled
	
	mov ecx, 0x28						; set interrupt 0x20 + 0x8
	mov edx, rtc_interrupt_irq8
	call set_interrupt_callback
	
	push edx
	push eax
	
	mov dx, RTC_CMOS_PORT_A
	mov al, 0x8b						; select status register B + disable NMI = 0x80
	out dx, al
	
	inc dx	; port 0x71
	in al, dx
	
	push eax
	
	dec dx ; port 0x70
	mov al, 0x8b
	out dx, al
	
	inc dx ; port 0x71
	pop eax
	or al, 0x40							; enable the IRQ8
	out dx, al					
	
	pop eax
	pop edx
	
	mov dword [rtc_time], 0
	mov dword [rtc_time + 4], 0

	ret



rtc_get_tick:
	;; returns the location of the low dword of the tick, but the next dword is the high word too, so this can be used for both purposes.  
	mov eax, rtc_current_tick_low
	ret
	
rtc_display_datetime:
	; let cx have the position
	push edx
	push ecx
	push eax
	
	mov dx, cx
	
	call rtc_get_date_time	; eax contains a pointer to the data.  
	mov esi, eax
	
	mov cx, 8
	rtc_display_datetime_loop:
		push ecx
		mov cl, [eax]
		call print_hex_byte ; should fix this to preserve eax...
		add dx, 3
		inc eax
		pop ecx
		dec cx
	jnz rtc_display_datetime_loop
	
	pop eax
	pop ecx
	pop edx
	ret

rtc_get_date_time:	; returns a pointer to the rtc_time data in eax
	push esi
	push edi
	push ecx
	push edx
	
	mov esi, port_order
	mov edi, rtc_time

	mov cx, 8
	
	mov dx, 0x1330
	
	rtc_get_date_time_loop:
		lodsb
		or al, 0x80				; disable NMI
		out RTC_CMOS_PORT_A, al
		in al, RTC_CMOS_PORT_B
		stosb
		dec cx
	jnz rtc_get_date_time_loop

	pop edx
	pop ecx
	pop edi
	pop esi
	
	mov eax, rtc_time		; load a pointer to the data and return it
	
	ret

cmos_get_register:
	;; fastcall passes through ecx, all we need is the register number in cl, return in al
	xor eax, eax
	mov al, cl
	or al, 0x80						; disable NMI for safety
	cli								; for safety since apparently a partial read can result in corruption
	out RTC_CMOS_PORT_A, al			; be quick about it
	in al, RTC_CMOS_PORT_B			; there we go
	sti								; re-enable interrupts
	ret
	
cmos_dump_registers:
	;; fastcall passes through ecx and edx
	;; ecx = size to read (if we know the amount of values, also the size in memory allocated
	;; edx = pointer to a memory block to read into.  
	push ecx
	push edi
	mov edi, edx
	xor eax, eax
	
	cmos_dump_registers_loop:
		push eax
		or al, 0x80				; disable NMI
		out RTC_CMOS_PORT_A, al
		in al, RTC_CMOS_PORT_B
		stosb
		pop eax
		inc eax
		dec cx
	jnz cmos_dump_registers_loop
	
	pop edi
	pop ecx
	
	ret


;; this is the interrupt that runs whenever the RTC signals a clock pulse.
rtc_interrupt_irq8:
	push eax
	push ebx
	push edx

	test byte [rtc_display_byte], 1
	jz .bypass_display

	cmp dword [rtc_current_tick_low], 0xffffffff
	jne .bypass_increment_high_word
	
	inc dword [rtc_current_tick_high]
	mov dword [rtc_current_tick_low], 0xffffffff
	
	.bypass_increment_high_word:
	inc dword [rtc_current_tick_low]	
	
	mov ebx, [rtc_current_tick_low]
	and ebx, 0x000001ff
	jnz .bypass_display
	
	push ecx
	
	mov cx, 0x1828
	call rtc_display_datetime
	pop ecx	
	
	.bypass_display:
	
	mov al, 0x20		; EOI = end of interrupt
	out 0xa0, al		; send to the slave pic
	out 0x20, al		; send to the master

	mov al, 0x0c		; must read the C register or else it won't call again
	mov dx, 0x70		; cannot just set the interrupt as cleared
	out dx, al			; do this and then it'll run again! who knew!
	inc dx
	in al, dx			

	
	pop edx
	pop ebx
	pop eax
	iretd

rtc_toggle_display:
	inc byte [rtc_display_byte]
	and byte [rtc_display_byte], 0xfd
	ret

section .data
	rtc_display_byte db 1
	rtc_rate	db		0000_0110b
	port_order 	db		0x32, 0x09, 0x08, 0x07, 0x06, 0x04, 0x02, 0x00
section .bss
	rtc_current_tick_low	resd 	1
	rtc_current_tick_high	resd 	1		; can represent 571 million years of time given the 
	rtc_time				resb	8