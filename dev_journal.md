Development Journal body { font-family: "Verdana"; } section { width: 50%; margin: 0 auto; } h1 {text-align: center; font-size: 3.0em; } h2 {text-align: center; font-size: 1.5em; }

18 June 2024
============

Beginning of Journal: I want to write this so that I can recall my thoughts and steps along the way, given that this development is being done without any real knowledge of how to do any of it, figuring it out along the way. I've been working on this for about a month.

Wrong Addressing for Segments
-----------------------------

Today I faced a number of problems. The first was that I couldn't count. I was loading using boot.asm 0x8000-0x9fff and then loading to 0x10000 instead of 0xa000. That's now fixed. I'm also totally confused currently about how sector-track-heads work on the floppy because for the second read from (side) head=1 track=0 I have to start at sector 4 instead of 0. Maybe I need to recalibrate the heads to zero or something but honestly I don't have a clue yet. When I addressed incorrectly the symptom was that variables in the .data segment basically were all 0's. To me this indicated that the variables were not at their correct addresses since all memory is zero. Many hexdumps and searches were required and it was frustrating because it ate most of my progress for the day.

ATA Driver
----------

I also tested out the read and write from ATA today for the first time, which initially wrote to some bizarre address but fixing the way that the parameters are passed and checking to make sure the offsets were correct fixed that. I have successfully written and read from address 0x0 on the drive. We're using PIO (Polling I/O) rather than the DMA currently, but that doesn't really matter yet. I added a read from the alternative status register of the first controller until the DRQ bit is set, which means that we're ready to read data. It wasn't specified in the 48 bit PIO instructions which I followed pretty religiously, but it makes sense that it would need to be set, and looking deeply at their sample driver, which I didn't really use otherwise, they also do the same thing. Reading before the DRQ bit is set produces 0's, maybe even flips an ERR bit but I wouldn't know since my code currently isn't safe enough to check.

Next Steps
----------

In terms of next steps currently we have a few big jobs to do:

*   Get dynamic memory working probably in C++ by implementing new, new\[\] and delete. We need this to do the next two tasks. I'm probably going to implement a very terrible version which allocates and then never really deletes anything, just so that we can test out some of the other things we need to do. Eventually we'll run out of ram, I suppose but really we don't run this enough to matter, yet.
*   Implement a string class to handle strings of all kinds. Strings will require dynamic memory allocation. This isn't glorious but I need to for the text boxes and edit boxes in the next item. Should be a few minutes of boring work really. I should probably also implement a vector/array class for the same reason.
*   Once those things are done, we should implement the TUI = text user interface classes. I want to build an interface with frames/windows, buttons, text boxes, edit boxes, and other controls in order to fix what we're coming up against which is almost too much to display at a given time.
*   Eventually I need to go back and fix the floppy driver which casuses reboots/faults on VMWare and VirtualBox, meaning something that is probably emulated there is more detailed than the QEMU emulation.
*   Add more support for faults and attempt to debug them without having the emulated computer reboot. #GP and #UD are probably the next targets.
*   Once the TUI is up and running, create tabs for CPUID, Floppy Drives, Hard Drives, Controllers, and add a tab for data entry into ram so that we can then save it to the hard drive or move it, perform memory operations, etc.
*   Once all of that is done, begin implementing the FAT32 format so that we can actually use the hard drive as a hard drive. FAT32 is a decent format in the sense that it has a max of 4gb files and currently this OS will have a drive of 40 MB. We can implement ext4, ntfs, btrfs all when anything else actually works.
*   See if we can get VGA support actually working so that we can output to the screen by pixel and then really begin making a GUI, but this is far far future work.
*   Also for the far future, getting PCI support would be nice.
*   In terms of the TUI one feature I want to support is a kind of virtual keyword without the keyword meaning if we have ETUIObject \*'s we can call redraw and it will know which method is correct. Some work on this today but no success yet.

19 June 2024
============

I learned two things today. The first is that if you don't include something in the link.ld file, then you will end up with the sections of .data potentially going anywhere including into the boot.data section which means that the amount of data will quickly exceed the MBR. We should write an auto-generation script that will make a link.ld file appropriately.

I also learned that on a different computer, the sector you need is also different in boot.asm for the secondary load. It was 3 instead of 4, I have no explanation for this either.

Currently the OS cannot be compiled via the github without modification, I think we should probably make it so that it can be built out of the box, but that will take a bit more effort.

