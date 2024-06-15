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
			union FloppyDiskRead fdr;
			fdr.unused = 0xff;
			fdr.drive = 0;
			fdr.track = 0; 					// already read all of track 0
			fdisk_read_sector(&fdr, 1); 	// read starting at sector 1.  
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
		else if(cstrings_equal(in_string, "rtc toggle"))
		{
			rtc_toggle_display();
			clear_screen();
		}
		else
		{
			cprintline(in_string, 0);
		}
	}
}

