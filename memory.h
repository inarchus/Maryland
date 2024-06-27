/*
	
	A DynamicMemory struct is a single allocation of dynamic memory and contains a pointer back to the record struct and another pointer back to the memory.
	
	MemoryRecord structures have the pointer to the memory, the length of the memory and a byte containing flags which currently just have an allocation flag bit.  
	
	MemoryBlock structures are the structures which are linked list nodes containing 64 memory records, two pointers for forward and previous in the linked list, 
		and then start and end addresses which the block is allowed to allocate into.  
		
	The first memory block is going to be called "origin" and there's going to be one of them which is at the root of the dynamic memory block.  
	
*/
#ifndef __MEMORY_H__
#define __MEMORY_H__
namespace std { 
	/*
		You may wonder why we're doing something strange like this, rather than using unsigned int or unsigned long or unsigned long long.  
		As it turns out if you replace typeof(sizeof(0)) with uint it will say that it wants a ulong, and vice versa.  I could not get
		the errors to resolve themselves unless I used this specific magic, admittedly it is ugly and unsatisfying.  It is important that
		we standardize the sizes eventually, i.e. short = 2 bytes, int = 4 bytes, long = 8 bytes, but the int vs long vs long long vagueness
		is a problem here.  
	*/

	typedef typeof(sizeof(0)) size_t; 

}

extern "C" {
	void run_memory_test();
}

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int dword;
// have to decide if the lp64 argument worked then we can change this to simple long. 
typedef unsigned long long qword;


/*
	Because we are the operating system we must define these keywords as they have no ability to function otherwise.  
*/

void * operator new (std::size_t size_in_bytes);
void * operator new[] (std::size_t size_in_bytes);

void operator delete(void * p_memory) noexcept;
void operator delete [] (void * p_memory) noexcept;


namespace Memory {
	
struct MemoryBlock; 
struct MemoryRecord;

typedef struct DynamicMemory{
	struct MemoryRecord * p_record; 	// this should be a pointer that precedes each dynamic memory block and has 
										// a pointer back to its record in the dynamic memory table
	void * p_memory;					// this is the actual memory itself.  
} DynamicMemory;

typedef struct MemoryRecord {
	DynamicMemory * p_dynamic; 		// pointer to the memory location
	std::size_t length;		 		// length in bytes of the memory block
	byte flags;		 				// bits that have data about the allocated block.  [ - - - - - - - AF] AF = Allocated(1), Free(0)
} MemoryRecord;

typedef struct MemoryBlock {
	struct MemoryRecord memory_records[64]; // 64 memory records per block
	struct MemoryBlock * p_next, * p_prev;  // we'll have a linked list of memory blocks
	void * start_address;
	void * end_address;
	// qword allocated;						// one bit for each record.  
} MemoryBlock;

extern "C" void initialize_block(MemoryBlock * p_block, MemoryBlock * p_prev);
extern "C" void initialize_origin();

void initialize_origin();
void initialize_block(MemoryBlock * p_block, MemoryBlock * p_prev);

void * allocate(std::size_t size);
void free(void * p_memory);
void kill(void * p_memory);

}

#endif