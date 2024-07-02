#include "ata.h"

ATADrive::ATADrive(byte drive)
{

}

byte ATADrive::ReadSector(qword sector_number, void * data)
{
    return 1;
}
byte ATADrive::ReadSectors(qword sector_number, dword read_size, void * data)
{
    return 1;
}
byte ATADrive::WriteSector(qword sector_number, void * data)
{
    return 1;
}
byte ATADrive::WriteSectors(qword sector_number, dword write_size, void * data)
{
    return 1;
}