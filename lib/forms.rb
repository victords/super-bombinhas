require_relative 'global'

module AGL
	class Button
		def initialize x, y, font, text, img, center = true, margin_x = 0, margin_y = 0, &action
			@x = x
			@y = y
			@font = font
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
				@font.draw_rel @text, @text_x, @text_y, 0, 0.5, 0.5, 1, 1, 0xff000000
			else
				@font.draw @text, @text_x, @text_y, 0, 1, 1, 0xff000000
			end
		end
	end
	
	class TextField
		attr_reader :text
		
		def initialize x, y, font, img, cursor_img = nil, text = "", margin_x = 0, margin_y = 0, max_length = 100
			@x = x
			@y = y
			@font = font
			@img = Res.img img
			@w = @img.width
			@h = @img.height
			@cursor_img = Res.img(cursor_img) if cursor_img
			@text = text
			@text_x = x + margin_x
			@text_y = y + margin_y
			@max_length = max_length
			
			@nodes = [x + margin_x]
			@cur_node = 0
			@cursor_visible = true
			@cursor_timer = 0
			
			@k = [
				Gosu::KbA, Gosu::KbB, Gosu::KbC, Gosu::KbD, Gosu::KbE, Gosu::KbF,
				Gosu::KbG, Gosu::KbH, Gosu::KbI, Gosu::KbJ, Gosu::KbK, Gosu::KbL,
				Gosu::KbM, Gosu::KbN, Gosu::KbO, Gosu::KbP, Gosu::KbQ, Gosu::KbR,
				Gosu::KbS, Gosu::KbT, Gosu::KbU, Gosu::KbV, Gosu::KbW, Gosu::KbX,
				Gosu::KbY, Gosu::KbZ, Gosu::Kb1, Gosu::Kb2, Gosu::Kb3, Gosu::Kb4,
				Gosu::Kb5, Gosu::Kb6, Gosu::Kb7, Gosu::Kb8, Gosu::Kb9, Gosu::Kb0,
				Gosu::KbNumpad1, Gosu::KbNumpad2, Gosu::KbNumpad3, Gosu::KbNumpad4,
				Gosu::KbNumpad5, Gosu::KbNumpad6, Gosu::KbNumpad7, Gosu::KbNumpad8,
				Gosu::KbNumpad9, Gosu::KbNumpad0, Gosu::KbSpace, Gosu::KbBackspace,
				Gosu::KbDelete, Gosu::KbLeft, Gosu::KbRight, Gosu::KbHome,
				Gosu::KbEnd, Gosu::KbLeftShift, Gosu::KbRightShift,
				Gosu::KbBacktick, Gosu::KbMinus, Gosu::KbEqual, Gosu::KbBracketLeft,
				Gosu::KbBracketRight, Gosu::KbBackslash, Gosu::KbApostrophe,
				Gosu::KbComma, Gosu::KbPeriod, Gosu::KbSlash
			]
			@chars = "abcdefghijklmnopqrstuvwxyz1234567890 ABCDEFGHIJKLMNOPQRSTUVWXYZ'-=/[]\\,.;\"_+?{}|<>:!@#$%6&*()"
		end
		
		def text= value
			@text = value[0...max_length]
			@nodes.clear; @nodes << (@x + @margin_x)
			x = @nodes[0]
			for char in @text
				x += @font.text_width char
				@nodes << x
			end
			@cur_node = @nodes.size - 1
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
					@anchor2 = @nodes.size - 1
					@cur_node = @anchor2
					set_cursor_visible
				elsif Mouse.button_pressed? :left
					set_node_by_mouse
					@anchor1 = @cur_node
					@anchor2 = nil
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
					else; @anchor1 = nil; end
				end
			end
			
			@cursor_timer += 1
			if @cursor_timer >= 30
				@cursor_visible = (not @cursor_visible)
				@cursor_timer = 0
			end
			
			############################### Keyboard ##############################
			shift = KB.key_down?(@k[53]) or KB.key_down?(@k[54])
			if KB.key_pressed?(@k[53]) or KB.key_pressed?(@k[54]) # shift
				@anchor1 = @cur_node if @anchor1.nil?
			elsif KB.key_released?(@k[53]) or KB.key_released?(@k[54])
				@anchor1 = nil if @anchor2.nil?
			end
			inserted = false
			for i in 0..46 # alnum
				if KB.key_pressed?(@k[i]) or KB.key_held?(@k[i])
					remove_interval if @anchor1 and @anchor2
					if i < 26
#						bool capsLock = Console.CapsLock;
						if shift
#							if (capsLock) insert_char(@chars[i]);
#							else
							insert_char @chars[i + 37]
						else
