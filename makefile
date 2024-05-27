boot: boot.asm secondary.asm kernel.asm
	nasm -f elf32 boot.asm -o boot.o
	nasm -f elf32 secondary.asm -o secondary.o
	nasm -f elf32 kernel.asm -o kernel.o
	gcc -m32 -fpie --freestanding -fno-asynchronous-unwind-tables -c kernel.c -o kernel_c.o
	ld -m elf_i386 --build-id=none -T link.ld boot.o secondary.o kernel.o kernel_c.o -o boot.elf
	objcopy -O binary boot.elf boot.bin
	qemu-img convert -f raw boot.bin -O qcow2 boot.bin boot.qcow2
clean:
	rm boot.bin boot.elf boot.o secondary.o kernel.o kernel_c.o
run:
	qemu-system-i386 -fda boot.qcow2 -boot order=a
run64:
	qemu-system-x86_64 -fda boot.qcow2 -cpu Nehalem,sse2=on
boot-image:
	nasm -f elf32 boot.asm -o boot.o
	nasm -f elf32 secondary.asm -o secondary.o
	nasm -f elf32 kernel.asm -o kernel.o
	gcc -m32 -fno-pic --freestanding -fno-asynchronous-unwind-tables -c kernel.c -o kernel_c.o
	ld -m elf_i386 --oformat binary --build-id=none -T link.ld boot.o secondary.o kernel.o kernel_c.o -o boot.img
	cp boot.img /mnt/d/Projects/

# A vfd file is literally a raw file containing exactly 1440kb or 1,474,560 bytes.  The bin is also a raw file, but doesn't have that exact requirement.  
# So we'll just extend the file to the proper length using "truncate."  VFD format files work in the Hyper-V for windows 10 and VirutalBox
vfd: boot
	cp boot.bin floppy.vfd
	truncate -s 1474560 floppy.vfd
	cp boot.img /mnt/d/Projects/
