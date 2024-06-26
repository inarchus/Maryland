#include "msfat.h"

class ATADrive
{
	public:
		ATADrive(byte drive);
		dword GetSectorCount() const;
		
		byte ReadSector(qword sector_number, byte * data);
		byte ReadSectors(qword sector_number, byte * data);
		byte WriteSector(qword sector_number, byte * data);
		byte WriteSectors(qword sector_number, byte * data);
		
	private:
		byte selected_drive;
		qword num_sectors;		
};