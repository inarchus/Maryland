#ifndef __EPROGRESS_BAR__
#define __EPROGRESS_BAR__

#include "ETUIObject.h"


class EProgressBar : public ETUIObject
{
	public:
		unsigned int getCurrent() const;
		unsigned int getMaximum() const;

		void setCurrent(unsigned int new_current);
		void setMaximum(unsigned int new_maximum);
		
		//void redraw();
	private:
		unsigned int current, maximum;
};

#endif