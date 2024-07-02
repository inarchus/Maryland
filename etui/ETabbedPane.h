#ifndef __E_TABBED_PANE_H__
#define __E_TABBED_PANE_H__

#include "../string.h"
#include "ETUIObject.h"

class ETabbedPane : public ETUIObject
{
	public:
		void addFrame(const String & title, EFrame & p_frame);
		bool removeFrame(const String & title);
		virtual void redraw();
		void drawTabs();
	private:
		int selected_index;
		Array<String> titles;
		Array<Frame *> frames;
};

#endif