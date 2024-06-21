#include "EButton.h"

EButton::EButton(EButtonPressCallback _callback)
	: callback(_callback)
{

}

inline void EButton::setCallback(EButtonPressCallback new_callback)
{
	callback = new_callback;
}

inline EButtonPressCallback EButton::getCallback() const
{
	return callback;
}

void EButton::press(/* Implement button press event eventually */)
{
	callback();
}