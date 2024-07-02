ASSEMBLER = nasm
ASM_FLAGS = elf32
CLANG_FLAGS = -target i386 -nostdlib -ffreestanding -fno-exceptions -fno-rtti -mabi=lp64

include config.mk

export ASSEMBLY_OBJECTS_REAL_MODE = boot.o secondary.o 
export ASSEMBLY_OBJECTS_PROTECTED = kernel.o pit.o pic8259.o interrupts.o memory.o floppy_driver.o rtc.o ata.o cpuid.o keyboard.o
export CLANG_OBJECTS = user_interface.o kernel_c.o etui_object.o e_progress_bar.o memory_c.o string.o e_frame.o e_button.o e_text_input.o e_text_display.o msfat.o ata_c.o

boot: link-file config.mk assemble $(CLANG_OBJECTS) 
	ld -m elf_i386 --build-id=none -T link.ld $(ASSEMBLY_OBJECTS_REAL_MODE) $(ASSEMBLY_OBJECTS_PROTECTED) $(CLANG_OBJECTS) -o boot.elf
	objcopy -O binary boot.elf boot.bin
#	qemu-img convert -f raw boot.bin -O qcow2 boot.bin boot.qcow2
	@cp boot.bin floppy.vfd
	@truncate -s 1474560 floppy.vfd
	@stat boot.bin | grep "Size:"

link-file: makefile
	python3 generate_link_file.py

etui_object.o: etui/ETUIObject.h etui/ETUIObject.cpp
	clang $(CLANG_FLAGS) -c etui/ETUIObject.cpp -o etui_object.o
e_button.o: etui/EButton.cpp etui/EButton.h
	clang $(CLANG_FLAGS) -c etui/EButton.cpp -o e_button.o
e_text_input.o: etui/ETextInput.cpp etui/ETextInput.h
	clang $(CLANG_FLAGS) -c etui/ETextInput.cpp -o e_text_input.o
e_text_display.o: etui/ETextInput.cpp etui/ETextInput.h
	clang $(CLANG_FLAGS) -c etui/ETextDisplay.cpp -o e_text_display.o
e_frame.o: etui/EFrame.cpp etui/EFrame.h
	clang $(CLANG_FLAGS) -c etui/EFrame.cpp -o e_frame.o
e_progress_bar.o: etui/EProgressBar.cpp etui/EProgressBar.h
	clang $(CLANG_FLAGS) -c etui/EProgressBar.cpp -o e_progress_bar.o


user_interface.o: user_interface.cpp user_interface.h
	clang $(CLANG_FLAGS) -c user_interface.cpp -o user_interface.o
kernel_c.o: kernel.c kernel.h
	clang $(CLANG_FLAGS) -c kernel.c -o kernel_c.o
memory_c.o: memory.cpp memory.h
	clang $(CLANG_FLAGS) -c memory.cpp -o memory_c.o
string.o: string.h string.cpp
	clang $(CLANG_FLAGS) -c string.cpp -o string.o
ata_c.o:
	clang $(CLANG_FLAGS) -c ata.cpp -o ata_c.o
msfat.o: msfat.h msfat.cpp
	clang $(CLANG_FLAGS) -c msfat.cpp -o msfat.o

assemble: $(ASSEMBLY_OBJECTS_REAL_MODE) $(ASSEMBLY_OBJECTS_PROTECTED) 
	
memory.o: memory.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) memory.asm -o memory.o
keyboard.o: keyboard.asm ps2map.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) keyboard.asm -o keyboard.o
floppy_driver.o: floppy_driver.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) floppy_driver.asm -o floppy_driver.o
rtc.o: rtc.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) rtc.asm -o rtc.o
ata.o: ata.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) ata.asm -o ata.o
boot.o: boot.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) boot.asm -o boot.o
secondary.o: secondary.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) secondary.asm -o secondary.o
kernel.o: kernel.asm ps2map.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) kernel.asm -o kernel.o
interrupts.o: interrupts.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) interrupts.asm -o interrupts.o
pic8259.o: pic8259.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) pic8259.asm -o pic8259.o
pit.o: pit.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) pit.asm -o pit.o
cpuid.o: cpuid.asm
	$(ASSEMBLER) -f $(ASM_FLAGS) cpuid.asm -o cpuid.o
clean:
	rm *.o boot.bin
run:
	qemu-system-i386 -drive file=floppy.vfd,index=0,if=floppy,format=raw -hda $(PATH_TO_VMDK_HDA) -boot order=a -cpu pentium3,sse=on -k en-us -vga std
# -D qemu_i386.log -d cpu ; we want to turn logging on but this is too much info.  
run64:
	qemu-system-x86_64 -fda boot.qcow2 -hda $(PATH_TO_VMDK_HDA) -cpu Nehalem,sse2=on
# -cpu Nehalem
# A vfd file is literally a raw file containing exactly 1440kb or 1,474,560 bytes.  The bin is also a raw file, but doesn't have that exact requirement.  
# So we'll just extend the file to the proper length using "truncate."  VFD format files work in the Hyper-V for windows 10 and VirutalBox
vfd: boot
	cp boot.bin floppy.vfd
	truncate -s 1474560 floppy.vfd
	cp floppy.vfd /mnt/d/Projects/

vmdk-disk:
	qemu-image create -f vmdk -o subformat=monolithicFlat $(PATH_TO_VMDK_HDA) 40M
