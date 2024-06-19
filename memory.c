/*
	
	A DynamicMemory struct is a single allocation of dynamic memory and contains a pointer back to the record struct and another pointer back to the memory.
	
	MemoryRecord structures have the pointer to the memory, the length of the memory and a byte containing flags which currently just have an allocation flag bit.  
	
	MemoryBlock structures are the structures which are linked list nodes containing 64 memory records, two pointers for forward and previous in the linked list, 
		and then start and end addresses which the block is allowed to allocate into.  
		
	The first memory block is going to be called "origin" and there's going to be one of them which is at the root of the dynamic memory block.  
	
*/
//namespace Memory {
	
struct MemoryBlock; 
extern struct MemoryBlock origin;
extern void memcopy(void * source, void * destination, unsigned int length);
extern void memset(void * memory, unsigned int size, unsigned char value);


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
MemoryBlock origin;


void * allocate(unsigned int size)
{
	// this is going to be a hard one probably
	// search through the blocks to find memory of a particular size in unallocated space.  
	return 0;
}

/*
	This function will find the memory in the allocated block and set its allocated flag to 0 meaning that it can be reused.  
*/
unsigned char free(void * p_memory)
{
	DynamicMemory * p_dynamic = (void * )(p_memory - sizeof(void *));
	p_dynamic->p_record->flags &= ~0x01;
	return 1;
}

unsigned char kill(void * p_memory)
{
	DynamicMemory * p_dynamic = (void * )(p_memory - sizeof(void *));
	p_dynamic->p_record->flags &= ~0x01;
	memset(p_memory, 0, p_dynamic->p_record->length);
	return 1;	
}

//}