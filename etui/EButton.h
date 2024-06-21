#ifndef __ETUI_BUTTON_H__
#define __ETUI_BUTTON_H__

#include "ETUIObject.h"

typedef void (*EButtonPressCallback)(void);

class EButton : public ETUIObject
{
	public:
		EButton(EButtonPressCallback _callback = nullptr);
		inline void setCallback(EButtonPressCallback new_callback);
		inline EButtonPressCallback getCallback() const;
		void press();
	private:
		EButtonPressCallback callback;
};

#endif 