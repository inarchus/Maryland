#ifndef __STRING_H__
#define __STRING_H__

#include "memory.h"
#include "array.h"

class String
{
	public:
		String();
		String(const char * const p_string);
		String(const String & copy_string);
		
		String & Concatenate(const String & rhs);
		bool Equals(const String & rhs) const;
		bool Startswith(const String & rhs) const;
		String & Upper();
		String & Lower();
		Array<String> Split(char split_on = '\0') const; 
		String Substring(int start_index, int end_index) const;
		inline unsigned int Length() const { return n_length; }
		String & operator = (const String & rhs);
		bool operator == (const String & rhs) const;
		String operator + (const String & rhs);
		String & operator += (const String & rhs);
		char & operator [] (int index) const;
		bool IsWhitespace(char x) const;
		inline char * GetCString() { return p_char_string; }
		~String();
	private:
		unsigned int calculate_length(const char * const p_chars) const;
		void char_pointer_copy(const char * const p_chars);
	
		unsigned int n_length;
		char * p_char_string;
};

#endif