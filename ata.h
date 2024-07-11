#include "memory.h"
#ifndef __ATA_H__
#define __ATA_H__

/*
	Taken from the ATA standard section 7.16 [identify device]
		For virtual machines and virtual drives, most of these don't even seem to be set.  
		ATA strings are strange becauset they're in the "abcdef" == [b, a, d, c, f, e], pairwise swapped, don't forget about that
		The structure here is going to be written to by the assembly code, hopefully populating the correct locations.

		The packed attribute is intended to assure that no alignment or extra bytes are inserted since the data structure returned from the hard drive itself 
			is exactly 512 bytes.  
*/
struct __attribute__((packed)) ATADriveData
{
	word general_configuration;
	word obsolete_01;
	word specific_configuration;
	word obsolete_02[7];
	word serial_number[10];
	word obsolete_03[3];
	word firmware_version[4];
	word model_number[20];
	word max_sectors_drq; // maximum number of logical sectors transferred per DRQ data block
	word trusted_computing;
	word capabilities_01;
	word capabilities_02;
	word obsolete_04[2];
	byte field_check;
	byte free_fall_sensitivity;
	word obsolete_05[5];
	word logical_sectors_per_drq;
	dword logical_sectors_28;
	word obsolete_06;
	word multiword_dma;
	word pio_modes;
	word minimum_multiword_dma_time;
	word recommended_multiword_dma_time;
	word minimum_pio_transfer_time;
	word minimum_pio_iordy_time;
	dword reserved_01;
	word id_packet_device[4];
	word queue_depth;
	word serial_ata_features_76;
	word reserved_02;
	word serial_ata_features_78;
	word serial_ata_features_79;
	word major_version;
	word minor_version;
	word feature_sets[6];
	word ultra_dma_modes;
	word reserved_03[2];
	word current_apm;
	word master_password_id;
	word hardware_reset; // word 93
	word aam_value; // no idea what aam is, but the low byte is the current aam value
	word stream_min_req_size;
	word stream_transfer_time;
	word stream_access_latency;
	dword stream_perf_granularity;
	qword number_of_sectors_lba48;
	word stream_transfer_time_pio;
	word reserved_04;
	word phys_to_log_ratio; // physical setor size / logical sector size 3:0 2^X logical sectors per physical sector
	word inter_seek_delay;
	word world_wide_name[4];
	word reserved_05[5];
	dword logical_sector_size;
	word feature_sets_2[8];
	word obsolete_07;
	word security_status;
	word vendor_specific[31];
	word cfa_power_mode;
	word compact_flash[7];
	word device_nominal_form_factor; // 3:0 Device Nominal Form Factor, whatever the heck that is
	word reserved_06[7];
	word media_serial_number[30]; // ATA string
	word sct_command_transport; 
	word ce_ata[2];
	word alignment;
	dword rwv_sec_count_mode3;
	dword rwv_sec_count_mode2;
	word nv_cache;
	dword nv_cache_size;
	word media_rotation_rate;
	word reserved_07;
	word nv_cache_options;
	word rwv_feature_set;
	word reserved_08;
	word transport_major_version;
	word transport_minor_version;
	word ce_ata_2[10];
	word min_blocks_per_dlm;
	word max_blocks_per_dlm;
	word reserved_09[19];
	word integrity_word;
};

class ATADrive
{
	public:
		ATADrive(byte controller = 0, byte drive = 0);
		inline qword GetSectorCount() const { return num_sectors; }
		
		byte ReadSector(qword sector_number, void * data);
		byte ReadSectors(qword sector_number, void * data, dword read_size);
		byte WriteSector(qword sector_number, void * data);
		byte WriteSectors(qword sector_number, void * data, dword write_size);
		
		ATADriveData * GetDriveData();
		~ATADrive();
	private:
		byte ctrl_drive; // store it together since there can only be two drives per controller with ATA. 
		ATADriveData * drive_data;

		byte selected_drive;
		qword num_sectors;
};

#endif