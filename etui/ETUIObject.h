#ifndef __ETUI_OBJECT__
#define __ETUI_OBJECT__

class ETUIObject
{
	public:
		ETUIObject();
		inline bool getVisible() const;
		inline unsigned int getRPosition() const;
		inline unsigned int getCPosition() const;

		inline unsigned int getRSize() const;
		inline unsigned int getCSize() const;
		
		inline bool setVisible(bool new_visible);
		inline unsigned int setRPosition(unsigned int new_row);
		inline unsigned int setCPosition(unsigned int new_col);
		
		inline unsigned int setRSize(unsigned int new_row_size);
		inline unsigned int setCSize(unsigned int new_col_size);
		
		inline ETUIObject * GetParent() const;
		inline void SetParent(ETUIObject * p_new_parent);
		
		// we want to build this as a virtual method but in order to do it we'll implement virtuality ourselves
		// 
		virtual void redraw();
		
	protected:
		unsigned int row_position, col_position, row_size, col_size;
		bool visible;
		ETUIObject * p_parent;
		
		// this is essentially for virtual functions.  
		ETUIObject * base_pointer;
};

#endif 