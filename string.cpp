#include "string.h"
#include "memory.h"


String::String()
	: n_length(0), p_char_string(nullptr)
{
	
}

String::String(const char * const p_chars)
{
	char_pointer_copy(p_chars);
}

String::String(const String & copy_string)
{
	char_pointer_copy(copy_string.p_char_string);
}

String::~String()
{
	delete p_char_string;
}

String & String::concatenate(const String & rhs)
{
	char * new_string = new char[n_length + rhs.n_length + 1];
	
	for(unsigned int i = 0; i < n_length; i++)
	{
		new_string[i] = p_char_string[i];
	}
	for(unsigned int j = n_length; j < n_length + rhs.n_length + 1; j++)
	{
		new_string[j] = rhs.p_char_string[j - n_length];
	}
	new_string[n_length + rhs.n_length] = 0; // null terminate
	
	delete p_char_string;
	p_char_string = new_string;
	n_length += rhs.n_length;
	
	return *this;
}
bool String::equals(const String & rhs) const
{
	if (n_length != rhs.n_length)
		return false;
	
	for(unsigned int i = 0; i < n_length; i++)
	{
		if (p_char_string[i] != rhs.p_char_string[i])
			return false;
	}
	return true;
}
bool String::startswith(const String & rhs) const
{
	if(n_length < rhs.n_length)
		return false;
	
	for(unsigned int i = 0; i < rhs.n_length; i++)
	{
		if (rhs.p_char_string[i] != p_char_string[i])
			return false;
	}
	return true;
}
String & String::upper()
{
	for(unsigned int i = 0; i < n_length; i++)
	{
		if ('a' <= p_char_string[i] && p_char_string[i] <= 'z')
		{
			p_char_string[i] -= 0x20;
		}
	}
	return *this;
}
String & String::lower()
{
	for(unsigned int i = 0; i < n_length; i++)
	{
		if ('A' <= p_char_string[i] && p_char_string[i] <= 'Z')
		{
			p_char_string[i] += 0x20;
		}
	}	
	return *this;
}

inline unsigned int String::length() const
{
	return n_length;
}

String & String::operator = (const String & rhs)
{
	if (this != &rhs)
	{
		char_pointer_copy(rhs.p_char_string);
	}
	return *this;
}
bool String::operator == (const String & rhs) const
{
	return equals(rhs);
}
String String::operator + (const String & rhs)
{
	//String new_string(*this);
	concatenate(rhs);
	return *this;
}
String & String::operator += (const String & rhs)
{
	return concatenate(rhs);
}

void String::char_pointer_copy(const char * const p_chars)
{
	delete p_char_string;
	
	n_length = calculate_length(p_chars);
	p_char_string = new char[n_length + 1];
	for(unsigned int i = 0; i < n_length; i++)
	{
		p_char_string[i] = p_chars[i];
	}
}

unsigned int String::calculate_length(const char * const p_chars) const
{
	unsigned int length = 0, max_length = 65536; // perhaps have a big string modifier which allows larger strings for the future.
	
	while (p_chars[length] && length < max_length)
		length++;
	return length;	
}

	/*asm volatile (
	    ".intel_syntax;"  // Switch to Intel syntax
		"cld;"
		"push edi;"
		"push ecx;"
		"xor eax, eax;"
		"mov edi, %1;"
		"mov ecx, 0xffff;"
		"repnz scasb;"
		"not cx;"
		"dec cx;"
		"movzx eax, cx;"
		"mov %0, eax;"
		"pop ecx;"
		"pop edi;"
		: "=r" (length)
		: "r" (p_chars)
		would have been nice if it worked.
	);*/