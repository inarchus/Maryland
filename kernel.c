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
		else if(cstrings_equal(in_string, "fdisk init"))
		{
			cprintline("Starting Floppy Drive Init", 0x0200);
			fdisk_init_controller();
			cprintline("Floppy Drive Initialized", 0x0300);
		}			
		else if(startswith(in_string, "fdisk read"))
		{
			//union FloppyDiskRead fdr;
			unsigned int input_values = hex_str_to_value(in_string + 11);
			unsigned int sectors = input_values & 0xffff;
			
			// ecx = [controller=0 for now | drive = 0 = fda for now| ch = head | cl = track]
			//  edx = [dh = sector_start | dl = n_sectors]
			fdisk_read_sector(input_values >> 16, sectors);
		}
		else if(startswith(in_string, "configure pit"))
		{
			unsigned int pit_word = hex_str_to_value(in_string + 13);
			print_hex_word(pit_word, 0x0400);
			configure_pit(pit_word);
		}
		else if(cstrings_equal(in_string, "display msr"))
		{
			fdisk_display_msr();			
		}
		else if(cstrings_equal(in_string, "fdisk recalibrate"))
		{
			fdisk_recalibrate(0);
		}
		else if(cstrings_equal(in_string, "fdisk controller version"))
		{
			print_string("ver=", 0x162c);
			print_hex_byte(fdisk_version(), 0x1630);
		}
		else if(cstrings_equal(in_string, "fdisk identify drives"))
		{
			fdisk_identify();
		}
		else if(cstrings_equal(in_string, "ata identify drives"))
		{
			ata_identify_drives();
		}
		else if(cstrings_equal(in_string, "ata test drive0"))
		{
			run_ata_test();
		}
		else if(cstrings_equal(in_string, "cpuid"))
		{
			display_cpuid();
		}
		else if(cstrings_equal(in_string, "clear screen"))
		{
			clear_screen();
			cprintline("Screen Cleared", 0x0000);
		}
		else if(cstrings_equal(in_string, "display ascii"))
		{
			display_ascii_characters();			
		}
		else if(cstrings_equal(in_string, "ata get status"))
		{
			ata_display_status();
		}
		else if(cstrings_equal(in_string, "test decimal conversion"))
		{
			print_decimal(45915, 0x0200);
			print_decimal(23, 0x0300);
			print_decimal(7788125, 0x0400);
			print_decimal(0, 0x0500);
			print_decimal(4294967295, 0x0600);
		}
		else if(cstrings_equal(in_string, "divide by zero"))
		{
			int x = 5, y = 0;
			print_decimal(x/y, 0x0100);
		}
		else if(cstrings_equal(in_string, "rtc toggle"))
		{
			rtc_toggle_display();
			clear_screen();
		}
		else if(cstrings_equal(in_string, "esh"))
		{
			eshell_entry(25, 80);
		}
		else if(cstrings_equal(in_string, "ata test write"))
		{
			for(dword i = 0x00300000; i < 0x00300200; i++)
			{
				*((byte *)i) = i % 256;
			}
			// this explodes in a way that is unimaginable... 
			ata_write_sector_lba(0, 1, 0x0, 0x00300000);
		}
		else if(cstrings_equal(in_string, "ata test read"))
		{
			ata_read_sector_lba(0, 1, 0x0, 0x00310000);
		}
		else if(cstrings_equal(in_string, "get size of long"))
		{
			print_hex_byte(sizeof(long long), 0x0300);
		}
		else if(cstrings_equal(in_string, "test memory allocation"))
		{
			run_memory_test();			
		}
		else
		{
			cprintline(in_string, 0);
		}
	}
}

inline void cprint_hex_byte(unsigned char byte, unsigned int position)
{
	print_hex_byte(byte, position);
}

inline void cprint_hex_word(unsigned short word, unsigned int position)
{
	print_hex_word(word, position);
}

inline void cprint_hex_dword(unsigned int dword, unsigned int position)
{
	print_hex_dword(dword, position);
}
