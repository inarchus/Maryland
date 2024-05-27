/*

*/

extern int strings_equal(char * string1, char * string2);
extern void cgetline(char * in_string, int position);
extern void cprintline(char * out_string, int position);

void main_shell(char * in_string)
{
	int position = 0;
	while(1)
	{
		// blank the line out
		cprintline(" ", 0x1700);
		cgetline(in_string, 0x1700);
		cprintline(in_string, position);
		position += 0x01 << 8;
		if (position >> 8 == 0x17)
		{
			position = 0;
		}
	}
}

