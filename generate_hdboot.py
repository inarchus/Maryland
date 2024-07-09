import json
import sys

"""
This is the boot sector that we'll use for the hard drive.  We'll look to a configuration file passed
    as a command line argument to be a json file containing these details so that we can enter them in. 
    
    We'll open the vmdk file to get the heads, cylinders and sector information.  Then we'll open the json for the rest,
    populate the rest of it, then create the assembly file that will actually be assembled.   

section .bpb_boot_sector
    dw		0xe95a					; jump to position 90 relative
    db		0x90					; nop
    db 		'MARYLAND'				; OEM Name identifier, 8 bytes
    dw		{bytes_per_sector}		; bytes per sector
    db		{sectors_per_cluster}	; sectors per cluster, 4096 bytes per cluster
    dw		{reserved_sectors}		; a reserved sector count
    db		{num_fa_tables}			; num FATs [FAT in this case is File Allocation Table not the entire format]
    dw		{total_sectors_16}		; total sectors of fat12 or fat16, 0 if fat32
    db		0xf8					; magic code bits for hard drive
    dw 		0						; 16-bit count of sectors occupied by one FAT // 0 for fat32.
    dw		{sectors_per_track}		; fill in with python script after reading drive
    dw		{num_heads}				;
    dd		{hidden_sectors}		; hidden sectors,
    dd		{total_sectors_32}		; fat32 total sector count
    dd		{fat32_table_size}		; number of sectors in a fat table
    dw		{extended_flags}		; extended flags
    dw		0						; revision number
    dd		{root_cluster}			; first cluster of the root directory
    dw		1						; fsinfo structure location
    dw		6						; backup boot sector location
    dd		0,0,0					; 12 bytes of reserved 0's
    db		{bios_drive_number}		; either 0x80 or 0x00
    db		0						; reserved byte zero
    db		{extended_boot_sig}		; 0x29 if either of the next two fields are valid
    dd		{serial_number}			;
    db		{volume_name}			; must be 11-byte name of the volume
    db		"FAT32   "				; must be 8 bytes so include the 3 spaces
"""


def get_path_to_vmdk():
    path_to_vmdk = ''
    with open("config.mk") as config_file:
        for line in config_file:
            split_line = line.split('=')
            if len(split_line) >= 2:
                if split_line[0].strip() == "PATH_TO_VMDK_HDA":
                    path_to_vmdk = ''.join(split_line[1].strip().split('\\'))
    return path_to_vmdk


"""
The lines of the file that we need are:
    ddb.geometry.cylinders = "81"
    ddb.geometry.heads = "16"
    ddb.geometry.sectors = "63"
"""
def get_drive_chs_parameters(path_to_vmdk):
    hds = 0
    sec = 0
    cyl = 0
    with open(path_to_vmdk) as vmdk_file:
        for line in vmdk_file:
            split_line = line.split('=')
            if len(split_line) >= 2:
                if split_line[0].strip() == 'ddb.geometry.cylinders':
                    cyl = int(split_line[1].strip().strip("\""))
                elif split_line[0].strip() == 'ddb.geometry.heads':
                    hds = int(split_line[1].strip().strip("\""))
                elif split_line[0].strip() == 'ddb.geometry.sectors':
                    sec = int(split_line[1].strip().strip("\""))

    return cyl, hds, sec


def write_final_assembly(hd_dict):
    result_code = ''
    with open('hdboot.asm') as boot_assembly_file:
        assembly_code = boot_assembly_file.read()
        result_code = assembly_code.format(**hd_dict)
    if not result_code:
        print("Unable to write the hdboot.asm assembly file")
        return
    with open('hdboot_final.asm', 'w') as hdboot_code_file:
        hdboot_code_file.write(result_code)
    print('Configured hdboot')


def configure_hd_values(vmdk_json_path, cylinders, heads, sectors):
    with open(vmdk_json_path) as vmdk_json_file:
        hd_values = json.loads(vmdk_json_file.read())
        hd_values['cylinders'] = cylinders
        hd_values['heads'] = heads
        hd_values['sectors'] = sectors

    return hd_values



if __name__ == '__main__':
    print(sys.argv)
    try:
        vmdk_path = get_path_to_vmdk()
        cylinders, heads, sectors = get_drive_chs_parameters(vmdk_path)
        drive_values = configure_hd_values(sys.argv[1], cylinders, heads, sectors)
        print(drive_values)
        write_final_assembly(drive_values)
    except FileNotFoundError as the_error:
        print(the_error)
    except ValueError as val_error:
        print(val_error, "One of the cylinder, head or sector values was most likely faulty. ")
