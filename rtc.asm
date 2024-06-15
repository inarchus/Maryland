
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


extern rtc_enable
extern printstrf
extern print_hex_byte
extern display_hex_byte
extern rtc_display_datetime
extern rtc_get_tick				; returns a pointer to the low dword...
extern rtc_display_byte
extern rtc_toggle_display

section .text

rtc_enable:
	cli
	push edx
	push eax
	
	mov dx, RTC_CMOS_PORT_A
	mov al, 0x8b				; select status register B + disable NMI = 0x80
	out dx, al
	
	inc dx
	in al, dx
	
	push eax
	
	dec dx
	mov al, 0x8b
	out dx, al
	
	inc dx
	pop eax
	or al, 0x40					; enable the IRQ8
	out dx, al					
	
	pop eax
	pop edx
	
	mov dword [rtc_time], 0
	mov dword [rtc_time + 4], 0
	
	sti
	ret



rtc_get_tick:
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

; rtc_display_byte

rtc_toggle_display:
	inc byte [rtc_display_byte]
	and byte [rtc_display_byte], 0xfd
	ret

section .data
	rtc_rate	db		0000_0110b
	port_order 	db		0x32, 0x09, 0x08, 0x07, 0x06, 0x04, 0x02, 0x00
section .bss
	rtc_current_tick_low	resd 	1
	rtc_current_tick_high	resd 	1		; can represent 571 million years of time given the 
	rtc_time				resb	8