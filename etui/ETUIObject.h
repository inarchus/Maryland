#ifndef __ETUI_OBJECT__
#define __ETUI_OBJECT__

#include "../memory.h"
#include "../string.h"

enum EBorderType {borderless, single_line, double_line};

class ETUIObject
{
	public:
		ETUIObject();
		inline bool getVisible() const;
		inline unsigned int getRPosition() const;
		inline unsigned int getCPosition() const;

		inline unsigned int getRSize() const { return row_size; }
		inline unsigned int getCSize() const { return col_size; }
		
		inline bool setVisible(bool new_visible) 			   { visible = new_visible; redraw(); return visible; }
		inline unsigned int setRPosition(unsigned int new_row) { row_position = new_row; redraw(); return row_position; }
		inline unsigned int setCPosition(unsigned int new_col) { col_position = new_col; redraw(); return col_position; }
		
		inline unsigned int setRSize(unsigned int new_row_size) { row_size = new_row_size; redraw(); return row_size; }
		inline unsigned int setCSize(unsigned int new_col_size) { col_size = new_col_size; redraw(); return new_col_size; }
		
		inline void setTextColor(byte new_color) { text_color = new_color & 0x0f; }
		inline void setBackgroundColor(byte new_color) { background_color = new_color & 0x0f; }
		inline void setBorderColor(byte new_color) { border_color = new_color & 0x0f; }
		
		inline byte getTextColor(byte new_color) const { return text_color; }
		inline byte getBackgroundColor(byte new_color) const { return background_color; }
		inline byte getBorderColor(byte new_color) const { return border_color; }
		
		inline ETUIObject * GetParent() const;
		inline void SetParent(ETUIObject * p_new_parent);
		
		// we want to build this as a virtual method but in order to do it we'll implement virtuality ourselves
		// 
		virtual void redraw();
		
	protected:
		unsigned int row_position, col_position, row_size, col_size;
		bool visible;
		ETUIObject * p_parent;
		
		byte text_color;
		byte background_color;
		byte border_color;
		char border_symbol;
		
		void printToBuffer(int x_pos, int y_pos, char out_char, byte format);
		void drawString(int x_pos, int y_pos, const String & the_string, byte format);
		
		// this is essentially for virtual functions.  
		ETUIObject * base_pointer;
		
		static int screen_width;
};

#endif 