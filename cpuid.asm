;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			cpuid.asm																							;;;;
;;;;																																								;;;;
;;;;		Provide functionality allowing for cpuid instruction to be displayed as sensible output.  																;;;;
;;;;			Source for my information https://osdev.org/CPUID																				Eric Hamilton		;;;;
;;;;																																			9 June 2024	  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extern printstrf
extern display_cpuid

section .text


display_cpuid:
	
	mov eax, 1
	cpuid 

	push ebx
	push ecx
	
	mov ebx, edx
	mov esi, CPUID_FEAT_EDX
	mov edx, 0x0200
	call display_cpuid_loop_auxiliary
	
	pop ecx
	mov ebx, ecx
	mov esi, CPUID_FEAT_ECX
	mov edx, 0x0400
	call display_cpuid_loop_auxiliary
	
	pop ebx
	
	ret
	
display_cpuid_loop_auxiliary:
	mov ecx, 32	
	display_cpuid_loop:
		test ebx, 1
		mov al, 0x0a
		jnz skip_set_red
		mov al, 0x0c
		skip_set_red:
		
		call printstrf
		
		shr ebx, 1
		add esi, 5 				; length of all of the fixed size strings in the array.
		add edx, 5
		dec ecx	
	jnz display_cpuid_loop
	ret

section .data		
	CPUID_FEAT_ECX:
	CPUID_FEAT_ECX_SSE3         db 'SSE3', 0
    CPUID_FEAT_ECX_PCLMUL       db 'PCLM', 0
    CPUID_FEAT_ECX_DTES64       db 'DTES', 0
    CPUID_FEAT_ECX_MONITOR      db 'MONT', 0
    CPUID_FEAT_ECX_DS_CPL       db 'DSCP', 0
    CPUID_FEAT_ECX_VMX          db 'VMX ', 0
    CPUID_FEAT_ECX_SMX          db 'SMX ', 0
    CPUID_FEAT_ECX_EST          db 'EST ', 0
    CPUID_FEAT_ECX_TM2          db 'TM2 ', 0
    CPUID_FEAT_ECX_SSSE3        db 'SSSE', 0
    CPUID_FEAT_ECX_CID          db 'CID ', 0
    CPUID_FEAT_ECX_SDBG         db 'SDBG', 0
    CPUID_FEAT_ECX_FMA          db 'FMA ', 0
    CPUID_FEAT_ECX_CX16         db 'CX16', 0
    CPUID_FEAT_ECX_XTPR         db 'XTPR', 0
    CPUID_FEAT_ECX_PDCM         db 'PDCM', 0
	CPUID_FEAT_ECX_NONE         db '    ', 0		; spacer because there's no feature for bit 16
    CPUID_FEAT_ECX_PCID         db 'PCID', 0
    CPUID_FEAT_ECX_DCA          db 'DCA ', 0
    CPUID_FEAT_ECX_SSE4_1       db 'SE41', 0
    CPUID_FEAT_ECX_SSE4_2       db 'SE42', 0
    CPUID_FEAT_ECX_X2APIC       db 'X2AP', 0
    CPUID_FEAT_ECX_MOVBE        db 'MOVB', 0
    CPUID_FEAT_ECX_POPCNT       db 'POPC', 0
    CPUID_FEAT_ECX_TSC          db 'TSC ', 0
    CPUID_FEAT_ECX_AES          db 'AES ', 0
    CPUID_FEAT_ECX_XSAVE        db 'XSAV', 0
    CPUID_FEAT_ECX_OSXSAVE      db 'OSXS', 0
    CPUID_FEAT_ECX_AVX          db 'AVX ', 0
    CPUID_FEAT_ECX_F16C         db 'F16C', 0
    CPUID_FEAT_ECX_RDRAND       db 'RDRN', 0
    CPUID_FEAT_ECX_HYPERVISOR   db 'HYPV', 0
 
	CPUID_FEAT_EDX:
    CPUID_FEAT_EDX_FPU          db 'FPU ', 0
    CPUID_FEAT_EDX_VME          db 'VME ', 0
    CPUID_FEAT_EDX_DE           db 'DE  ', 0
    CPUID_FEAT_EDX_PSE          db 'PSE ', 0
    CPUID_FEAT_EDX_TSC          db 'TSC ', 0
    CPUID_FEAT_EDX_MSR          db 'MSR ', 0
    CPUID_FEAT_EDX_PAE          db 'PAE ', 0
    CPUID_FEAT_EDX_MCE          db 'MCE ', 0
    CPUID_FEAT_EDX_CX8          db 'CX8 ', 0  
    CPUID_FEAT_EDX_APIC         db 'APIC', 0 
    CPUID_FEAT_EDX_NONE1        db '    ', 0		; spacer because there's no feature for bit 10
	CPUID_FEAT_EDX_SEP          db 'SEP ', 0
    CPUID_FEAT_EDX_MTRR         db 'MTRR', 0
    CPUID_FEAT_EDX_PGE          db 'PGE ', 0
    CPUID_FEAT_EDX_MCA          db 'MCA ', 0
    CPUID_FEAT_EDX_CMOV         db 'CMOV', 0
    CPUID_FEAT_EDX_PAT          db 'PAT ', 0
    CPUID_FEAT_EDX_PSE36        db 'PS36', 0
    CPUID_FEAT_EDX_PSN          db 'PSN ', 0
    CPUID_FEAT_EDX_CLFLUSH      db 'CLFL', 0
	CPUID_FEAT_EDX_NONE2        db '    ', 0		; same for bit 20 as 10.
    CPUID_FEAT_EDX_DS           db 'DS  ', 0
    CPUID_FEAT_EDX_ACPI         db 'ACPI', 0
    CPUID_FEAT_EDX_MMX          db 'MMX ', 0
    CPUID_FEAT_EDX_FXSR         db 'FXSR', 0
    CPUID_FEAT_EDX_SSE          db 'SSE ', 0
    CPUID_FEAT_EDX_SSE2         db 'SSE2', 0
    CPUID_FEAT_EDX_SS           db 'SS  ', 0
    CPUID_FEAT_EDX_HTT          db 'HTT ', 0 
    CPUID_FEAT_EDX_TM           db 'TM  ', 0
    CPUID_FEAT_EDX_IA64         db 'IA64', 0
    CPUID_FEAT_EDX_PBE          db 'PBE ', 0
