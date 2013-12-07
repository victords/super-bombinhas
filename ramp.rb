class Ramp
	def initialize(x, y, w, h, left, color)
		@x = x
		@y = y
		@w = w
		@h = h
		# Indicates whether the ramp raises from left to right
		@left = left
		@color = color
	end
	
	def intersects(obj)
		obj.x + obj.w > @x && obj.x < @x + @w && obj.y > get_y(obj) && obj.y <= @y + @h - obj.h
	end
	def is_below(obj)
		obj.x + obj.w > @x && obj.x < @x + @w && obj.y == get_y(obj)
	end
	def get_y(obj)
		if @left && obj.x + obj.w > @x + @w; return @y - obj.h
		elsif @left; return @y + (1.0 * (@x + @w - obj.x - obj.w) * @h / @w) - obj.h
		elsif obj.x < @x; return @y - obj.h
		else; return @y + (1.0 * (obj.x - @x) * @h / @w) - obj.h
		end
	end
	
	def draw(window, map)
		window.draw_triangle((@left ? @x + @w : @x) - map.cam.x, @y - map.cam.y, @color,
			(@left ? @x : @x + @w) - map.cam.x, @y + @h - map.cam.y, @color,
			(@left ? @x + @w : @x) - map.cam.x, @y + @h - map.cam.y, @color, 0)
	end
end
