#ifndef __MSFAT_H__
#define __MSFAT_H__

#include "string.h"
#include "array.h"
#include "ata.h"

/*

	Implementation of the FAT32 standard, and perhaps Fat 12 and 16 if we have the time and get 32 working.  
	
	The data was procured from FMicrosoft FAT Specification, August 30, 2005.  

		Understanding provided by: https://www.pjrc.com/tech/8051/ide/fat32.html
		The picture there explained what microsoft did not, which was how these various parts are actually placed on the drive, and how the FAT works precisely.  
		MS Documentation explains how the data structures are formatted, but is missing large conceptual parts which would actually explain how files are stored, how
			directories are stored, what a "File Allocation Table" actually is, they have no examples and only a very vague description.  

*/
namespace msfat
{
	typedef unsigned char byte;
	typedef unsigned short int word;
	typedef unsigned int dword;
	typedef unsigned long long qword;

	#define FAT12_STRING "FAT12   "; // needs to be null terminated
	#define FAT16_STRING "FAT32   "; // needs to be null terminated
	#define FAT32_STRING "FAT32   "; // needs to be null terminated

	struct BootSector {};

	struct BootSector16 : public BootSector
	{
		BootSector16() 
			: reserved_1(0), signature(0xaa55)
		{}
		
		byte jump_code_1; 		// either 0xEB or 0xE9
		byte jump_address;		// byte address to jump inside of the bootsector.
		byte jump_code_2;		// 
		char oem_name[8];
		word bytes_per_sector;
		byte sectors_per_cluster;	// must be powers of 2 from 1 to 128
		word num_reserved_sectors;
		byte number_fats;			//fat = file allocation table, recommended 2
		word root_entry_count;		// for fat 32 = 0, for fat12, fat16 root_entry_count * 32 should by a multiple of bytes_per_sector
		word total_sectors;
		byte media_type;			//The legal values for this field are 0xF0, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, and 0xFF. 
									//0xF8 is the standard value for “fixed” (non-removable) media. For removable media, 0xF0 is frequently used.
		word fat_size_16;			// fat32 = 0, on fat12/16 it is the 16 bit count of sectors occupied by one FAT.
		word sectors_per_track;		// number of sectors per track as described in the interrupt 0x13
		word num_heads; 			// number of heads as described in the interrupt 0x13
		dword num_hidden_sectors;	// Count of hidden sectors preceding the partition that contains this FAT volume. This field is generally only relevant for media visible on interrupt 0x13.
		dword total_sectors_32;		// 32 bit count of the number of total sectors on the volume.
		byte drive_number;			// set to either 0x80 or 0x00 depending on int 0x13
		byte reserved_1;			// set to 0
		byte boot_signature;		// extended boot signature. Set value to 0x29 if either of the following two fields are non-zero.
		dword volume_id;			// volume serial number
		char volume_label[11];			// 11 byte string.  
		char file_system_type[8];	// either "FAT12   " or "FAT16   " or "FAT     " [space padded]
		byte boot_code[448];		// MS specification says to set this to zero, but that would go against other parts of the documentation where it says this is where to store the boot code.  
		word signature;
		
		static char fat_12[9];
		static char fat_16[9];
	};

	struct BootSector32 : public BootSector
	{
		BootSector32() 
			: reserved_1(0), fat_size_16(0), signature(0xaa55)
		{}
		
