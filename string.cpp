#include "string.h"
#include "array.h"
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
	delete [] p_char_string;
}

bool String::IsWhitespace(char x) const
{
	return x == ' ' || x == '\n' || x == '\r' || x == '\t';
}

String & String::Concatenate(const String & rhs)
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
bool String::Equals(const String & rhs) const
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
bool String::Startswith(const String & rhs) const
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
String & String::Upper()
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
String & String::Lower()
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

inline unsigned int String::Length() const
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
	return Equals(rhs);
}
String String::operator + (const String & rhs)
{
	String new_string(*this);
	new_string.Concatenate(rhs);
	return new_string;
}
String & String::operator += (const String & rhs)
{
	return Concatenate(rhs);
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
	p_char_string[n_length] = 0; // null terminate
}

unsigned int String::calculate_length(const char * const p_chars) const
{
	unsigned int length = 0, max_length = 65536; // perhaps have a big string modifier which allows larger strings for the future.
	
	while (p_chars[length] && length < max_length)
		length++;
	return length;	
}

String String::Substring(int start_index, int end_index) const
{
	String result;

	if (0 <= start_index && end_index <= n_length)
	{
		result.p_char_string = new char[end_index - start_index + 1];
		for(int i = start_index; i < end_index; i++)
		{
			result.p_char_string[i - start_index] = p_char_string[i];
		}
		
		result.p_char_string[end_index - start_index] = 0;
	}
	return result;
}

Array<String> String::Split() const
{
	Array<String> result;
	
	int current_start = -1;
	
	for(unsigned int i = 0; i < n_length; i++)
	{
		if(!IsWhitespace(p_char_string[i]) && current_start == -1)
		{
			current_start = i;
		}
		else if(current_start != -1 && IsWhitespace(p_char_string[i]))
		{
			result.append(Substring(current_start, i));
			current_start = -1;
		}
	}
	
	return result;
}
