require './movement'
require './resources'

class Sprite
	def initialize x, y, img, sprite_width = nil, sprite_height = nil
		@x = x; @y = y
		@img =
			if sprite_width.nil?
				[Res.img(img)]
			else
				Res.imgs img, sprite_width, sprite_height
			end
		@counter = 0
		@img_index = 0
		@index_index = 0
	end
	
	def update param
		
	end
	
	def animate interval, indices
		@counter += 1
		if @counter == interval
			@index_index += 1
			@index_index = 0 if @index_index == indices.length
			@img_index = indices[@index_index]
			@counter = 0
		end
	end
	
	def draw
		@img[@img_index].draw @x, @y, 0
	end
end

class Block
	include Movement
	
	def initialize x, y, w, h, passable
		@x = x; @y = y; @w = w; @h = h
		@passable = passable
	end
end

class GameObject < Sprite
	include Movement
	
	def initialize x, y, w, h, img, sprite_width = nil, sprite_height = nil, img_gap = nil
		super x, y, img, sprite_width, sprite_height
		@w = w; @h = h
		@img_gap =
			if img_gap.nil?
				Vector.new 0, 0
			else
				img_gap
			end
		@bounds = Rectangle.new x, y, w, h
		@speed = Vector.new 0, 0
		@stored_forces = Vector.new 0, 0
		@active = false
	end
	
	def is_visible map
		if @active_bounds
			return map.cam.intersects @active_bounds if @active
			return true
		end
		false
	end
	
	def set_animation index
		@counter = 0
		@img_index = index
		@index_index = 0
	end
	
	def draw map
		@img[@img_index].draw @x + @img_gap.x - map.cam.x,
		                      @y + @img_gap.y - map.cam.y, 0 if @img
	end
end
