import os
import json
import shutil

file_preamble = """OUTPUT_FORMAT("elf32-i386");
/* We define an entry point to keep the linker quiet. This entry point
 * has no meaning with a bootloader in the binary image we will eventually
 * generate. Bootloader will start executing at whatever is at 0x07c00 
 https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_3.html#SEC17
 */
ENTRY(start);
SECTIONS
{
"""

def read_environment_variables():
    return {
        'real-mode': os.environ.get('ASSEMBLY_OBJECTS_REAL_MODE'),
        'kernel-asm': os.environ.get('ASSEMBLY_OBJECTS_PROTECTED'),
        'kernel-cpp': os.environ.get('CLANG_OBJECTS')
    }


def generate_segment(segment_name, **kwargs):
    data_string = file_string = ''

    if 'data' in kwargs:
        # if we have any other data we'd have to modify this
        data_string = '\n\t\t'.join([f"SHORT({hex(datum)});" for datum in kwargs['data']])

    if 'files' in kwargs:
        file_string = '\n\t\t'.join([f"{f} ({seg});" for f, seg in kwargs['files']])

    address_string = hex(kwargs['address']) if 'address' in kwargs else ''
    align_string = f"ALIGN({hex(kwargs['align'])})" if 'align' in kwargs else ''
    subalign_string = f"SUBALIGN({hex(kwargs['subalign'])})" if 'subalign' in kwargs else ''

    segment_preamble = f"\t{segment_name} {address_string} : {align_string} {subalign_string} {{"

    segment_string = f" {segment_preamble}\n\t\t{data_string}{file_string} \n\t}}"

    return segment_string


def generate_link_file(file_name, linker_json, **options):
    object_files = read_environment_variables()

    # make a backup of the link.ld file in case we screw something up terribly.
    # shutil.copy(file_name, os.path.join('backup', file_name + '.bak'))
    segment_list = []
    segment_list.append(generate_segment('boot-text', address=0x7c00, files=[('boot.o', '.text')]))
    segment_list.append(generate_segment('boot-data', subalign=2, files=[('boot.o', '.data')]))
    segment_list.append(generate_segment('boot-signature', address=0x7dfe, data=[0xaa55]))
    segment_list.append(generate_segment('secondary-bss', address=0x4000, files=[('secondary.o', '.bss')]))

    segment_list.append(generate_segment('secondary', address=0x8000, files=[('secondary.o', '.text'), ('secondary.o', '.data')]))

    kernel_text_files = ([(file_name, '.text') for file_name in object_files['kernel-asm'].split()] +
                         [(file_name, '.text') for file_name in object_files['kernel-cpp'].split()])

    kernel_data_files = ([(file_name, '.data') for file_name in object_files['kernel-asm'].split()] +
                         [(file_name, '.data') for file_name in object_files['kernel-cpp'].split()])

    kernel_bss_files = [(file_name, '.bss') for file_name in object_files['kernel-asm'].split()] + \
                       [(file_name, '.bss') for file_name in object_files['kernel-cpp'].split()]

    segment_list.append(generate_segment('kernel-text', align=0x0200, files=kernel_text_files))
    segment_list.append(generate_segment('kernel-data', subalign=4, files=kernel_data_files))
    segment_list.append(generate_segment('kernel-bss', address=0x200000, files=kernel_bss_files))

    segment_string = '\n'.join(segment_list)

    output_string = f"{file_preamble}{segment_string}\n}}"

    # print(output_string)

    with open(file_name, 'w') as linker_file:
        linker_file.write(output_string)

if __name__ == '__main__':
    generate_link_file('link.ld', 'link.json')
