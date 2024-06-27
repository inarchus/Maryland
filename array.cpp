#include "array.h"
#include "memory.h"

template<typename t>
Array<t>::Array(unsigned int default_size)
	: n_capacity(default_size), n_size(0)
{
	p_array = new t[n_capacity];
}

template<typename t>
Array<t>::Array(const Array<t> & rhs)
{
	copy(rhs);
}

template<typename t>
Array<t> & Array<t>::operator = (const Array<t> & rhs)
{
	if(&rhs != this)
	{
		copy(rhs);
	}
	return *this;
}

template<typename t>
void Array<t>::copy(const Array<t> & rhs)
{
	if(p_array)
		delete p_array;
	
	n_size = rhs.n_size;
	n_capacity = rhs.n_capacity;
	
	p_array = new t[n_capacity];
	for(unsigned int i = 0; i < n_size; i++)
	{
		p_array[i] = rhs.p_array[i];
	}
}

template<typename t>
bool Array<t>::operator == (const Array<t> & rhs) const
{
	if (rhs.n_size != n_size)
		return false;
	for(unsigned int i = 0; i < n_size; i++)
	{
		if (p_array[i] != rhs.p_array[i])
			return false;
	}
	return true;
}

template<typename t>
void Array<t>::append(const t & new_item)
{
	if (n_size < n_capacity)
	{
		p_array[n_size++] = new_item;
	}
	else
	{
		t * new_array = new t[2 * n_capacity];
		for(unsigned int i = 0; i < n_size; i++)
		{
			new_array[i] = p_array[i];
		}
		n_size++;
		n_capacity *= 2;
		delete p_array;
		p_array = new_array;
	}
}

template<typename t>
t & Array<t>::operator [] (unsigned int index)
{
	if(index < n_size)
		return p_array[index];
	else
		return error_value;
}

template<typename t>
void Array<t>::set_error_value(const t & err)
{
	error_value = err;
}

template<typename t>
const t & Array<t>::get_error_value() const
{
	return error_value;
}


template<typename t>
inline unsigned int Array<t>::size() const
{
	return n_size;
}

template<typename t>
inline unsigned int Array<t>::capacity() const
{
	return n_capacity;
}

template<typename t>
bool Array<t>::exists(const t & item)
{
	for(unsigned int i = 0; i < n_size; i++)
	{
		if(p_array[i] == t)
			return true;
	}
	return false;
}

template<typename t>
unsigned int Array<t>::find_index(const t & item)
{
	for(unsigned int i = 0; i < n_size; i++)
	{
		if(p_array[i] == t)
			return i;
	}
	return 0xffffffff;
}

template<typename t>
bool Array<t>::remove_element(const t & item)
{
	return false;
}

template<typename t>
Array<t>::~Array()
{
	delete [] p_array;
}
