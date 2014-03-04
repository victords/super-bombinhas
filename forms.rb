require './global'

module AGL
	class Button
		def initialize x, y, text, img, margin_x = 0, margin_y = 0, center = true, &action
			@x = x
			@y = y
			@text = text
			@img = Res.imgs img, 1, 3, true
			@w = @img[0].width
			@h = @img[0].height
			if center
				@text_x = x + @w / 2
				@text_y = y + @h / 2
			else
				@text_x = x + margin_x
				@text_y = y + margin_y
			end
			@center = center
			@action = Proc.new &action
		
			@state = :up
			@img_index = 0
		end
	
		def update
			mouse_over = Mouse.over? @x, @y, @w, @h
			mouse_press = Mouse.button_pressed? :left
			mouse_rel = Mouse.button_released? :left
			
			if @state == :up
				if mouse_over
					@img_index = 1
					@state = :over
				end
			elsif @state == :over
				if not mouse_over
					@img_index = 0
					@state = :up
				elsif mouse_press
					@img_index = 2
					@state = :down
				end
			elsif @state == :down
				if not mouse_over
					@img_index = 0
					@state = :down_out
				elsif mouse_rel
					@img_index = 0
					@state = :up
					@action.call
				end
			elsif @state == :down_out
				if mouse_over
					@img_index = 2
					@state = :down
				elsif mouse_rel
					@img_index = 0
					@state = :up
				end
			end
		end
	
		def draw
			@img[@img_index].draw @x, @y, 0
			if @center
				G.font.draw_rel @text, @text_x, @text_y, 0, 0.5, 0.5, 1, 1, 0xff000000
			else
				G.font.draw @text, @text_x, @text_y, 0, 1, 1, 0xff000000
			end
		end
	end
	
	class TextField
		attr_reader :text
		
		def initialize x, y, img, cursor_img, text = "", margin_x = 0, margin_y = 0, max_length = 100
			@x = x
			@y = y
			@img = Res.img img
			@w = @img[0].width
			@h = @img[0].height
			@cursor_img = Res.img(cursor_img) if cursor_img
			@text = text
			@margin_x = margin_x
			@margin_y = margin_y
			@max_length = max_length
			
			@nodes = [x + margin_x]
			@cur_node = 0
			@cursor_visible = true
			@cursor_timer = 0
		end
		
		def text= value
			@text = value[0...max_length]
			@nodes.clear; @nodes << (@x + @margin_x)
			x = @nodes[0]
			for char in @text
				x += G.font.text_width char
				@nodes << x
			end
			@cur_node = -1
			@anchor1 = nil
			@anchor2 = nil
			set_cursor_visible
		end
		
		def selected_text
			return "" if @anchor2.nil?
			min = @anchor1 < @anchor2 ? @anchor1 : @anchor2
			max = min == @anchor1 ? @anchor2 : @anchor1
			@text[min..max]
		end
		
		def update
			################################ Mouse ################################
			if Mouse.over? @x, @y, @w, @h
				if Mouse.double_click? :left
					@anchor1 = 0
					@anchor2 = -1
					@cur_node = -1
					set_cursor_visible
				elsif Mouse.button_pressed? :left
					set_node_by_mouse
					@anchor1 = @cur_node
					@anchor2 = -1
					set_cursor_visible
				end
			end
			if Mouse.button_down? :left
				if @anchor1
					set_node_by_mouse
					if @cur_node != @anchor1; @anchor2 = @cur_node
					else; @anchor2 = nil; end
					set_cursor_visible
				end
			elsif Mouse.button_released? :left
				if @anchor1
					if @cur_node != @anchor1; @anchor2 = @cur_node
					else @anchor1 = nil; end
				end
			end
			
			@cursor_timer += 1
			if @cursor_timer >= 30
				@cursor_visible = (not @cursor_visible)
				@cursor_timer = 0
			end
			
			############################### Keyboard ##############################
