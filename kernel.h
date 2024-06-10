#ifndef __KERNEL_H__
#define __KERNEL_H__

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

extern void display_stack_values(unsigned int a, unsigned short b);


#endif 