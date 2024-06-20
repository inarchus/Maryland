/*
	
	A DynamicMemory struct is a single allocation of dynamic memory and contains a pointer back to the record struct and another pointer back to the memory.
	
	MemoryRecord structures have the pointer to the memory, the length of the memory and a byte containing flags which currently just have an allocation flag bit.  
	
	MemoryBlock structures are the structures which are linked list nodes containing 64 memory records, two pointers for forward and previous in the linked list, 
		and then start and end addresses which the block is allowed to allocate into.  
		
	The first memory block is going to be called "origin" and there's going to be one of them which is at the root of the dynamic memory block.  
	
*/
#ifndef __MEMORY_H__
#define __MEMORY_H__



void * operator new (unsigned int size_in_bytes);
void * operator new[] (unsigned int size_in_bytes);
void operator delete(void * p_memory) noexcept;
void operator delete [] (void * p_memory) noexcept;

namespace Memory {
	
struct MemoryBlock; 
extern struct MemoryBlock origin;

struct MemoryRecord;

typedef struct DynamicMemory{
	struct MemoryRecord * p_record; 	// this should be a pointer that precedes each dynamic memory block and has 
								// a pointer back to its record in the dynamic memory table
	void * p_memory;			// this is the actual memory itself.  
} DynamicMemory;

typedef struct MemoryRecord {
	void * p_memory; 			 // pointer to the memory location
	unsigned int length;		 // length in bytes of the memory block
	unsigned char flags;		 // bits that have data about the allocated block.  [ - - - - - - - AF] AF = Allocated(1), Free(0)
} MemoryRecord;

typedef struct MemoryBlock {
	struct MemoryRecord memory_records[64]; // 64 memory records per block
	struct MemoryBlock * p_next, * p_prev;  // we'll have a linked list of memory blocks
	void * start_address;
	void * end_address;
} MemoryBlock;

/*
	Here is the declaration of the origin memory block, essentially the base object in the entire allocation structure.  
*/
//MemoryBlock origin;

void * __attribute__((fastcall)) allocate(unsigned int size);
void __attribute__((fastcall)) free(void * p_memory);
void __attribute__((fastcall)) kill(void * p_memory);

} //



#endif