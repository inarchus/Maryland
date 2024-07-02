
#include "../string.h"
#include "ETabbedPane.h"



void ETabbedPane::addFrame(const String & title, EFrame & p_frame)
{
	titles.append(title);
	frames.append(p_frame);
	redraw();
}

bool ETabbedPane::removeFrame(const String & title)
{
	bool found = false;
	for(int i = 0; i < titles.size(); i++)
	{
		if(title == titles[i])
		{
			found = true;
		}
		if(found)
		{
			frames[i] = frames[i + 1];
		}
	}
	if(found) 
	{
		//frames.pop_back();
		//titles.pop_back(); -- first implement that... 
	}
	return found;
}

void ETabbedPane::redraw()
{
	drawTabs();
	frames[selected_index].redraw();
}

void ETabbedPane::drawTabs()
{
	for(int i = 0; i < titles.size(); i++)
	{
		drawString();
		drawString(); // separator
	}
	drawBorder();
}