#include "memory.h"
#include "string.h"
#include "msfat.h"
#include "ata.h"

extern "C" void memory_copy(void * destination, void * source, dword size);
extern "C" void memory_set(void * block, dword size, byte set_byte);
extern "C" int cstrings_equal(char * str1, char * str2);
extern "C" void __fastcall zero_memory(void * p_block, dword size);

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

FileDescriptor & FileDescriptor::operator = (const FileDescriptor & rhs)
{
	for(int i = 0; i < 11; i++)
	{
		name[i] = rhs.name[i];
	}

	attributes = rhs.attributes;
	nt_reserved = rhs.nt_reserved;
	creation_time_tenths = rhs.creation_time_tenths; 	// value between 0 <= tenths <= 199
	creation_time = rhs.creation_time;
	creation_date = rhs.creation_date;
	last_access_date = rhs.last_access_date;
	starting_cluster_high_word = rhs.starting_cluster_high_word;	// 
	modified_time = rhs.modified_time;
	modified_date = rhs.modified_date;
	starting_cluster_low_word = rhs.starting_cluster_low_word;		// 
	size = rhs.size;							// size in bytes of the directory described, unknown exactly how this is to be calculated
	return *this;
}

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

	delete [] p_boot_sector;
	return 1;
}

dword FATPartition::ReadDirectoryStructure(DirectoryInformation & current_directory, const String & path)
{
	Array<String> split_path = path.Split('/');
	bool found_next_step;

	dword next_cluster = ParseDirectoryInformation(current_directory, root_cluster); // need to give the root_cluster number so that 

	for(int i = 0; i < split_path.size(); i++)
	{
		found_next_step = false;
		for(int j = 0; j < current_directory.size(); j++)
		{
			if(current_directory[i].IsDirectory() && current_directory[i].GetName().Lower() == split_path[i].Lower())
			{
				next_cluster = ParseDirectoryInformation(current_directory, current_directory[i].GetStartingCluster()); // need to give the root_cluster number so that we can get there.
				found_next_step = true;
			}
		}
		if(!found_next_step)
		{
			// invalid directory
			break;
		}
	}

	return next_cluster;
}

dword FATPartition::ParseDirectoryInformation(DirectoryInformation & dir_info, dword cluster)
{
	// need to read the initial cluster and also the FAT for the next cluster to read
	// read all clusters in the directory structure, make an array of cluster numbers
	// load the clusters into memory
	byte * cluster_data = new byte[cluster_size];
	dword next_cluster = cluster;

	// any cluster number higher than 0xfffffff8 is considered invalid, any cluster under the root cluster is either in 
	//		a FAT or in the reserved or boot clusters at the start of the drive.
	while(next_cluster < 0xFFFFFFF8 && next_cluster >= root_cluster)
	{
		next_cluster = ReadCluster(cluster, cluster_data);
		for(int i = 0; i < bytes_per_sector * sectors_per_cluster; i+=32)
		{
			dir_info.AddTableEntry((FileDescriptor *)((byte *)cluster_data + i));
		}
	}
	return 1;
}

