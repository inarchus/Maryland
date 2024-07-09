#include "memory.h"
#include "string.h"
#include "msfat.h"
#include "ata.h"

extern "C" void memory_copy(void * destination, void * source, dword size);
extern "C" void memory_set(void * block, dword size, byte set_byte);
extern "C" int cstrings_equal(char * str1, char * str2);

#define FAT32_BOOT_SECTOR_SIZE32 	330
#define FAT32_FSI_SECTOR_LOCATION 	1
#define FAT32_VOLUME_LENGTH			11
#define FAT32_BACKUP_BOOT_SECTOR	6
#define FAT32_BYTES_PER_SECTOR 		0x200	// aka 512
#define BASE_SECTORS				8
namespace msfat
{

unsigned int FATPartition::system_sectors = 8;
unsigned int FATPartition::sector_size = 512;

char FAT_STRING[9] = "FAT     "; // needs to be null terminated
char BootSector16::fat_12[9] = FAT12_STRING;
char BootSector16::fat_16[9] = FAT16_STRING;
char BootSector32::fat_32[9] = FAT32_STRING;

FATPartition::FATPartition(byte controller, byte drive)
	: p_ata(new ATADrive(controller, drive))
{
	p_boot_sector = new BootSector32();
	p_fsi = new FileSystemInformation();
	p_ata->ReadSector(0, p_boot_sector);
	p_ata->ReadSector(1, p_fsi);
}

/*
	p_boot_sector: 	a pointer to the BootSector32 which will be populated
	volume_name: 	a string of length 11.
	boot_sector_code:	this is the boot code that we'll load into the boot sector.
	cluster_count: 	number of clusters
	cluster_size: 	size of cluster in sectors [not bytes]
	num_fat_tables: the number of File Allocation Tables.  (2 is traditional, but it can be anything but 0 really)
	volume_id: MS documentation doesn't seem to be very certain about what they even want this to be.  They say to store date and time combined
		so presumably this can be junk data or data of our choosing. 
*/
byte FATPartition::PopulateBootSector32(BootSector32 * p_boot_sector, char * volume_name, byte * boot_sector_code, dword cluster_count, dword cluster_size, dword num_fat_tables, dword reserved_size, dword volume_id)
{
	p_boot_sector->fat_size_16 = 0;
	// copy the boot sector code into the proper location.  Given that it starts at 90 = 0x5a, I think we'll have to adjust the org of any assembly to 0x7c5a
	memory_copy(p_boot_sector->boot_code, boot_sector_code, FAT32_BOOT_SECTOR_SIZE32);
	p_boot_sector->drive_number = 0;
	p_boot_sector->file_system_info = FAT32_FSI_SECTOR_LOCATION;			// this means that the FSI can be found at sector 1.  
	memory_copy(p_boot_sector->volume_label, volume_name, FAT32_VOLUME_LENGTH);				// 11 is hard coded in the standard
	p_boot_sector->volume_id = volume_id;
	memory_copy(p_boot_sector->file_system_type, BootSector32::fat_32, 8);
	p_boot_sector->drive_number = 0x80;						// !!!!!!!!!! CHANGE THIS WHEN WE SUPPORT MULTIPLE HARD DRIVES !!!!!!!!!!
	p_boot_sector->backup_boot_sector = FAT32_BACKUP_BOOT_SECTOR;
	p_boot_sector->bytes_per_sector = FAT32_BYTES_PER_SECTOR; 	// 512 bytes per sector
	p_boot_sector->num_reserved_sectors = reserved_size;
	
	p_boot_sector->root_cluster = 8 + reserved_size + 4 * num_fat_tables * cluster_count;
	p_boot_sector->num_hidden_sectors = 0;		// not sure how this is different from reserved sectors... maybe it's for partitioning?
	p_boot_sector->number_fats = num_fat_tables;
	p_boot_sector->media_type = 0xF8;

	p_boot_sector->num_heads = 0;				// in a perfect world we'll populate this by getting the bios data and saving it during the transition to protected mode. 
	p_boot_sector->sectors_per_cluster = cluster_size;
	
	return 1;
}

byte FATPartition::PopulateBootSector16(BootSector16 * boot_sector, char * volume_name, byte * boot_sector_code, dword cluster_count, dword cluster_size, dword num_fat_tables, dword reserved_size, dword volume_id)
{
	return 1;
}

byte FATPartition::PopulateFileSystemInfo(FileSystemInformation * p_fsi, dword cluster_count, dword cluster_size, dword num_fat_tables, dword reserved_size)
{
	dword fat_sector_size = 4 * cluster_count / 512 + (cluster_count % 512 ? 1 : 0);
	dword fat_cluster_size = fat_sector_size / cluster_size + (fat_sector_size % cluster_size ? 1 : 0);
	dword base_clusters = BASE_SECTORS / cluster_size + (BASE_SECTORS % cluster_size ? 1 : 0);
	// the first free cluster is after the last cluster of the last FileAllocTable
	p_fsi->next_free_cluster = base_clusters + reserved_size + num_fat_tables * fat_cluster_size; 
	p_fsi->free_cluster_count = cluster_count - p_fsi->next_free_cluster; // same calculation. 
	return 1;
}

/*
	FATPartition::FormatDrive
	
	
*/
byte FATPartition::FormatDrive(byte fat_type, char * volume_name, byte * boot_sector_code, dword cluster_count, word cluster_size, byte num_fat_tables, word reserved_size, dword volume_id)
{
	BootSector * p_boot_sector = nullptr;
	FileSystemInformation * fsi = new FileSystemInformation();
	PopulateFileSystemInfo(fsi, cluster_count, cluster_size, num_fat_tables, reserved_size);
	
	if (fat_type == 32)
	{
		p_boot_sector = new BootSector32();
		PopulateBootSector32((BootSector32*)p_boot_sector, volume_name, boot_sector_code, cluster_count, cluster_size, num_fat_tables, reserved_size, volume_id);
	}
	else // fat 12 or fat 16 are the same just depending on the sectors, we can configure BootSector16 to the right settings for FAT12.  
	{
		// do not run this 
		p_boot_sector = new BootSector16();
		PopulateBootSector16((BootSector16*)p_boot_sector, volume_name, boot_sector_code, cluster_count, cluster_size, num_fat_tables, reserved_size, volume_id);
	}
	
	p_ata->WriteSector(0, p_boot_sector);		// put the boot sector at sector 0
	p_ata->WriteSector(1, fsi);		// file system information at sector 1
	p_ata->WriteSector(6, p_boot_sector);		// backup BPB, sector 6, microsoft says 0 or 6, don't know if this could be set to any other value.  
	p_ata->WriteSector(7, fsi);		// backup file system information at sector 7
	
	dword fat_table_clusters = (sizeof(dword) * cluster_count) / (sector_size * cluster_size);
	if ((sizeof(dword) * cluster_count) % (sector_size * cluster_size))
		fat_table_clusters++; // increment by one if we need an additional sector to store the f.a.t. 
	
	dword system_clusters = system_sectors / cluster_size + (system_sectors % cluster_size ? 1 : 0);
	dword reserved_clusters = reserved_size / cluster_size + (reserved_size % cluster_size ? 1 : 0);
	for(int i = 0; i < num_fat_tables; i++)
	{
		dword fat_location = system_clusters + reserved_clusters + i * num_fat_tables * fat_table_clusters;
		CreateFileAllocationTable(fat_location, fat_table_clusters, cluster_size);
	}
	
	CreateRootDirectory();

	delete [] p_boot_sector;
	return 1;
}

byte FATPartition::CreateRootDirectory()
{
	return 0;
}


/*
	FATPartition::CreateFileAllocationTable
	This is a helper function for FormatDrive which will allow us to set to zero all of the sectors 
		in the File Allocation Table copy specified by the sector counts.
	Actually creating the fat partitions are pretty simple, all we need to do is zero out the entire table. 
	
	cluster_size is in sectors [512 byte blocks]
*/
byte FATPartition::CreateFileAllocationTable(dword fat_location, dword fat_table_clusters, dword cluster_size)
{
	byte * zero_memory = new byte[cluster_size];
	memory_set(zero_memory, cluster_size, 0);
	
	for(qword sector = fat_location; sector < fat_location + fat_table_clusters; sector++)
	{
		p_ata->WriteSector(sector, zero_memory);
	}
	delete [] zero_memory;
    return 1;
}

dword FATPartition::CreateDirectory(String path)
{
	return 0;
}

dword FATPartition::DeleteDirectory(String path)
{
	return 0;
}

FATPartition::~FATPartition()
{
	delete p_boot_sector;
	delete p_fsi;
}

}