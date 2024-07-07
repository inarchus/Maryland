ENTRY(bootloader_init);
SECTIONS
{
 	secondary-bss 0x4000 :   {
		secondary.o (.bss); 
	}
 	secondary 0x8000 :   {
		secondary.o (.text);
		secondary.o (.data); 
	}
 	kernel-text  : ALIGN(0x200)  {
		kernel.o (.text);
		pit.o (.text);
		pic8259.o (.text);
		interrupts.o (.text);
		memory.o (.text);
		floppy_driver.o (.text);
		rtc.o (.text);
		ata.o (.text);
		cpuid.o (.text);
		keyboard.o (.text);
		msfat_asm.o (.text);
		user_interface.o (.text);
		kernel_c.o (.text);
		etui_object.o (.text);
		e_progress_bar.o (.text);
		memory_c.o (.text);
		string.o (.text);
		e_frame.o (.text);
		e_button.o (.text);
		e_text_input.o (.text);
		e_text_display.o (.text);
		msfat.o (.text);
		ata_c.o (.text); 
	}
 	kernel-data  :  SUBALIGN(0x4) {
		kernel.o (.data);
		pit.o (.data);
		pic8259.o (.data);
		interrupts.o (.data);
		memory.o (.data);
		floppy_driver.o (.data);
		rtc.o (.data);
		ata.o (.data);
		cpuid.o (.data);
		keyboard.o (.data);
		msfat_asm.o (.data);
		user_interface.o (.data);
		kernel_c.o (.data);
		etui_object.o (.data);
		e_progress_bar.o (.data);
		memory_c.o (.data);
		string.o (.data);
		e_frame.o (.data);
		e_button.o (.data);
		e_text_input.o (.data);
		e_text_display.o (.data);
		msfat.o (.data);
		ata_c.o (.data); 
	}
 	kernel-bss 0x200000 :   {
		kernel.o (.bss);
		pit.o (.bss);
		pic8259.o (.bss);
		interrupts.o (.bss);
		memory.o (.bss);
		floppy_driver.o (.bss);
		rtc.o (.bss);
		ata.o (.bss);
		cpuid.o (.bss);
		keyboard.o (.bss);
		msfat_asm.o (.bss);
		user_interface.o (.bss);
		kernel_c.o (.bss);
		etui_object.o (.bss);
		e_progress_bar.o (.bss);
		memory_c.o (.bss);
		string.o (.bss);
		e_frame.o (.bss);
		e_button.o (.bss);
		e_text_input.o (.bss);
		e_text_display.o (.bss);
		msfat.o (.bss);
		ata_c.o (.bss); 
	}
}