#include "user_interface.h"
#include "etui/EFrame.h"
#include "msfat.h"

extern "C" dword eshell_entry(int rows, int cols);
extern "C" void set_getchar_print(byte);
extern "C" void pit_set_print(byte);
extern "C" void rtc_toggle_display();
extern "C" byte getchar_pressed();


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
	msfat::FATPartition fp;
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