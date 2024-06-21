#ifndef __E_TEXT_INPUT_H__
#define __E_TEXT_INPUT_H__

#include "../string.h"
#include "ETUIObject.h"


class ETextInput : public ETUIObject
{
	public:
		inline void setText(const String & new_text);
		inline const String & getText() const;
	private:
		String input_string;		
};

#endif 