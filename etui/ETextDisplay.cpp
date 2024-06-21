#include "../string.h"
#include "ETextDisplay.h"


inline String & ETextDisplay::getText()
{
	return display_text;
}

inline void ETextDisplay::setText(char * new_text)
{
	display_text = new_text;
	redraw();
}
