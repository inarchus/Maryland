#ifndef __KERNEL_H__
#define __KERNEL_H__

typedef unsigned char 	byte;
typedef unsigned short 	word;
typedef unsigned int 	dword;


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

#endif 