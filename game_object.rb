require './movement'
require './resources'

class Sprite
	attr_accessor :x, :y
	
	def initialize x, y, img, sprite_cols = nil, sprite_rows = nil
		@x = x; @y = y
		@img =
			if sprite_cols.nil?
				[Res.img(img)]
			else
				Res.imgs img, sprite_cols, sprite_rows
			end
		@anim_counter = 0
		@img_index = 0
		@index_index = 0
	end
	
	def animate indices, interval
		@anim_counter += 1
		if @anim_counter >= interval
			@index_index += 1
			@index_index = 0 if @index_index == indices.length
			@img_index = indices[@index_index]
			@anim_counter = 0
		end
	end
	
	def draw map = nil
		if map
			@img[@img_index].draw @x - map.cam.x, @y - map.cam.y, 0
		else
			@img[@img_index].draw @x, @y, 0
		end
	end
end

class Block
	attr_reader :x, :y, :w, :h, :passable
	
	def initialize x, y, w, h, passable
		@x = x; @y = y; @w = w; @h = h
		@passable = passable
	end
	
	def bounds
		Rectangle.new @x, @y, @w, @h
	end
end

class GameObject < Sprite
	include Movement
	
	def initialize x, y, w, h, img, img_gap = nil, sprite_cols = nil, sprite_rows = nil
		super x, y, img, sprite_cols, sprite_rows
		@w = w; @h = h
		@img_gap =
			if img_gap.nil?
				Vector.new 0, 0
			else
				img_gap
			end
		@speed = Vector.new 0, 0
		@min_speed = Vector.new 0.01, 0.01
		@max_speed = Vector.new 15, 15
		@stored_forces = Vector.new 0, 0
	end
	
	def set_animation index
		@anim_counter = 0
		@img_index = index
		@index_index = 0
	end
	
	def is_visible map
		return map.cam.intersects @active_bounds if @active_bounds
		false
	end
	
	def dead?
		@dead
	end
	
	def update param
	end
	
	def draw map
		@img[@img_index].draw @x.round + @img_gap.x - map.cam.x,
		                      @y.round + @img_gap.y - map.cam.y, 0 if @img
	end
end

class Effect < Sprite
	def initialize x, y, life_time, img, sprite_cols = nil, sprite_rows = nil, indices = nil, interval = 1
		super x, y, img, sprite_cols, sprite_rows
		@life_time = life_time
		@timer = 0
		if indices
			@indices = indices
		else
			@indices = *(0..(@img.length - 1))
		end
		@interval = interval
	end
	
	def update
		animate @indices, @interval
		@timer += 1
		if @timer == @life_time
			@dead = true
		end
	end
end
