#ifndef __ARRAY_H__
#define __ARRAY_H__

template<typename t>
class Array
{
	public:
		Array(unsigned int default_size = 10);
		Array(const Array<t> & rhs);
		
		Array<t> & operator = (const Array<t> & rhs);
		bool operator == (const Array<t> & rhs) const;
		void append(const t & new_item);
		t & operator [] (unsigned int index);
		
		inline unsigned int size() const;
		inline unsigned int capacity() const;
		
		bool exists(const t & item);
		unsigned int find_index(const t & item);
		bool remove_element(const t & item);
		
		void set_error_value(const t & err);
		const t & get_error_value() const;
		
		~Array();
	private:
		void copy(const Array<t> & rhs);
		t * p_array;
		unsigned int n_size;		// size of the Array object, number of elements inserted
		unsigned int n_capacity;	// total capacity of the actual p_array, rather than just the number currently filled.
		t error_value;
};

#include "array.cpp"

#endif