#							if (capsLock) insert_char(@chars[i + 37]);
#							else
							insert_char @chars[i]
						end
					elsif i < 36
						if shift
							insert_char @chars[i + 57]
						else; insert_char @chars[i]; end
					elsif shift
						insert_char(@chars[i + 47]);
					else; insert_char(@chars[i - 10]); end
					inserted = true
					break
				end
			end
			
			return if inserted
			for i in 55..64 # special
				if KB.key_pressed?(@k[i]) or KB.key_held?(@k[i])
					if shift; insert_char @chars[i + 18]
					else; insert_char @chars[i + 8]; end
					inserted = true
					break
				end
			end
			
			return if inserted
			if KB.key_pressed?(@k[47]) or KB.key_held?(@k[47]) # back
				if @anchor1 and @anchor2
					remove_interval
				elsif @cur_node > 0
					remove_char true
				end
			elsif KB.key_pressed?(@k[48]) or KB.key_held?(@k[48]) # del
				if @anchor1 and @anchor2
					remove_interval
				elsif @cur_node < @nodes.size - 1
					remove_char false
				end
			elsif KB.key_pressed?(@k[49]) or KB.key_held?(@k[49]) # left
				if @anchor1
					if shift
						if @cur_node > 0
							@cur_node -= 1
							@anchor2 = @cur_node
							set_cursor_visible
						end
					elsif @anchor2
						@cur_node = @anchor1 < @anchor2 ? @anchor1 : @anchor2
						@anchor1 = nil
						@anchor2 = nil
						set_cursor_visible
					end
				elsif @cur_node > 0
					@cur_node -= 1
					set_cursor_visible
				end
			elsif KB.key_pressed?(@k[50]) or KB.key_held?(@k[50]) # right
				if @anchor1
					if shift
						if @cur_node < @nodes.size - 1
							@cur_node += 1
							@anchor2 = @cur_node
							set_cursor_visible
						end
					elsif @anchor2
						@cur_node = @anchor1 > @anchor2 ? @anchor1 : @anchor2
						@anchor1 = nil
						@anchor2 = nil
						set_cursor_visible
					end
				elsif @cur_node < @nodes.size - 1
					@cur_node += 1
					set_cursor_visible
				end
			elsif KB.key_pressed?(@k[51]) # home
				@cur_node = 0
				if shift; @anchor2 = @cur_node
				else
					@anchor1 = nil
					@anchor2 = nil
				end
				set_cursor_visible
			elsif KB.key_pressed?(@k[52]) # end
				@cur_node = @nodes.size - 1
				if shift; @anchor2 = @cur_node
				else
					@anchor1 = nil
					@anchor2 = nil
				end
				set_cursor_visible
			end
		end
		
		def set_cursor_visible
			@cursor_visible = true
			@cursor_timer = 0
		end
		
		def set_node_by_mouse
			index = @nodes.size - 1
			@nodes.each_with_index do |n, i|
				if n >= Mouse.x
					index = i
					break
				end
			end
			if index > 0
				d1 = @nodes[index] - Mouse.x; d2 = Mouse.x - @nodes[index - 1]
				index -= 1 if d1 > d2
			end
			@cur_node = index
		end
		
		def insert_char char
			if @text.length < @max_length
				@text.insert @cur_node, char
				@nodes.insert @cur_node + 1, @nodes[@cur_node] + @font.text_width(char)
				for i in (@cur_node + 2)..(@nodes.size - 1)
					@nodes[i] += @font.text_width(char)
				end
				@cur_node += 1
				set_cursor_visible
			end
		end
		
		def remove_interval
			min = @anchor1 < @anchor2 ? @anchor1 : @anchor2
			max = min == @anchor1 ? @anchor2 : @anchor1
			interval_width = 0
			for i in min...max
				interval_width += @font.text_width(@text[i])
				@nodes.delete_at min + 1
			end
			@text[min...max] = ""
			for i in (min + 1)..(@nodes.size - 1)
				@nodes[i] -= interval_width
			end
			@cur_node = min
			@anchor1 = nil
			@anchor2 = nil
			set_cursor_visible
		end
		
		def remove_char back
			@cur_node -= 1 if back
			char_width = @font.text_width(@text[@cur_node])
			@text[@cur_node] = ""
			@nodes.delete_at @cur_node + 1
			for i in (@cur_node + 1)..(@nodes.size - 1)
				@nodes[i] -= char_width
			end
			set_cursor_visible
		end
		
		def draw
			@img.draw @x, @y, 0
			if @cursor_visible
				if @cursor_img; @cursor_img.draw @text_x, @text_y, 0
				else
					Game.window.draw_quad @nodes[@cur_node], @text_y, 0xff000000,
					                      @nodes[@cur_node] + 1, @text_y, 0xff000000,
					                      @nodes[@cur_node] + 1, @text_y + @font.height, 0xff000000,
					                      @nodes[@cur_node], @text_y + @font.height, 0xff000000, 0
				end
			end
			@font.draw @text, @text_x, @text_y, 0, 1, 1, 0xff000000
			
			if @anchor1 and @anchor2
				Game.window.draw_quad @nodes[@anchor1], @text_y, 0x80000000,
				                   @nodes[@anchor2] + 1, @text_y, 0x80000000,
				                   @nodes[@anchor2] + 1, @text_y + @font.height, 0x80000000,
				                   @nodes[@anchor1], @text_y + @font.height, 0x80000000, 0
			end
		end
	end
end
