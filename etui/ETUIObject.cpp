#include "ETUIObject.h"


ETUIObject::ETUIObject()
	: row_position(0), col_position(0), row_size(10), col_size(10), visible(false), p_parent(nullptr), base_pointer(this)
{

}

inline bool ETUIObject::getVisible() const
{
	return visible;
}

inline unsigned int ETUIObject::getRPosition() const
{
	return row_position;
}

inline unsigned int ETUIObject::getCPosition() const
{
	return col_position;
}

inline unsigned int ETUIObject::getRSize() const
{
	return row_size;
}

inline unsigned int ETUIObject::getCSize() const
{
	return col_size;
}

void ETUIObject::redraw()
{
	// blank stub because this object is a default basic object.  Could make it abstract if we wanted to...
	// base_pointer->redraw();
}

inline bool ETUIObject::setVisible(bool new_visible)
{
	visible = new_visible;
	redraw();
	return visible;
}

inline unsigned int ETUIObject::setRPosition(unsigned int new_row)
{
	row_position = new_row;
	redraw();
	return row_position;
}

inline unsigned int ETUIObject::setCPosition(unsigned int new_col)
{
	col_position = new_col;
	redraw();
	return col_position;
}

inline unsigned int ETUIObject::setRSize(unsigned int new_row_size)
{
	row_size = new_row_size;
	redraw();
	return row_size;
}

inline unsigned int ETUIObject::setCSize(unsigned int new_col_size)
{
	col_size = new_col_size;
	redraw();
	return col_size;
}

inline ETUIObject * ETUIObject::GetParent() const
{
	return p_parent;
}

inline void ETUIObject::SetParent(ETUIObject * p_new_parent)
{
	p_parent = p_new_parent;
}
