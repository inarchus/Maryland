#ifndef __E_TEXT_DISPLAY_H__
#define __E_TEXT_DISPLAY_H__

#include "../string.h"
#include "ETUIObject.h"

class ETextDisplay : public ETUIObject
{
	public:
		inline String & getText();
		inline void setText(char * new_text);
	private:
		String display_text;
};

#endif