#include "EFrame.h"

EFrame::EFrame()
{

}

bool EFrame::addChild(ETUIObject * p_object)
{
	return false;
}

bool EFrame::removeChild(ETUIObject * p_object)
{
	return false;
}

void EFrame::redraw()
{
	
	for(unsigned int i = 0; i < children.size(); i++)
	{
		children[i]->redraw();
	}
}