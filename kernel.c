/*
	Next objective is to have a split function.
*/

#include "kernel.h"

enum {FALSE = 0, TRUE = 1};


void main_shell(char * in_string)
{
	int position = 0;
	while(1)
	{
		
		cprintline(" ", 0x1700);		// blank the line out
		cgetline(in_string, 0x1700);
		if (startswith(in_string, "hexdump"))
		{
			unsigned int address = hex_str_to_value(in_string + 8);
			hex_dump((unsigned char *)address);
		}
		else if(cstrings_equal(in_string, "read pit"))
		{
			unsigned short pit_count = read_pit();
			print_hex_word(pit_count, 0x1830);
		}
		else if(cstrings_equal(in_string, "display stack"))
		{
			display_stack_values(17, 0xabcd);//, 0x15253545);
		}
		else if(cstrings_equal(in_string, "cpuid"))
		{
			display_cpuid();
		}
		else
		{
			cprintline(in_string, 0);
		}
	}
}

