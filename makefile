ASSEMBLER = nasm
ASM_FLAGS = elf32
CLANG_FLAGS = -target i386 -nostdlib -ffreestanding 
# -Wno-builtin-declaration-mismatch

ASSEMBLY_OBJECTS = boot.o secondary.o kernel.o pit.o pic8259.o interrupts.o memory.o floppy_driver.o rtc.o ata.o cpuid.o
CLANG_OBJECTS = user_interface.o kernel_c.o etui_object.o e_progress_bar.o memory_c.o

boot: assemble $(CLANG_OBJECTS)
	ld -m elf_i386 --build-id=none -T link.ld $(ASSEMBLY_OBJECTS) $(CLANG_OBJECTS) -o boot.elf
	objcopy -O binary boot.elf boot.bin
	qemu-img convert -f raw boot.bin -O qcow2 boot.bin boot.qcow2
	@stat boot.bin | grep "Size:"

etui_object.o: etui/ETUIObject.h etui/ETUIObject.cpp
	clang $(CLANG_FLAGS) -c etui/ETUIObject.cpp -o etui_object.o
e_progress_bar.o: etui/EProgressBar.cpp etui/EProgressBar.h
	clang $(CLANG_FLAGS) -c etui/EProgressBar.cpp -o e_progress_bar.o
user_interface.o: user_interface.cpp user_interface.h
	clang $(CLANG_FLAGS) -c user_interface.cpp -o user_interface.o
kernel_c.o: kernel.c kernel.h
	clang $(CLANG_FLAGS) -c kernel.c -o kernel_c.o
memory_c.o: memory.c
	clang $(CLANG_FLAGS) -c memory.c -o memory_c.o

assemble: $(ASSEMBLY_OBJECTS) 
	$(ASSEMBLER) -f $(ASM_FLAGS) memory.asm -o memory.o
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
	qemu-system-i386 -fda boot.qcow2 -hda /mnt/d/Virtual\ Machines/Maryland/Maryland.vmdk -boot order=a -cpu pentium3,sse=on
# -D qemu_i386.log -d cpu ; we want to turn logging on but this is too much info.  
run64:
	qemu-system-x86_64 -fda boot.qcow2 -hda /mnt/d/Virtual\ Machines/Maryland/Maryland.vmdk -cpu Nehalem,sse2=on
# -cpu Nehalem
# A vfd file is literally a raw file containing exactly 1440kb or 1,474,560 bytes.  The bin is also a raw file, but doesn't have that exact requirement.  
# So we'll just extend the file to the proper length using "truncate."  VFD format files work in the Hyper-V for windows 10 and VirutalBox
vfd: boot
	cp boot.bin floppy.vfd
	truncate -s 1474560 floppy.vfd
	cp floppy.vfd /mnt/d/Projects/