Link.ld Automation
------------------

I've written a python script that generates link.ld, that was basically all the progress of the 19th.

20 June 2024
============

Another day with very little progress. My goal was to get the TUI operational so I've been slowly grinding away at coding it, with the knowledge that I need to get the redraw() method working in all of the classes descending from ETUIObject. I need to reproduce a virtual method, unless perhaps I could just cheat and use the vtable. Let's try that. I got it to work, at least no errors. I implemented an array class (vector equivalent) and a string class.

Now I think it's time to implement the drawing of borders of the TUI objects, selecting which object needs to be used/inputted/outputted to via the console or mouse, probably with tabs or function keys. After the borders are implemented we can implement the text display that way instead of sending dx = location we can simply output things to a specific text box.

Maybe implement expanding/popup/drop down menus in the future.

Memory management currently involves allocating but no deallocation, which means that eventually we'll run out, so we can't be allocating new strings every 10 ms otherwise we may use up the available heap space pretty fast.

\_\_fastcall seems to really be fighting us in C++ rather than C, must figure that out. Tried fastcall, \_\_fastcall, \_\_attribute\_\_((fastcall)) all met with resistance. I was reading an online spat about how \_\_fastcall was actually not any faster than pushing to the stack, I'm a little bit dubious of that since passing arguments via registers has to be faster than using the stack which is ram, unless of course there's something I'm missing, or calls are so expensive that they mask the savings from the register passing. That's separate from trying to get it to work in the first place.

I think we should add some kind of check to ensure that the floppy load worked right. Some kind of checksum should be sufficient.

Soon we might have to write a bit of python to put the sectors onto the floppy correctly. This is because we will be putting things in places that aren't determined by their sector on the drive and the offset from the 0x8000 start.

We also have to think about what to do about the link.ld file. It will be constantly updated and changed. Maybe we can upload a sample version of it, with some explanation of what it's doing but then remove it from the actual git repository/add to .gitignore. This is a small matter.

We also should think about maybe making this dev-journal officially an md format so that it can be read by the git repository.

