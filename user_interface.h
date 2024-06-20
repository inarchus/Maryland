
#ifndef __USER_INTERFACE_H__
#define __USER_INTERFACE_H__

#include "etui/ETUIObject.h"
#include "string.h"

typedef unsigned int dword;

extern "C" void __fastcall print_hex_byte(unsigned char byte, unsigned int position);
extern "C" void __fastcall print_hex_word(unsigned short word, unsigned int position);
extern "C" void __fastcall print_hex_dword(unsigned int dword, unsigned int position);
extern "C" void __fastcall hex_dump(unsigned char * starting_address);

extern "C" dword eshell_entry(int rows, int cols);

dword eshell_entry(int rows, int cols);


/*
	Screen Buffers can be used as back-buffers or draw buffers
*/
class EScreenBuffer
{
	public:
		EScreenBuffer();
	private:
		
};


class EFrame : public ETUIObject
{
	public:
		EFrame();
		void redraw();
};

class ETextInput : public ETUIObject
{
	public:
	private:
};

class EButton : public ETUIObject
{
	public:
		void press() {}
	private:
};

class ETextDisplay : public ETUIObject
{
	public:
		String & getText() 
		{
			return display_text;
		}
		void setText(char * new_text) {}
	private:
		String display_text;
};

class EShellTextUI
{
	public:
		EShellTextUI(int rows, int cols, int color_bits);
		dword run();
	private:
		int n_rows, n_cols, n_color_bits;
		EScreenBuffer ** screen_buffer_array;
		int n_buffers;
};

#endif