#			if (kh.IsKeyPressed(53) || kh.IsKeyPressed(54)) # shift
#				if (@anchor1 == -1) @anchor1 = @cur_node;
#			bool inserted = false;
#			for (int i = 0; i < 47; i++) # alnum
#			{
#				if (kh.IsKeyPressed(i) || kh.IsKeyHeld(i))
#				{
#					if (@anchor1 != -1 && @anchor2 != -1)
#						RemoveInterval();
#					if (i < 26)
#					{
#						bool capsLock = Console.CapsLock;
#						if (kh.IsKeyDown(53) || kh.IsKeyDown(54))
#						{
#							if (capsLock) InsertChar(characters[i]);
#							else InsertChar(characters[i + 37]);
#						}
#						else
#						{
#							if (capsLock) InsertChar(characters[i + 37]);
#							else InsertChar(characters[i]);
#						}
#					}
#					elsif (i < 36)
#					{
#						if (kh.IsKeyDown(53) || kh.IsKeyDown(54)) InsertChar(characters[i + 57]);
#						else InsertChar(characters[i]);
#					}
#					elsif (kh.IsKeyDown(53) || kh.IsKeyDown(54)) InsertChar(characters[i + 47]);
#					else InsertChar(characters[i - 10]);
#					inserted = true;
#				}
#			}
#			for (int i = 55; i < 65; i++) # special
#			{
#				if (kh.IsKeyPressed(i) || kh.IsKeyHeld(i))
#				{
#					if (kh.IsKeyDown(53) || kh.IsKeyDown(54)) InsertChar(characters[i + 18]);
#					else InsertChar(characters[i + 8]);
#					inserted = true;
#				}
#			}
#			if (inserted) return;

#			if (kh.IsKeyPressed(47) || kh.IsKeyHeld(47)) # back
#			{
#				if (@anchor1 != -1 && @anchor2 != -1)
#					RemoveInterval();
#				elsif (@cur_node > 0)
#					RemoveChar(true);
#			}
#			elsif (kh.IsKeyPressed(48) || kh.IsKeyHeld(48)) # del
#			{
#				if (@anchor1 != -1 && @anchor2 != -1)
#					RemoveInterval();
#				elsif (@cur_node < charNodes.Count - 1)
#					RemoveChar(false);
#			}
#			elsif (kh.IsKeyPressed(49) || kh.IsKeyHeld(49)) # left
#			{
#				if (@anchor1 != -1)
#				{
#					if (kh.IsKeyDown(53) || kh.IsKeyDown(54))
#					{
#						if (@cur_node > 0)
#						{
#							@cur_node--;
#							@anchor2 = @cur_node;
#							set_cursor_visible
#						}
#					}
#					elsif (@anchor2 != -1)
#					{
#						@cur_node = @anchor1 < @anchor2 ? @anchor1 : @anchor2;
#						@anchor1 = -1;
#						@anchor2 = -1;
#						set_cursor_visible
#					}
#				}
#				elsif (@cur_node > 0)
#				{
#					@cur_node--;
#					set_cursor_visible
#				}
#			}
#			elsif (kh.IsKeyPressed(50) || kh.IsKeyHeld(50)) # right
#			{
#				if (@anchor1 != -1)
#				{
#					if (kh.IsKeyDown(53) || kh.IsKeyDown(54))
#					{
#						if (@cur_node < charNodes.Count - 1)
#						{
#							@cur_node++;
#							@anchor2 = @cur_node;
#							set_cursor_visible
#						}
#					}
#					elsif (@anchor2 != -1)
#					{
#						@cur_node = @anchor1 > @anchor2 ? @anchor1 : @anchor2;
#						@anchor1 = -1;
#						@anchor2 = -1;
#						set_cursor_visible
#					}
#				}
#				elsif (@cur_node < charNodes.Count - 1)
#				{
#					@cur_node++;
#					set_cursor_visible
#				}
#			}
#			elsif (kh.IsKeyPressed(51)) # home
#			{
#				@cur_node = 0;
#				if (kh.IsKeyDown(53) || kh.IsKeyDown(54))
#				@anchor2 = @cur_node;
#				else
#				{
#					@anchor1 = -1;
#					@anchor2 = -1;
#				}
#				set_cursor_visible
#			}
#			elsif (kh.IsKeyPressed(52)) # end
#			{
#				@cur_node = charNodes.Count - 1;
#				if (kh.IsKeyDown(53) || kh.IsKeyDown(54))
#				@anchor2 = @cur_node;
#				else
#				{
#					@anchor1 = -1;
#					@anchor2 = -1;
#				}
#				set_cursor_visible
#			}
		end
		
		def set_cursor_visible
			@cursor_visible = true
			@cursor_timer = 0
		end
	end
end
