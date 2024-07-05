#include "memory.h"
#ifndef __ATA_H__
#define __ATA_H__

class ATADrive
{
	public:
		ATADrive(byte controller = 0, byte drive = 0);
		inline qword GetSectorCount() const { return num_sectors; }
		
		byte ReadSector(qword sector_number, void * data);
		byte ReadSectors(qword sector_number, dword read_size, void * data);
		byte WriteSector(qword sector_number, void * data);
		byte WriteSectors(qword sector_number, dword write_size, void * data);
		
	private:
		byte ctrl_drive; // store it together since there can only be two drives per controller with ATA. 

		byte selected_drive;
		qword num_sectors;
};

#endif