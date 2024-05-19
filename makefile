boot: boot.asm secondary.asm tertiary.c
	nasm -f elf32 boot.asm -o boot.o
	nasm -f elf32 secondary.asm -o secondary.o
	# gcc -m16 --freestanding -c tertiary.c -o tertiary.o
	ld -m elf_i386 --build-id=none -T link.ld boot.o secondary.o -o boot.elf
	objcopy -O binary boot.elf boot.bin
	qemu-img convert -f raw boot.bin -O qcow2 boot.bin boot.qcow2
clean:
	rm boot.bin boot.elf boot.o
run:
	qemu-system-i386 -fda boot.qcow2 -boot order=a
boot-image:
	ld -m elf_i386 --build-id=none -T link.ld boot.o secondary.o -o boot.img --oformat binary

# https://docs.openstack.org/image-guide/convert-images.html - how to handle qemu-img convert
# this one doesn't work anyway
virtualbox:
	qemu-img convert -f raw boot.bin -O vdi boot.bin boot.vdi
