OUTPUT_FORMAT("elf32-i386");
/* We define an entry point to keep the linker quiet. This entry point
 * has no meaning with a bootloader in the binary image we will eventually
 * generate. Bootloader will start executing at whatever is at 0x07c00 */
ENTRY(start);
SECTIONS
{
    .text0 0x7c00 : {
        boot.o(.text);
    }

    .data : SUBALIGN(2) {
	boot.o(.data);
        *(.rodata*);
    }
    .sig 0x7DFE : {
        SHORT(0xaa55);
    }
    
    .text1 ALIGN(0x8000): {
        secondary.o(.text);
    }

    .data1 : SUBALIGN(2) {
        secondary.o(.data);
    }

    .bss : SUBALIGN(4) {
        secondary.o(.bss);
    }
}
