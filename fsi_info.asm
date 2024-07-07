; FileSystemInformation format

section .fsidata
	dd 0x41615252
	times (480 - $) db 0
	dd 0x61417272
	dd {fsi_free_count}
	dd {fsi_next_free_cluster}
	dd 0,0,0
	dd 0xaa550000