		byte jump_code_1; 		// either 0xEB or 0xE9
		byte jump_address;		// byte address to jump inside of the bootsector.
		byte jump_code_2;		// 
		char oem_name[8];
		word bytes_per_sector;
		byte sectors_per_cluster;	// must be powers of 2 from 1 to 128
		word num_reserved_sectors;
		byte number_fats;			//fat = file allocation table, recommended 2
		word root_entry_count;		// for fat 32 = 0, for fat12, fat16 root_entry_count * 32 should by a multiple of bytes_per_sector
		word total_sectors;
		byte media_type;			//The legal values for this field are 0xF0, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, and 0xFF. 
									//0xF8 is the standard value for “fixed” (non-removable) media. For removable media, 0xF0 is frequently used.
		word fat_size_16;			// fat32 = 0, on fat12/16 it is the 16 bit count of sectors occupied by one FAT.
		word sectors_per_track;		// number of sectors per track as described in the interrupt 0x13
		word num_heads; 			// number of heads as described in the interrupt 0x13
		dword num_hidden_sectors;	// Count of hidden sectors preceding the partition that contains this FAT volume. This field is generally only relevant for media visible on interrupt 0x13.
		dword total_sectors_32;		// 32 bit count of the number of total sectors on the volume.
		// byte 36 where it diverges from the 12/16 style boot sector.  
		dword fat_size_32;			// number of sectors occupied by one FAT.  , set the fat_size_16(0)
		word extended_flags;		// 0-3 = zero based number of active FAT.  4-6 reserved, 7 = [0 = fat is mirrored at runtime into all fats, 1 = only one fat is active, referenced in 0-3]
									// bits 8-15 reserved, no idea what this actually means
		word file_system_version;	// high byte is major rev. number, lower byte is minor.  
		dword root_cluster;			// set to the cluster number of the first cluster of the root directory.  <--
		word file_system_info;		// sector of the FileSystemInformation structure, set to 1
		word backup_boot_sector;	// sector of the backup FSI. 0 if it doesn't exist, 6 if it's in sector 6
		dword reserved[3];			// set to zero.

		byte drive_number;			// set to either 0x80 or 0x00 depending on int 0x13
		byte reserved_1;			// set to 0
		byte boot_signature;		// extended boot signature. Set value to 0x29 if either of the following two fields are non-zero.
		dword volume_id;			// volume serial number
		char volume_label[11];			// 11 byte string.  
		char file_system_type[8];	// either "FAT12   " or "FAT16   " or "FAT     " [space padded]

		byte boot_code[420];		// MS specification says to set this to zero, but that would go against other parts of the documentation where it says this is where to store the boot code.  
		word signature;
		
		static char fat_32[9];
	};
	
	
	/*
		The FSInfo structure is only present on volumes formatted FAT32. The structure must be
		persisted on the media during volume initialization (format). The structure must be located at
		sector #1 – immediately following the sector containing the BPB.
		
		A copy of the structure is maintained at sector #7.
	*/
	struct FileSystemInformation
	{
		public:
			FileSystemInformation()
				: lead_signature(0x41615252), structure_signature(0x61417272),
				  free_cluster_count(0xFFFFFFFF), next_free_cluster(0xFFFFFFFF),  // these indicate there's no information on the next free cluster. 
				  trail_signature(0xaa550000)
			{
				for(int i = 0; i < 480; i++)
					reserved_block_1[i] = 0;
				for(int j = 0; j < 12; j++)
					reserved_block_2[j] = 0;
			}
			dword lead_signature;
			byte reserved_block_1[480];
			dword structure_signature;
			dword free_cluster_count;
			dword next_free_cluster;
			byte reserved_block_2[12];	
			dword trail_signature;
	};

	enum DirectoryAttribute {ATTR_READ_ONLY = 0x01, ATTR_HIDDEN = 0x02, ATTR_SYSTEM = 0x04, ATTR_VOLUME_ID = 0x08, ATTR_DIRECTORY = 0x10, ATTR_ARCHIVE = 0x20};

	struct __attribute__((packed)) FileDescriptor
	{
		public:
			FileDescriptor() : nt_reserved(0) {}
			inline bool IsReadOnly() {return attributes & ATTR_READ_ONLY; }
			inline bool IsHidden() {return attributes & ATTR_HIDDEN; }
			inline bool IsSystem() {return attributes & ATTR_SYSTEM; }
			inline bool IsDirectory() {return attributes & ATTR_DIRECTORY; }
			inline bool IsModified() {return attributes & ATTR_ARCHIVE; } // use modified rather than archive because it doesn't make sense without explanation.
			inline bool HasVolumeID() {return attributes & ATTR_VOLUME_ID; }
			inline String GetName() {return String(name); }
			inline dword GetStartingCluster() { return (starting_cluster_high_word << 16) + starting_cluster_low_word; }
			FileDescriptor & operator = (const FileDescriptor & rhs);
			char name[11]; // 8.3 format adding up to 11 characters total
			byte attributes;
			byte nt_reserved;
			byte creation_time_tenths; 	// value between 0 <= tenths <= 199
			word creation_time;
			word creation_date;
			word last_access_date;
			word starting_cluster_high_word;	// 
			word modified_time;
			word modified_date;
			word starting_cluster_low_word;		// 
			dword size;							// size in bytes of the directory described, unknown exactly how this is to be calculated
	};

