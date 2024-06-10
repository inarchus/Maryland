ASSEMBLER = nasm

boot-clang: assemble
	clang -target i386 -nostdlib -ffreestanding -c kernel.c -o kernel_c.o
	clang -target i386 -nostdlib -ffreestanding -c memory.c -o cmemory.o
	ld -m elf_i386 --build-id=none -T link.ld boot.o secondary.o kernel.o kernel_c.o pit.o memory.o cmemory.o pic8259.o cpuid.o -o boot.elf
	objcopy -O binary boot.elf boot.bin
	qemu-img convert -f raw boot.bin -O qcow2 boot.bin boot.qcow2
	@ls -l | grep "boot.bin"
boot-gcc: assemble 
	gcc -m32 -fpie --freestanding -fno-asynchronous-unwind-tables -c kernel.c -o kernel_c.o
	ld -m elf_i386 --build-id=none -T link.ld boot.o secondary.o kernel.o kernel_c.o pit.o memory.o cmemory.o -o boot.elf
	objcopy -O binary boot.elf boot.bin
	qemu-img convert -f raw boot.bin -O qcow2 boot.bin boot.qcow2
	
assemble: boot.asm secondary.asm kernel.asm pit.asm memory.asm pic8259.asm
	$(ASSEMBLER) -f elf32 boot.asm -o boot.o
	$(ASSEMBLER) -f elf32 secondary.asm -o secondary.o
	$(ASSEMBLER) -f elf32 kernel.asm -o kernel.o
	$(ASSEMBLER) -f elf32 pic8259.asm -o pic8259.o
	$(ASSEMBLER) -f elf32 pit.asm -o pit.o
	$(ASSEMBLER) -f elf32 memory.asm -o memory.o
	$(ASSEMBLER) -f elf32 cpuid.asm -o cpuid.o
clean:
	rm boot.bin boot.elf boot.o secondary.o kernel.o kernel_c.o
run:
	qemu-system-i386 -fda boot.qcow2 -boot order=a
run64:
	qemu-system-x86_64 -fda boot.qcow2 -cpu Nehalem,sse2=on

boot-image: assemble
	gcc -m32 -fno-pic --freestanding -fno-asynchronous-unwind-tables -c kernel.c -o kernel_c.o
	ld -m elf_i386 --oformat binary --build-id=none -T link.ld boot.o secondary.o kernel.o kernel_c.o pit.o -o boot.img
	cp boot.img /mnt/d/Projects/

# A vfd file is literally a raw file containing exactly 1440kb or 1,474,560 bytes.  The bin is also a raw file, but doesn't have that exact requirement.  
# So we'll just extend the file to the proper length using "truncate."  VFD format files work in the Hyper-V for windows 10 and VirutalBox
vfd: boot-clang
	cp boot.bin floppy.vfd
	truncate -s 1474560 floppy.vfd
	cp boot.img floppy.vfd /mnt/d/Projects/
