#include "memory.h"
#include "string.h"
#include "msfat.h"

namespace msfat
{

/*
	FATPartition::FormatDrive
	
	
*/
byte FATPartition::FormatDrive(byte fat_type, dword cluster_count, word cluster_size, byte num_fat_tables, word reserved_size)
{
	byte * boot_sector = nullptr;
	FileSystemInformation fsi;
	PopulateFileSystemInfo(&fsi, fat_type, cluster_count, cluster_size, num_fat_tables, reserved_size);
	
	if (fat_type == FAT32)
	{
		boot_sector = new BootSector32();
		PopulateBootSector32(boot_sector, cluster_count, cluster_size, num_fat_tables, reserved_size);
	}
	else // fat 12 or fat 16 are the same just depending on the sectors, we can configure BootSector16 to the right settings for FAT12.  
	{
		boot_sector = new BootSector16();
		PopulateBootSector16(boot_sector, fat_type, cluster_count, cluster_size, num_fat_tables, reserved_size);
	}
	
	p_ata->WriteSector(0, boot_sector);		// put the boot sector at sector 0
	p_ata->WriteSector(1, &fsi);		// file system information at sector 1
	p_ata->WriteSector(6, boot_sector);		// backup BPB, sector 6, microsoft says 0 or 6, don't know if this could be set to any other value.  
	p_ata->WriteSector(7, &fsi);		// backup file system information at sector 7
	
	fat_table_sectors = (sizeof(dword) * cluster_count) / sector_size;
	if ((sizeof(dword) * cluster_count) % sector_size)
		fat_table_sectors++; // increment by one if we need an additional sector to store the f.a.t. 
	
	for(int i = 0; i < num_fat_tables; i++)
	{
		unsigned qword fat_location = system_sectors + i * num_fat_tables * fat_table_sectors;
		CreateFileAllocationTable(fat_location, fat_table_sectors);
	}
	
	delete boot_sector;
}

/*
	FATPartition::CreateFileAllocationTable
	This is a helper function for FormatDrive which will allow us to set to zero all of the sectors 
		in the File Allocation Table copy specified by the sector counts.
	Actually creating the fat partitions are pretty simple, all we need to do is zero out the entire table. 
*/
byte FATPartition::CreateFileAllocationTable(fat_location, fat_table_sectors)
{
	byte * zero_memory = new byte[sector_size];
	ZeroMemory(zero_memory, sector_size);
	
	for(qword sector = fat_location; sector < fat_table_sectors + fat_table_sectors; sector++)
	{
		p_ata->WriteSector(sector, zero_memory);
	}
	delete zero_memory;
}
	
}