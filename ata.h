#include "memory.h"
#ifndef __ATA_H__
#define __ATA_H__

class ATADrive
{
	public:
		ATADrive(byte drive);
		inline qword GetSectorCount() const { return num_sectors; }
		
		byte ReadSector(qword sector_number, void * data);
		byte ReadSectors(qword sector_number, dword read_size, void * data);
		byte WriteSector(qword sector_number, void * data);
		byte WriteSectors(qword sector_number, dword write_size, void * data);
		
	private:
		byte selected_drive;
		qword num_sectors;
};

#endif