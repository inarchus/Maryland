OUTPUT_FORMAT("elf32-i386");
/* We define an entry point to keep the linker quiet. This entry point
 * has no meaning with a bootloader in the binary image we will eventually
 * generate. Bootloader will start executing at whatever is at 0x07c00 
 https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_3.html#SEC17
 */
ENTRY(start);
SECTIONS
{
    .text0 0x7c00 : {
        boot.o(.text);
    }

    .data : SUBALIGN(2) {
		boot.o(.data);
    }
    .sig 0x7DFE : {
        SHORT(0xaa55);
    }
    
    .text1 ALIGN(0x8000): {
        secondary.o(.text);
		kernel.o (.text);
		pic8259.o (.text);
		pit.o (.text)
		memory.o (.text);
		memory_c.o (.text);
		cpuid.o (.text);
		rtc.o (.text)
		ata.o (.text);
    }

    .data1 : SUBALIGN(2) {
        secondary.o(.data);
		kernel.o (.data);
		pic8259.o (.data);
		pit.o (.data)
		memory.o (.data);
		memory_c.o (.data);
		cpuid.o (.data);
		rtc.o (.data);
		ata.o (.data);
		/* *(.rodata*); */
    }

    .bss0 : SUBALIGN(4) {
	    secondary.o(.bss);
    }
	.bss1 : ALIGN(0x180000) {
		kernel.o (.bss);
		memory.o (.bss);
		memory_c.o (.bss);
		pit.o (.bss)
		pic8259.o (.bss);
		rtc.o (.bss);
		ata.o (.bss);
	}
}
