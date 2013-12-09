require './global.rb'

class Map
	attr_reader :tile_size, :size, :cam
	
	def initialize t_w, t_h, t_x_count, t_y_count, scr_w = 800, scr_h = 600
		@tile_size = Vector.new t_w, t_h
		@size = Vector.new t_x_count, t_y_count
		@cam = Rectangle.new 0, 0, scr_w, scr_h
	end
	
	def get_absolute_size
		Vector.new(@tile_size.x * @size.x, @tile_size.y * @size.y)
	end
	
	def get_center
		Vector.new(@tile_size.x * @size.x / 2, @tile_size.y * @size.y / 2)
	end
	
	def get_screen_pos map_x, map_y
		Vector.new(map_x * @tile_size.x - @cam.x, map_y * @tile_size.y - @cam.y)
	end
	
	def get_map_pos scr_x, scr_y
		Vector.new((scr_x + @cam.x) / @tile_size.x, (scr_y + @cam.y) / @tile_size.y)
	end
	
	def is_in_map v
		v.x >= 0 && v.y >= 0 && v.x < @size.x && v.y < @size.y
	end
	
	def set_camera cam_x, cam_y
		@cam.x = cam_x
		@cam.y = cam_y
		set_bounds
	end
	
	def set_bounds
		@min_vis_x = @cam.x / @tile_size.x
		@min_vis_y = @cam.y / @tile_size.y
		@max_vis_x = (@cam.x + @cam.w - 1) / @tile_size.x
		@max_vis_y = (@cam.y + @cam.h - 1) / @tile_size.y

		if @min_vis_y < 0; @min_vis_y = 0
		elsif @min_vis_y > @size.y - 1; @min_vis_y = @size.y - 1; end

		if @max_vis_y < 0; @max_vis_y = 0
		elsif @max_vis_y > @size.y - 1; @max_vis_y = @size.y - 1; end

		if @min_vis_x < 0; @min_vis_x = 0
		elsif @min_vis_x > @size.x - 1; @min_vis_x = @size.x - 1; end

		if @max_vis_x < 0; @max_vis_x = 0
		elsif @max_vis_x > @size.x - 1; @max_vis_x = @size.x - 1; end
	end
	
	def foreach
		for j in @min_vis_y..@max_vis_y
			for i in @min_vis_x..@max_vis_x
				yield i, j, i * @tile_size.x - @cam.x, j * @tile_size.y - @cam.y
			end
		end
	end
end
