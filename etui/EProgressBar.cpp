#include "EProgressBar.h"

unsigned int EProgressBar::getCurrent() const 
{
	return current;
}
unsigned int EProgressBar::getMaximum() const 
{
	return maximum;
}

void EProgressBar::setCurrent(unsigned int new_current)
{
	current = new_current;
}

void EProgressBar::setMaximum(unsigned int new_maximum)
{
	maximum = new_maximum;
}