/*
	Reads a cluster and determines the location of the next cluster in the primary FAT
		We should add the capability to check the secondary FAT in case of problems.
*/
dword FATPartition::ReadCluster(dword cluster, byte * cluster_data)
{
	dword * sector_data = new dword[sector_size / 4];
	// read the sector in the primary FAT that contains the next cluster after this one.
	p_ata->ReadSector(root_cluster * sectors_per_cluster + (cluster * 4) / (bytes_per_sector * sectors_per_cluster), sector_data);
	// read the actual sectors
	p_ata->ReadSectors(cluster * sectors_per_cluster, cluster_data, sectors_per_cluster);
	// this is the location of the next cluster that contains the directory info.  
	return sector_data[(4 * cluster) % (bytes_per_sector * sectors_per_cluster)];
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

dword FATPartition::WriteCluster(dword cluster, byte * cluster_data)
{
	p_ata->WriteSectors(cluster * sectors_per_cluster, cluster_data, sectors_per_cluster);
	return 1;
}

#define CREATE_DIRECTORY_SUCCESS		1
#define DUPLICATE_DIRECTORY 			2
#define CREATE_DIRECTORY_ILLEGAL_NAME	3

dword FATPartition::CreateDirectory(String path, String directory_name)
{
	if(directory_name.Length() > 11)
	{
		return CREATE_DIRECTORY_ILLEGAL_NAME;
	}
	DirectoryInformation dir_info;
	dword last_cluster = ReadDirectoryStructure(dir_info, path);
	for(int i = 0; i < dir_info.size(); i++)
	{
		if (dir_info[i].GetName().Lower() == directory_name.Lower())
		{
			return DUPLICATE_DIRECTORY;
		}
	}
	byte * cluster_data = new byte[cluster_size];
	ReadCluster(last_cluster, cluster_data);
	FileDescriptor * p_fd = (FileDescriptor *)cluster_data;
	dword next_free_cluster = GetNextFreeCluster();
	bool new_slot_found = false;
	for(int dir_segment = 0; dir_segment < cluster_size; dir_segment+=32)
	{
		cluster_data += 1; // go to the next file descriptor
		if(p_fd->GetName()[0] == '\0')
		{
			for(int copy_string = 0; copy_string < 11; copy_string++)
			{
				p_fd->name[copy_string] = directory_name[copy_string];
			}
			p_fd->attributes = ATTR_DIRECTORY;
			p_fd->starting_cluster_high_word = next_free_cluster >> 16;
			p_fd->starting_cluster_low_word = next_free_cluster & 0xFFFF;
			p_fd->size = cluster_size;
			new_slot_found = true;
		}
	}
	dword parent_directory_cluster = dir_info.GetStartingCluster();
	if(!new_slot_found)
	{
		AllocateCluster(parent_directory_cluster, next_free_cluster);
		p_fsi->next_free_cluster = GetNextFreeCluster();
		p_ata->WriteSector(1, p_fsi);
		p_ata->WriteSector(7, p_fsi);
	}	

	zero_memory(cluster_data, cluster_size);
	WriteDotDirectories(parent_directory_cluster, next_free_cluster, (FileDescriptor*)cluster_data);

	// add . and .. to the new directory
	WriteCluster(next_free_cluster, cluster_data);

	delete [] cluster_data;

	return CREATE_DIRECTORY_SUCCESS;
}

dword FATPartition::GetNextFreeCluster(dword start_cluster)
{
	dword next_free_cluster;
	if(!start_cluster)
	{
		next_free_cluster = p_fsi->next_free_cluster;
	}
	else
	{
		next_free_cluster = start_cluster;
	}

	dword starting_fat_sector = ((BootSector32*)p_boot_sector)->num_reserved_sectors;
	dword number_fats = ((BootSector32*)p_boot_sector)->number_fats;
	// first we'll check the sector that the fsi claims to be the next free cluster.
	if(CheckClusterFree(next_free_cluster))
	{
		p_fsi->next_free_cluster = GetNextFreeCluster(next_free_cluster + 1);
		return next_free_cluster;
	}


	// this is actually a little bit messy, first we have to check the FSI if it knows the next available sector.  If it's set incorrectly then we have to recover it.
	// 

	return 0;
}

byte FATPartition::CheckClusterFree(dword cluster)
{	
	// if the cluster is not in the allocatable region, refuse to allocate.
	if(cluster < root_cluster)
	{
		return 0;
	}
	dword * sector_data = new dword[bytes_per_sector / 4];
	// check the cluster in the fat table to see if it's 0x0 or something else.  If it's something else, then it's used.  
	p_ata->ReadSector(num_reserved_sectors + (4 * cluster) / (bytes_per_sector), sector_data);
	
	if(sector_data[(4 * cluster) % bytes_per_sector] == 0x0)
	{
		delete [] sector_data;
		return true;
	}

	delete [] sector_data;
	return false;
}

byte FATPartition::AllocateCluster(dword parent_directory_cluster, dword next_free_cluster)
{
	dword * sector_data = new dword[bytes_per_sector / 4];
	// check the cluster in the fat table to see if it's 0x0 or something else.  If it's something else, then it's used.  
	p_ata->ReadSector(num_reserved_sectors + (4 * parent_directory_cluster) / (bytes_per_sector), sector_data);
	sector_data[(4 * parent_directory_cluster) % bytes_per_sector] = next_free_cluster;
	p_ata->WriteSector(num_reserved_sectors + (4 * parent_directory_cluster) / (bytes_per_sector), sector_data);

	p_ata->ReadSector(num_reserved_sectors + (4 * next_free_cluster) / (bytes_per_sector), sector_data);
	sector_data[(4 * next_free_cluster) % bytes_per_sector] = 0xffffffff; // this signals the end of the directory or file
	p_ata->WriteSector(num_reserved_sectors + (4 * next_free_cluster) / (bytes_per_sector), sector_data);
	delete [] sector_data;
	return 1;
}


byte FATPartition::WriteDotDirectories(dword parent_directory_cluster, dword next_free_cluster, FileDescriptor * cluster_data)
{

	// ensure that the current cluster is zero.
	for(int i = 64; i < cluster_size; i+=32)
	{
		zero_memory(cluster_data++, 32);
	}
	//WriteCluster();
	return 1;
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