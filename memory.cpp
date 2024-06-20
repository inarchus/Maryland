/*
	
	A DynamicMemory struct is a single allocation of dynamic memory and contains a pointer back to the record struct and another pointer back to the memory.
	
	MemoryRecord structures have the pointer to the memory, the length of the memory and a byte containing flags which currently just have an allocation flag bit.  
	
	MemoryBlock structures are the structures which are linked list nodes containing 64 memory records, two pointers for forward and previous in the linked list, 
		and then start and end addresses which the block is allowed to allocate into.  
		
	The first memory block is going to be called "origin" and there's going to be one of them which is at the root of the dynamic memory block.  
	
*/

#include "memory.h"

extern "C" void memcpy(void * source, void * destination, unsigned int length);
extern "C" void memset(void * memory, unsigned int size, unsigned char value);

void * p_dynamic_memory_start = (void *)0x400000;		// again, dumbest thing imaginable, we're hard coding the start of the dynamic segment [heap]
void * p_dynamic_memory_current = (void *)0x400000;

void * operator new (unsigned int size_in_bytes)
{
	return Memory::allocate(size_in_bytes);
}

void * operator new[] (unsigned int size_in_bytes)
{
	return Memory::allocate(size_in_bytes);
}

void operator delete(void * p_memory) noexcept
{
	
}

void operator delete [] (void * p_memory) noexcept
{
	
}

namespace Memory 
{
	
void * __attribute__((fastcall)) allocate(unsigned int size)
{
	// this needs to be rewritten entirely once we get around to actually caring about allocating memory and freeing it properly.  
	// search through the blocks to find memory of a particular size in unallocated space.  
	void * current_location = (void *)p_dynamic_memory_current;
	p_dynamic_memory_current = (void *)(((char *)p_dynamic_memory_current) + size);
	//((unsigned int)p_dynamic_memory_current) += size;		
	// return the previous location because that's what the address was before we added the size in bytes. 
	return current_location;
}

/*
	This function will find the memory in the allocated block and set its allocated flag to 0 meaning that it can be reused.  
	
	CURRENTLY WE DO NOT FREE MEMORY
*/
void __attribute__((fastcall)) free(void * p_memory)
{
	/*DynamicMemory * p_dynamic = (void * )(p_memory - sizeof(void *));
	p_dynamic->p_record->flags &= ~0x01;
	return 1;
	*/
	// do nothing, we're dumb
}

// dont' use this, it's going to break
// CURRENTLY WE DO NOT FREE MEMORY
void __attribute__((fastcall)) kill(void * p_memory)
{
	DynamicMemory * p_dynamic = (DynamicMemory * )((char *)p_memory - sizeof(void *));
	p_dynamic->p_record->flags &= ~0x01;
	memset(p_memory, 0, p_dynamic->p_record->length);
}

}