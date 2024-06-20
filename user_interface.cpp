#include "user_interface.h"

extern "C" dword eshell_entry(int rows, int cols);

dword eshell_entry(int rows, int cols)
{
	EShellTextUI shell(rows, cols, 4);
	return shell.run();
}

EShellTextUI::EShellTextUI(int rows, int cols, int color_bits)
	: n_rows(rows), n_cols(cols), n_color_bits(color_bits)
{

}

dword EShellTextUI::run()
{
	print_hex_dword(0xabc12345, 0x0420);
	return 0;
}