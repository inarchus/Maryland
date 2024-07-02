#include "ETUIObject.h"
#include "../string.h"

extern "C" void __fastcall print_hex_dword(unsigned int dword, unsigned int position);

int ETUIObject::screen_width = 80;

ETUIObject::ETUIObject()
	: row_position(0), col_position(0), row_size(10), col_size(10), visible(false), p_parent(nullptr), base_pointer(this), border_symbol(0xb1)
{
	
}

void ETUIObject::redraw()
{

}

ETUIObject * ETUIObject::GetParent() const
{
	return p_parent;
}

void ETUIObject::SetParent(ETUIObject * p_new_parent)
{
	p_parent = p_new_parent;
}

void ETUIObject::printToBuffer(int x_pos, int y_pos, char out_char, byte format)
{
	word * p_screen = (word*)0xb8000;
	p_screen[(row_position + x_pos) * screen_width + (col_position + y_pos)] = (format << 8) | out_char;
	print_hex_dword((dword)&screen_width, 0x0500);
}

void ETUIObject::drawString(int x_pos, int y_pos, const String & the_string, byte format)
{
	word * p_screen = (word*)0xb8000;
	for(int i = 0; i < the_string.Length(); i++)
	{
		p_screen[(row_position + x_pos) * screen_width + (col_position + y_pos)] = (format << 8) | the_string[i];
	}
}

/*
asm (
		"movl %0, %%eax;"
		"movxzb 80, %%ebx;"
		"movb %2, %%al;"
		"movl %3, %%ecx;"
		: 
		: "r" (x_pos), "r" (y_pos), "r" (out_char), "r" (format), "r"(screen_width)
		: 
	);	
	*/
