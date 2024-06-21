#include "../string.h"
#include "ETextInput.h"

inline void ETextInput::setText(const String & new_text)
{
	input_string = new_text;
	redraw();
}

inline const String & ETextInput::getText() const
{
	return input_string;
}
