The Project
============
The primary goal of this project is to learn.  I have always wanted to create an operating system with an old style bootloader, a kernel, etc, no UEFI boot.  

*	The Operating System will be built for Pentium 4 architecture in mind, meaning 32 bits x86, with MMX, SSE (maybe SSE2 if I can get away with it).  
*	The goal is to learn about all of the ways in which the operating system interacts with hardware.  I feel like UEFI takes away from that significantly.  
*	Primarily I am using QEMU for testing, as it runs quickly in WSL2-Ubuntu and allows quick compilation and restarting since the operating system is so small. 
*	I've also used VirtualBox and VMWare Workstation to test the differences between virutal machines and their interaction with the OS.  
*	

What You Need
============
I am using WSL2/Ubuntu to build so I assume that most versions of linux should be acceptable as build environments as long as you can install:

*	NASM: nasm is the assembler that I'm most familiar with and like the most anyway.  
*	Clang: You may think gcc will be fine, but it has a number of issues with cross compilation that made it necessary to install clang, which has been working far better. 
*	QEMU: qemu-system-x86 should give the necessary emulation software.  
	* apt install qemu-system-x86
	* I use both qemu-system-i386 which almost seems partially deprecated on their documentation but still works, and qemu-system-x86 for emulation for core2/nehalem.
*	make: Nothing complex here, not using any super-advanced build tools as they are not yet necessary.  
*	python3: as long as you're on an ubuntu installation it will come with it, but otherwise you'll need it.  There is a python script which generates the link.ld file for us, so that we don't need to rely on doing it manually, which caused me many problems.  
*	Clone the repository.
	
Create your config.mk
============
You'll need to add your path to a file called config.mk.  The only line currently should be:
PATH_TO_VMDK_HDA = [insert your path to the hard drive image here]

If you want to create a hard drive image you can use:
*	make vmdk-disk
This will create a 40 MB flat (allocated and set to zero) vmdk file which QEMU and VMWare can use.  

Development Journal
============
[a relative link](dev_journal.md)