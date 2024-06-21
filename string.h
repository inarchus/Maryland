#ifndef __STRING_H__
#define __STRING_H__

#include "memory.h"

class String
{
	public:
		String();
		String(const char * const p_string);
		String(const String & copy_string);
		
		String & concatenate(const String & rhs);
		bool equals(const String & rhs) const;
		bool startswith(const String & rhs) const;
		String & upper();
		String & lower();
		// array<String> & split(); needs array to be implemented
		inline unsigned int length() const;
		String & operator = (const String & rhs);
		bool operator == (const String & rhs) const;
		String operator + (const String & rhs);
		String & operator += (const String & rhs);
		
		~String();
	private:
		unsigned int calculate_length(const char * const p_chars) const;
		void char_pointer_copy(const char * const p_chars);
	
		unsigned int n_length;
		char * p_char_string;
};

#endif