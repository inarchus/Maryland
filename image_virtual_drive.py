"""
    This is a basic attempt at getting the boot sector coded properly, we'll then code in the secondary bootloader
        and then load the kernel.



"""

import sys


def format_boot_sectors(vmdk_filename):
    with open(vmdk_filename, 'rb+') as vmdk_file:
        vmdk_file.seek(0, 0)
        with open('hdboot.bin', 'rb') as hdboot_file:
            boot_sector_data = hdboot_file.read()
        with open('fsi_info.bin', 'rb') as fsi_file:
            fsi_data = fsi_file.read()
        
        # write to sectors 0 and 1
        vmdk_file.write(boot_sector_data)
        vmdk_file.write(fsi_data)
        
        # write to sectors 6 and 7
        vmdk_file.seek(6 * 512, 0)
        vmdk_file.write(boot_sector_data)
        vmdk_file.write(fsi_data)

        with open('hdd_kernel.bin', 'rb') as hdd_bin_file:
            vmdk_file.write(hdd_bin_file.read())

if __name__ == '__main__':
    format_boot_sectors(sys.argv[1])
