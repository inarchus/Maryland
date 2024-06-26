/*
	
	A DynamicMemory struct is a single allocation of dynamic memory and contains a pointer back to the record struct and another pointer back to the memory.
	
	MemoryRecord structures have the pointer to the memory, the length of the memory and a byte containing flags which currently just have an allocation flag bit.  
	
	MemoryBlock structures are the structures which are linked list nodes containing 64 memory records, two pointers for forward and previous in the linked list, 
		and then start and end addresses which the block is allowed to allocate into.  
		
	The first memory block is going to be called "origin" and there's going to be one of them which is at the root of the dynamic memory block.  
	
*/

#include "memory.h"


extern "C" void memory_copy(void * source, void * destination, unsigned int length);
extern "C" void memory_set(void * memory, unsigned int size, unsigned long value);

void * operator new (std::size_t size_in_bytes)
{
	return Memory::allocate(size_in_bytes);
}

void * operator new[] (std::size_t size_in_bytes)
{
	return Memory::allocate(size_in_bytes);
}

void operator delete(void * p_memory) noexcept
{
	Memory::free(p_memory);
}

void operator delete [] (void * p_memory) noexcept
{
	Memory::free(p_memory);
}



namespace Memory 
{
/*

typedef struct MemoryRecord {
	void * p_memory; 			 // pointer to the memory location, do we include the back pointer?... 
	unsigned int length;		 // length in bytes of the memory block
	unsigned char flags;		 // bits that have data about the allocated block.  [ - - - - - - - AF] AF = Allocated(1), Free(0)
} MemoryRecord;

typedef struct MemoryBlock {
	struct MemoryRecord memory_records[64]; // 64 memory records per block
	struct MemoryBlock * p_next, * p_prev;  // we'll have a linked list of memory blocks
	void * start_address;
	void * end_address;
	qword allocated;						// one bit for each record.  
} MemoryBlock;

*/
// leave the top bit 0 because that will be allocated as the next MemoryBlock.
#define ALL_BITS_63 0x7FFFFFFFFFFFFFFFULL
#define MEMORY_ALLOCATED 0x01

byte * p_dynamic_memory_start = (byte *)0x400000;		// again, dumbest thing imaginable, we're hard coding the start of the dynamic segment [heap]
byte * p_dynamic_memory_current = (byte *)0x400000;
byte * p_dynamic_memory_maximum = (byte *)0x800000;		// for now i'll give dynamic memory 4 MB, we're nowhere close to that yet.  

void * allocate(std::size_t size)
{
	MemoryBlock * p_current = &origin;
	bool allocated = false;
	
	qword allocated_bit;
	
	while (p_current && !allocated)
	{
		allocated_bit = 1;
		if((p_current->allocated & ALL_BITS_63) != ALL_BITS_63)
		{
			for(int i = 0; i < 63; i++)
			{
				if(p_current->memory_records[i].flags & MEMORY_ALLOCATED)
				{
					continue;
				}
				else if (p_current->memory_records[i].length >= size)
				{
					// reuse an old memory block
					p_current->allocated |= allocated_bit;
					p_current->memory_records[i].flags |= MEMORY_ALLOCATED;
					// give any excess memory to the next record, if it's not allocated
					if(i + 1 < 63 && !(p_current->allocated & (allocated_bit << 1)) && p_current->memory_records[i].length > size)
					{
						p_current->memory_records[i + 1].p_dynamic -= (p_current->memory_records[i].length - size);
						p_current->memory_records[i + 1].p_dynamic->p_record = &(p_current->memory_records[i + 1]);
						p_current->memory_records[i + 1].length += (p_current->memory_records[i].length - size);
						p_current->memory_records[i].length = size;
						p_current->memory_records[i].p_dynamic->p_record = &(p_current->memory_records[i]);
					}
					// we have to return the actual memory back to the user rather than the pointer to the memory block itself.  
					return p_current->memory_records[i].p_dynamic->p_memory;
				}
				else if (p_current->memory_records[i].length == 0) // zero means that the length is not determined yet.  
				{
					if(p_dynamic_memory_current + size >= p_dynamic_memory_maximum)
					{
						return nullptr;
					}
					else
					{
						// allocate a new block at the end of the currently allocated MemoryBlock
						p_current->memory_records[i].length = size;
						p_current->memory_records[i].p_dynamic = (DynamicMemory *)p_dynamic_memory_current;
						p_current->memory_records[i].p_dynamic->p_record = &(p_current->memory_records[i]);
						p_current->memory_records[i].flags |= MEMORY_ALLOCATED;
						p_dynamic_memory_current += (size + sizeof(MemoryRecord *));
						
						return p_current->memory_records[i].p_dynamic->p_memory;
					}
				}
				allocated_bit <<= 1;
			}
		}
		
		if(!p_current->p_next)
		{
			// allocate the space to this new block.  
			p_dynamic_memory_current += sizeof(MemoryBlock);
			p_current->allocated |= 0x1000000000000000;
			p_current->memory_records[63].flags |= MEMORY_ALLOCATED;
			p_current->memory_records[63].length = sizeof(MemoryBlock);
			p_current->p_next = (MemoryBlock*)p_dynamic_memory_current;
		}
		
		p_current = p_current->p_next;
	}
	return nullptr;
}

/*
	This function will find the memory in the allocated block and set its allocated flag to 0 meaning that it can be reused.  
*/
void free(void * p_memory) 
{
	DynamicMemory * p_dynamic = (DynamicMemory *)((byte *)p_memory - sizeof(void *));
	p_dynamic->p_record->flags &= ~0x01;
}

void kill(void * p_memory)
{
	DynamicMemory * p_dynamic = (DynamicMemory *)((byte *)p_memory - sizeof(void *));
	p_dynamic->p_record->flags &= ~0x01;
	memory_set(p_memory, 0, p_dynamic->p_record->length);
}

}