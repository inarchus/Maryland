#ifndef __E_FRAME_H__
#define __E_FRAME_H__

#include "../string.h"
#include "../array.h"
#include "ETUIObject.h"

class EFrame : public ETUIObject
{
	public:
		EFrame();
		bool addChild(ETUIObject * p_object);
		bool removeChild(ETUIObject * p_object);
		
		void drawBackground();
		virtual void drawBorder();
		virtual void redraw();

	private:
		Array<ETUIObject *> children;
};

#endif