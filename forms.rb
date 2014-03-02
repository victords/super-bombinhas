require './global'

class TestButton
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
		
		puts "#{@x} #{@y} #{@w} #{@h}"
	end
	
	def update
		mouse_over = (Mouse.x >= @x and Mouse.x < @x + @w and Mouse.y >= @y and Mouse.y < @y + @h)
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
