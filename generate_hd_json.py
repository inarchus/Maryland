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
import sys
import json

BOOT_SECTORS = 8


def safe_input(prompt, cast_type, value_check):
    found_value = False
    in_value = None
    while not found_value:
        try:
            in_value = input(prompt)
            found_value = value_check(in_value)
        except ValueError:
            print('Incorrect Data Type, retry...')
    return cast_type(in_value)


def get_drive_parameters(cylinders, heads, sectors):
    total_sectors_32 = cylinders * heads * sectors  # this needn't be asked it can be computed
    hd_parameters = {'total_sectors_16': 0, 'hidden_sectors': 0, 'heads': heads, 'cylinders': cylinders,
                     'total_sectors_32': total_sectors_32, 'extended_flags': 0, 'fsinfo_sector': 1}

    print(
        f"The current drive has {cylinders} cylinders, {heads} heads, {sectors} sectors per cylinder-head, for {total_sectors_32} total sectors on the drive.")

    bytes_per_sector = safe_input('Enter the number of bytes per sector, 0 if unsure, 512 is default: ',
                                  lambda x: int(x), lambda x: x == '' or int(x) >= 0)
    if bytes_per_sector == 0:
        bytes_per_sector = 512
    hd_parameters['bytes_per_sector'] = bytes_per_sector

    sectors_per_cluster = safe_input(
        "Enter the number of sectors per cluster, 1 is default, but can be a power of 2 (1, 2, 4, 8, 16, 32): ",
        lambda x: int(x), lambda x: any(2 ** i == int(x) for i in range(10)))
    reserved_sectors = safe_input(
        "Enter the number of reserved sectors, to appear after the 8 required boot sectors before the first file allocation table: ",
        lambda x: int(x), lambda x: int(x) >= 0)
    num_fa_tables = safe_input(
        "Enter the number of File Allocation Tables FATs (the place where the locations of files and directories are stored) 1 is required, more than that is for redundancy and disk recovery in the event of failure or other problems: ",
        lambda x: int(x), lambda x: int(x) >= 1)

    hd_parameters['sectors_per_cluster'] = sectors_per_cluster
    hd_parameters['reserved_sectors'] = reserved_sectors
    hd_parameters['num_fa_tables'] = num_fa_tables

    num_clusters = total_sectors_32 // sectors_per_cluster
    # calculate me
    fat_table_sector_size = (4 * num_clusters) // bytes_per_sector
    if (4 * num_clusters) % bytes_per_sector:
        fat_table_sector_size += 1
    hd_parameters['fat32_table_size'] = fat_table_sector_size

    hd_parameters['sectors_per_track'] = sectors

    root_cluster_sector = BOOT_SECTORS + reserved_sectors + num_fa_tables * fat_table_sector_size
    root_cluster = root_cluster_sector // sectors_per_cluster + (1 if root_cluster_sector % sectors_per_cluster else 0)
    hd_parameters['root_cluster'] = root_cluster
    print(f'The root cluster will be located at {root_cluster} sectors from the start of the drive')
    bios_drive_number = safe_input(
        "Is this drive the primary or secondary on the IDE ribbon? [p/primary] or [s/secondary]: ",
        lambda x: '0x80' if x.lower() in ['p', 'primary'] else '0x00',
        lambda x: x in ['p', 's', 'primary', 'secondary'])
    hd_parameters['bios_drive_number'] = bios_drive_number

    set_serial_name_signature = False

    drive_serial = safe_input(
        "Enter the serial number of the drive (a 32 bit unsigned number) or zero if no serial number: ",
        lambda x: int(x), lambda x: 2 ** 32 > int(x) >= 0)
    if drive_serial != 0:
        hd_parameters['serial_number'] = hex(drive_serial)
        set_serial_name_signature = True
    drive_name = safe_input("Enter a name for the drive at most 11 characters: ", lambda x: x, lambda x: True)[0:11]
    if drive_name:
        hd_parameters['volume_name'] = f"\'{drive_name}\'"
        set_serial_name_signature = True
    else:
        hd_parameters['volume_name'] = "UnnamedVol."
    if set_serial_name_signature:
        hd_parameters['extended_boot_sig'] = '0x29'
    return hd_parameters


if __name__ == '__main__':
    json_filename = sys.argv[1]
    c, h, s = [int(x) for x in sys.argv[2:5]]
    drive_parameters = get_drive_parameters(c, h, s)
    with open(json_filename, 'w') as json_file:
        json_file.write(json.dumps(drive_parameters, indent=2))