	class DirectoryInformation : private FileDescriptor
	{
		public:
			inline bool IsReadOnly() const {return attributes & ATTR_READ_ONLY; }
			inline bool IsHidden() const {return attributes & ATTR_HIDDEN; }
			inline bool IsSystem() const {return attributes & ATTR_SYSTEM; }
			inline bool IsDirectory()const  {return attributes & ATTR_DIRECTORY; }
			inline bool IsModified() const {return attributes & ATTR_ARCHIVE; } // use modified rather than archive because it doesn't make sense without explanation.
			inline bool HasVolumeID() const {return attributes & ATTR_VOLUME_ID; }
			inline String GetName() {return String(name); }
			inline void AddTableEntry(FileDescriptor * p_fd) { descriptors.append(*p_fd); }
			inline FileDescriptor & operator[] (int index) {return descriptors[index]; }
			inline unsigned int size() const {return descriptors.size(); }
			inline dword GetStartingCluster() const { return (starting_cluster_high_word << 16) + starting_cluster_low_word; }
		private:
			// inherits the data from a FileDescriptor object (32 bytes)
			Array<FileDescriptor> descriptors;
	};

	class FileStream;

	class FATPartition
	{
		public:
			FATPartition(byte controller = 0, byte drive = 0);
			byte FormatDrive(byte fat_type, char * volume_name, byte * boot_sector_code, dword cluster_count, word cluster_size, byte num_fat_tables, word reserved_size, dword volume_id);
			inline dword GetSectorCount() const { return q_sectors; }
			
			dword CreateFile(String path);
			dword WriteFile(String path);
			dword DeleteFile(String path);
			dword ReadFile(String path);
			
			qword GetFileSize(String path);
			
			dword CreateDirectory(String path, String directory_name);
			dword DeleteDirectory(String path);
			
			dword ReadDirectoryStructure(DirectoryInformation & current_directory, const String & path);
			dword ParseDirectoryInformation(DirectoryInformation & dir_info, dword cluster);
			
			FileStream & OpenFile(String path);
			byte CloseFile(FileStream & fs);
			byte UpdateFreeCount();
			// this function adds a and b, wow.  it's a test to see if we can write an assembly function which essentially "externs" a method of a class.  I think it worked?
			dword ExperimentalFunction(dword a, dword b);
			~FATPartition();
		private:
			byte CreateFileAllocationTable(dword fat_location, dword fat_table_clusters, dword cluster_size);
			byte PopulateBootSector32(BootSector32 * boot_sector, char * volume_name, byte * boot_sector_code, dword cluster_count, dword cluster_size, dword num_fat_tables, dword reserved_size, dword volume_id);
			byte PopulateBootSector16(BootSector16 * boot_sector, char * volume_name, byte * boot_sector_code, dword cluster_count, dword cluster_size, dword num_fat_tables, dword reserved_size, dword volume_id);
			byte PopulateFileSystemInfo(FileSystemInformation * p_fsi, dword cluster_count, dword cluster_size, dword num_fat_tables, dword reserved_size);

			dword ReadCluster(dword cluster, byte * cluster_data);
			dword WriteCluster(dword cluster, byte * cluster_data);
			byte WriteDotDirectories(dword parent_directory_cluster, dword next_free_cluster, FileDescriptor * cluster_data);

			byte AllocateCluster(dword parent_directory_cluster, dword next_free_cluster);
			dword GetNextFreeCluster(dword start_cluster = 0);
			byte CheckClusterFree(dword cluster);

			ATADrive * p_ata; // drive that the partition lives on.

			// perform sanity checks on the boot sector data before assigning it to these variables
			dword cluster_size, bytes_per_sector, sectors_per_cluster, root_cluster;
			byte num_fats;
			dword num_reserved_sectors;

			BootSector * p_boot_sector; 	// we'll read sector 0 and load the sector data here 
			FileSystemInformation * p_fsi;	// we'll also load the file system information here so that we can

			DirectoryInformation current_directory; 

			qword q_sectors;
			
			static unsigned int system_sectors;
			static unsigned int sector_size;
	};
	
	class FileStream 
	{
		public:
			FileStream(String filename, byte permissions);
			byte * Read(dword num_bytes);
			dword Write(byte * bytes_to_write, dword size);
			dword Seek(dword location);
			
			
		private:
			dword read_pointer;
			dword write_pointer;
			byte permissions; // read only, write, append, etc.
	};
}

#endif