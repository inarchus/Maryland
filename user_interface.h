#include "etui/ETUIObject.h"
#include "string.h"

#ifndef __USER_INTERFACE_H__
#define __USER_INTERFACE_H__

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