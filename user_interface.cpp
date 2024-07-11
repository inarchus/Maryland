#include "user_interface.h"
#include "etui/EFrame.h"
#include "ata.h"
#include "msfat.h"
#include "string.h"

extern "C" dword eshell_entry(int rows, int cols);
extern "C" void set_getchar_print(byte);
extern "C" void pit_set_print(byte);
extern "C" void rtc_toggle_display();
extern "C" byte getchar_pressed();
extern "C" void cprintline(const char * out_string, unsigned int position);
extern "C" void print_string(const char * out_string, unsigned int position);

byte run_ata_test()
{
	ATADrive c_drive(0, 0);
	for(int row = 0; row < 16; row++)
	{
		for(int col = 0; col < 8; col++)
		{
			print_hex_dword(((dword *)c_drive.GetDriveData())[row * 8 + col], ((2 + row) << 8) + 9 * col);
		}
	}
	getchar_pressed();
	byte * data = new byte[512];
	c_drive.ReadSector(0, data);
	hex_dump(data);
	getchar_pressed();
	c_drive.ReadSector(1, data);
	hex_dump(data);
	delete [] data;

	return 1;
}

void run_split_test(char * split_string)
{
	const char * top_string = "Running split test: ";
	print_string(top_string, 0x0100);
	
	String new_str(split_string);
	Array<String> split_array = new_str.Split();
	for(int i = 0; i < split_array.size(); i++)
	{
		print_string(split_array[i].GetCString(), ((i + 2) << 8));
	}
	
}

dword eshell_entry(int rows, int cols)
{
	EShellTextUI shell(rows, cols, 4);
	return shell.run();
}

EShellTextUI::EShellTextUI(int rows, int cols, int color_bits)
	: n_rows(rows), n_cols(cols), n_color_bits(color_bits)
{

}

dword EShellTextUI::run()
{
	msfat::FATPartition fp(0, 0);
	fp.ExperimentalFunction(3, 6);
	
	set_getchar_print(0);
	pit_set_print(0);
	rtc_toggle_display();
	
	EFrame f1 = EFrame();
	EFrame f2 = EFrame();
	f1.setRPosition(0);
	f1.setCPosition(0);
	f1.setRSize(10);
	f1.setCSize(30);
	f1.setBackgroundColor(0b0010);	// green
	f1.setTextColor(0b0101);		// 
	f1.setVisible(true);


	f2.setRPosition(10);
	f2.setCPosition(40);
	f2.setRSize(20);
	f2.setCSize(40);
	f1.setBackgroundColor(0b1011);	// magenta?
	f1.setTextColor(0b0111);		// light grey
	f2.setVisible(true);

	
	f1.redraw();
	f2.redraw();

	getchar_pressed();

	rtc_toggle_display();
	set_getchar_print(3);	// 3 = 1 | 2 = turn on ascii print and scancode.  
	pit_set_print(1);
	
	return 0;
}