[For help with the linker error caused by virtual tables](https://forum.osdev.org/viewtopic.php?f=1&t=31529)

21 June 2024
============

Objectives:

*   Get a bit more of the ETUI library working.
*   Test the floppy track-head-sector reading to determine exactly what is stored where.
*   Go back to the PIT and see if we can add some functionality maybe.
*   Do a bit more of the ps2 keyboard driver to get it to the point where we can use it for function keys, arrow keys, etc.
*   Work on the dynamic memory allocation and deallocation to the point where at least it gets freed to be re-used.
*   Get the git-repo to the point where a pull request and make will actually work.
*   Implement a split function in the string class now that array is working.

22 June 2024
============

Keyboard Work
=============

I worked all day over a very small piece of code, not even successfully. But here's what I did accomplish, if we can even call it that. We moved the functionality from constant polling to an IRQ1 which gets called. I created a buffer for the raw scancodes and then a queue of somewhat processed scancodes so that they are separated into quad words for processing. I've learned a few things like that if you type fast enough, a PS2 keyboard will send multiple singleton scancodes at once, forcing you to split them, I assume it can also do this with multi-part scancodes as well. I had too much functionality in the irq handler and we have to keep those functions simple, because they need to be 100% airtight, since any problem with them will cause a GP fault or something like that. Processing these scancodes is kind of complex, since there is also indeterminacy. Just seeing 0xe0 doesn't mean it's 0xe0 + 0xXY where you get one additioanl code, but there's also the printscreen commands which are 0xe0 \[xx\] 0xe0 \[yy\]. Currently it's still not really working perfectly, though thankfully there is a distinction between the arrow keys and keypad, arrow keys use extended codes whereas keypad keys are regular. It was difficult to determine this, and catch all of the bytes being output by the IRQ but we have them now. Processing is still an issue.

I also tried to do some work reconfiguring the PIT, no success there, it seems to tick at the same rate regardless of the reconfiguration parameter I give it. More investigation necessary.

23-26 June 2024
============
Finished a very rudimentary version of dynamic memory so that we can allocate and deallocate space.  Spent a few days reading up on the FAT12/16/32 format for disks and I have opinions of course, but I think I should be able to implement the standard pretty easily.  

Accomplishments in the past few days are:
------------------
*	Built a bit of the FAT C++ code that will handle the file system.  It will be nice because we can then load the drive [hopefully] in another virtual machine and transfer files that way, or examine the files through a known working FAT implementation (windows 98/xp).  
*	Built the virtual memory code that allocates virtual memory.  Currently I have MemoryBlocks which form a linked list of memory allocated spaces.  There are 4 MB allocated currently from 4MB to 8MB in linear memory which should be enough currently.  The limits are hard coded.  I haven't tested the full linked list yet, and there's no advanced garbage collection.  
*	I think I hate the fact that in CPP when you add +i to a pointer it shifts not in bytes but by the sizeof(the underlying thing) \* i;  It's probably convenient for high level programmers but not very convenient for systems programmers who have to make sure everything is in (byte \*)'s to ensure that the shift is correct.  
*	I wanted to create a TUI and also wanted to create the FAT format code but realized that they were probably dependent on new and delete for the TUI I need strings which need dynamic memory and for the FAT formatting process, reading and writing I probably need to allocate a block of memory, so that's why my priority was the memory allocation.  
*	I tried a number of other hex codes for VGA formats to get more lines and columns but no success there.  Much of it just didn't work, or it prevented a screen refresh, or it just locked up before getting into the secondary bootloader.  
*	I just finished up the Array and String classes, so that we can move on to the ETUI.  Now that we have strings we can take care of textboxes and inputs.  As an aside we're getting close to the memory limit of the two track 0's.  We'll have to load another track into memory soon to avoid problems.  The limit is 18,432 bytes per two track block.  C++ is guilty of something like 75% of this code bloat.  

Current Goals
------------------
*	Work on the TUI finally and get something up and running. 
*	Get the FAT32 file system up and running.  Allow the user to format floppy disks in fdb and hard drives in all hard drive slots.  
*	Load and execute programs [maybe starting out in kernel mode]
* 	Figure out paging.
*	Move from kernel to user mode (ring 0->ring 3)
* 	Provide programs with interrupts to make system calls back to kernel mode.  
*	Write the Readme with build instructions. 

2 July 2024
=============
In the intervening time I've been working on the FAT32 file system which is about 50% finished and the TUI which is probably 25% finished.  But I've been working for the past few days on my old pentium 4 computer getting it back into working condition, and I've been successful in loading the bootloader first and second stages, and it will jump to the kernel and give a #GP fault, I was even able to have it print that to me before promptly dying.  

I went back and removed the sti instruction from all of the configuration setup in order to only call it once we are ready to actually handle interrupts.  None of the emulators produce this issue and I'm curious what the problem is.  The floppy drive does not like to write to the disks that I have, meaning either that the disks are all bad or possibly the floppy drive is having write issues.  Either way, I need to come up with a better system for getting the OS into a floppy and then onto the bare metal for actual testing.  I will probably attempt again tomorrow to write the floppy with the newest version of the OS and try again.  It could also be the floppy drive itself generating IRQ6 which may not be set immediately and the floppy IRQ is allowed.   

That's all fixed just now, but the real problem is that when I hexdump a000 in real mode and it should have loaded most of the kernel off the bat, it definitely hasn't done so. Yet more problems with floppy head, track and sector indexing.  This time it's different in QEMU vs a real floppy drive, because I know the data is on the floppy after dumping it back. 

Ok, I've bodged the rest of the tracks and sectors together and loaded them at boot.  Amazingly I've been able to get the current version working (with the exception for whatever reason of the RTC) on my pentium 4 downstairs.  This for me is a great accomplishment, since the real metal was more finicky than all of the emulations.  Even though it's cost me a few days of forward progress on the underlying software, actually running it on a real computer is probably a good sacrifice of time. As I say, the real time clock doesn't work.  You may ask why and I don't know yet, it may have to do with the fact that I pulled the CR2032 battery while I was trying to get the computer to boot again after repeatedly installing a bad ram stick in many different configurations.  But when it's powered on, it shouldn't need the battery, right? We'll find out.

7 July 2024
=============
Ran into hardware problems on the old pcs, should shift back to development until I solve them.  Currently it's the same problems, finishing the ATA-FAT32 driver and getting the eshell text interface working so that we can display data in a far better way.  

I did however finish writing up a new primary stage bootloader for a hard drive, fixed the secondary stage so that it works with both hard drives and floppy disks, write some python scripts which allow the vmdk file we're using to be formatted with fat32 at least in the boot sector and FSI (sector 1 extra info).  The rest of the formatting has yet to be done and actually writing files and directories seems far off but maybe we can get it done quickly.  