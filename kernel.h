#ifndef __KERNEL_H__
#define __KERNEL_H__

typedef unsigned char 		byte;
typedef unsigned short 		word;
typedef unsigned int 		dword;
typedef unsigned long long 	qword;	// must be long long otherwise it's just 4 again.  

/*
	This is the entry-point for "eshell" the eric-shell written in C++.  
	Since we cannot include a class into C, we'll extern it as well.  
*/
extern dword eshell_entry(int rows, int cols);


union FloppyDiskRead {
	dword drive_track;
	struct __attribute__((packed)) 
	{
		word track;
		byte drive;
		byte unused;
	};
};

extern int cstrings_equal(char * string1, char * string2);
extern char * cgetline(char * in_string, unsigned intposition);
extern void cprintline(char * out_string, unsigned int position);
extern unsigned short read_pit();
extern unsigned int chex_to_number(char * p_string);
extern unsigned int startswith(char * big_string, char * test_string);
extern void print_string(char * out_string, unsigned int position);
extern char nibble_to_hexchar(unsigned char nibble, unsigned char upper_case);
extern __fastcall unsigned int hex_str_to_value(char * p_string);
extern void __fastcall print_hex_byte(unsigned char byte, unsigned int position);
extern void __fastcall print_hex_word(unsigned short word, unsigned int position);
extern void __fastcall print_hex_dword(unsigned int dword, unsigned int position);
extern void __fastcall hex_dump(unsigned char * starting_address);
extern void display_cpuid();

extern void fdisk_init_controller();
extern void display_stack_values(unsigned int a, unsigned short b);

extern dword __fastcall fdisk_read_sector(union FloppyDiskRead * fdr, dword sector);
extern void fdisk_display_msr();
extern void __fastcall fdisk_recalibrate(dword drive_number);
extern byte fdisk_version();
extern void fdisk_identify();

extern void rtc_display_datetime(dword position);
extern void rtc_toggle_display();

extern void clear_screen();
extern void display_ascii_characters();

extern void ata_identify_drives();
extern void ata_display_status();
extern void __fastcall ata_write_sector_lba(dword controller_and_drive, dword num_sectors, qword lba_address, dword address);
extern void __fastcall ata_read_sector_lba(dword controller_and_drive, dword num_sectors, qword lba_address, dword address);


extern void __fastcall print_decimal(dword number, dword position);

#endif 