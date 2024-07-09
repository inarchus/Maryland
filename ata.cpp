#include "ata.h"

extern "C" word __fastcall ata_is_ready(byte controller);
extern "C" byte __fastcall ata_write_sector_lba(dword controller_drive, dword num_sectors, qword starting_sector, void * write_data);
extern "C" byte __fastcall ata_read_sector_lba(dword controller_drive, dword num_sectors, qword starting_sector, void * read_data);
extern "C" byte __fastcall ata_identify_drive(byte controller_and_drive, ATADriveData * p_drive_data);

ATADrive::ATADrive(byte b_controller, byte b_drive)
    : ctrl_drive((b_controller << 1) | (b_drive & 1))
{
    // check to make sure the drive is valid, identify the drive as best we can
    drive_data = new ATADriveData; // 512 bytes actually but traditionally arranged in words
    if (!ata_identify_drive(ctrl_drive, drive_data))
    {
        ctrl_drive = 0xff;      // set the controller and drive to a sentinel value to indicate that the drive doesn't exist. 
        delete [] drive_data;
    }
    // set up the drive for reading and writing.  
}

ATADrive::~ATADrive()
{
    delete [] drive_data;
}

ATADriveData * ATADrive::GetDriveData()
{
    return drive_data;
}

byte ATADrive::ReadSector(qword sector_number, void * data)
{
    if(ctrl_drive != 0xff)
    {
        ata_read_sector_lba(ctrl_drive, sector_number, 1, data);
    }
    return 1;
}
byte ATADrive::ReadSectors(qword sector_number, dword read_size, void * data)
{
    if(ctrl_drive != 0xff)
    {
        ata_read_sector_lba(ctrl_drive, sector_number, read_size, data);
    }
    return 1;
}
byte ATADrive::WriteSector(qword sector_number, void * data)
{
    if(ctrl_drive != 0xff)
    {
        ata_write_sector_lba(ctrl_drive, sector_number, 1, data);
    }
    return 1;
}
byte ATADrive::WriteSectors(qword sector_number, dword write_size, void * data)
{
    if(ctrl_drive != 0xff)
    {
        ata_write_sector_lba(ctrl_drive, sector_number, write_size, data);
    }
    return 1;
}