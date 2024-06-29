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

/*
	unsigned int row_position, col_position, row_size, col_size;
	bool visible;
	ETUIObject * p_parent;
	
	byte text_color;
	byte background_color;
	byte border_color;
*/

void EFrame::drawBorder()
{
	byte format = (background_color << 4) + text_color; // change to border color once anything actually works.  
	for(int b_x = row_position; b_x <= row_position + row_size; b_x++)
	{
		printToBuffer(b_x, col_position, border_symbol, format);
		printToBuffer(b_x, col_position + col_size, border_symbol, format);
	}
	for(int b_y = col_position; b_y <= col_position + col_size; b_y++)
	{
		printToBuffer(row_position, b_y, border_symbol, format);
		printToBuffer(row_position + row_size, b_y, border_symbol, format);
	}
}

void EFrame::drawBackground()
{
/*	asm (
		"movb %0, %%al;"
		"movl %3, %%ecx;"
		: 
		: "r" (background_color), "r" (row_position), "r" (col_position), "r" (row_size), "r" (col_size)
		: 
	);*/
	byte format = background_color << 4;
	for(int b_x = row_position + 1; b_x < row_position + row_size; b_x++)
	{
		for(int b_y = col_position + 1; b_y < col_position + col_size; b_y++)
		{
			printToBuffer(b_x, b_y, ' ', format);
		}
	}
}

void EFrame::redraw()
{
	if(visible)
	{
		drawBorder();
		drawBackground();
		for(int i = 0; i < 25; i++)
		{
			printToBuffer(i, i, 'a', 0x0f);
		}
		for(unsigned int i = 0; i < children.size(); i++)
		{
			children[i]->redraw();
		}
	}
}