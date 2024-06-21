;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;							                    			Memory.asm																							;;;;
;;;;																																								;;;;
;;;;		The goal is to provide allocate and free functions, the equivalent of malloc and free.  																;;;;
;;;;			Perhaps also provide some memory services like memset and memcopy.																Eric Hamilton		;;;;
;;;;																																			5/27/2024	  		;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;	Problem: we need to keep track of the dynamically allocated memory, a pointer to it, its length.  
;;;;
;;;;	Expressed in C-notation
;;;;	struct DynamicMemory {
;;;;		MemoryRecord * p_record; 	// this should be a pointer that precedes each dynamic memory block and has 
;;;;									// a pointer back to its record in the dynamic memory table
;;;;		void * p_memory;			// this is the actual memory itself.  
;;;;	};
;;;;
;;;;	struct MemoryRecord {
;;;;		void * p_memory; // pointer to the memory location
;;;;		int length;		 // length in bytes of the memory block
;;;;		char flags;		 // bits that have data about the allocated block.  [ - - - - - - - AF] AF = Allocated(1), Free(0)
;;;;	};
;;;;
;;;;	struct MemoryBlock {
;;;;		MemoryRecord memory_records[64]; // 64 memory records per block
;;;;		MemoryBlock * p_next, * p_prev;
;;;;		void * start_address;
;;;;		void * end_address;
;;;;	}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
extern memory_set
extern memory_copy

section .text


memory_set:
	; pointer to mem
	; value to set
	; size of mem
	push ebp
	mov ebp, esp
	push edi
	push ecx
	push eax
	
	mov edi, [ebp + 12]		;	destination
	mov al, [ebp + 8]		;	value, needs to be a single byte
	mov ecx, [ebp + 4]		;	size to set
	
	mov ah, al				; make four copies of al eax = [al, al, al, al]
	shl eax, 8
	mov al, ah
	shl eax, 8
	mov al, ah
	
	shr ecx, 2 				; divide by 4 so that we don't copy byte by byte
	memset_loop:
		stosd
	loop memset_loop
	
	mov ecx, [ebp + 4]
	and ecx, 3				; get the remainder when divided by 4 and execute that many more times.  
	memset_byte_loop:
		stosb
	loop memset_byte_loop
	
	pop eax
	pop ecx
	pop edi
	
	leave
	ret
	
memory_copy:
	;; assuming for now non-overlapping memory segments
	push ebp
	mov ebp, esp
	push esi
	push edi
	push ecx
	push eax
	
	mov esi, [ebp + 12]		;	source
	mov edi, [ebp + 8]		;	destination
	mov ecx, [ebp + 4]		;	size to copy
	
	shr ecx, 2 				; divide by 4 so that we don't copy byte by byte
	memcopy_loop:
		lodsd
		stosd
	loop memcopy_loop
	
	mov ecx, [ebp + 4]
	and ecx, 3				; get the remainder when divided by 4 and execute that many more times.  
	memcopy_byte_loop:
		lodsb
		stosb
	loop memcopy_byte_loop
	
	pop eax
	pop ecx
	pop edi
	pop esi
	
	leave
	ret

; hard coded for now, we can adjust this based on the size of the ram.  
section .data
	base_address	dd	0x0020_0000 	; start the heap at 2MB
	max_address		dd	0x0030_0000		; end the heap at 3MB
section .bss
