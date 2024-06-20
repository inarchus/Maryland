#include "ETUIObject.h"


ETUIObject::ETUIObject()
	: row_position(0), col_position(0), row_size(10), col_size(10), visible(false), p_parent(nullptr), base_pointer(this)
{

}

inline bool ETUIObject::getVisible() const
{
	return visible;
}

unsigned int ETUIObject::getRPosition() const
{
	return row_position;
}

unsigned int ETUIObject::getCPosition() const
{
	return col_position;
}

unsigned int ETUIObject::getRSize() const
{
	return row_size;
}

unsigned int ETUIObject::getCSize() const
{
	return col_size;
}

void ETUIObject::redraw()
{
	// blank stub because this object is a default basic object.  Could make it abstract if we wanted to...
	// base_pointer->redraw();
}

bool ETUIObject::setVisible(bool new_visible)
{
	redraw();
	visible = new_visible;
	return visible;
}

unsigned int ETUIObject::setRPosition(unsigned int new_row)
{
	redraw();
	row_position = new_row;
	return row_position;
}

unsigned int ETUIObject::setCPosition(unsigned int new_col)
{
	redraw();
	col_position = new_col;
	return col_position;
}

unsigned int ETUIObject::setRSize(unsigned int new_row_size)
{
	redraw();
	row_size = new_row_size;
	return row_size;
}

unsigned int ETUIObject::setCSize(unsigned int new_col_size)
{
	redraw();
	col_size = new_col_size;
	return col_size;
}

ETUIObject * ETUIObject::GetParent() const
{
	return p_parent;
}

void ETUIObject::SetParent(ETUIObject * p_new_parent)
{
	p_parent = p_new_parent;
}
