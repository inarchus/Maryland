ENTRY(hdboot_entry);
SECTIONS
{
	bpb_boot_sector 0x7c00 : {
		hdboot.o (.bpb_boot_sector);
	}
	boot_entry 0x7c5a : {
		hdboot.o (.text);
	}
	boot_entry_data : SUBALIGN(2) {
		hdboot.o (.data);
	}
	boot_entry_sig 0x7dfe : {
		hdboot.o (.boot_signature);
	}
	
}