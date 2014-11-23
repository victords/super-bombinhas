require 'minigl'
include AGL

############################### classes abstratas ##############################

class TwoStateObject < GameObject
	def initialize x, y, w, h, img, img_gap, sprite_cols, sprite_rows,
		change_interval, anim_interval, change_anim_interval, s1_indices, s2_indices, s1_s2_indices, s2_s1_indices, s2_first = false
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows

		@timer = 0
		@changing = false
		@change_interval = change_interval
		@anim_interval = anim_interval
		@change_anim_interval = change_anim_interval
		@s1_indices = s1_indices
		@s2_indices = s2_indices
		@s1_s2_indices = s1_s2_indices
		@s2_s1_indices = s2_s1_indices
		@state2 = s2_first
		set_animation s2_indices[0] if s2_first
	end

	def update section
		@timer += 1
		if @timer == @change_interval
			@state2 = (not @state2)
			if @state2
				s1_to_s2 section
				set_animation @s1_s2_indices[0]
			else
				s2_to_s1 section
				set_animation @s2_s1_indices[0]
			end
			@changing = true
			@timer = 0
		end

		if @changing
			if @state2
				animate @s1_s2_indices, @change_anim_interval
				if @img_index == @s1_s2_indices[-1]
					set_animation @s1_s2_indices[-2]
					@changing = false
				end
			else
				animate @s2_s1_indices, @change_anim_interval
				if @img_index == @s2_s1_indices[-1]
					set_animation @s2_s1_indices[-2]
					@changing = false
				end
			end
		elsif @state2
			animate @s2_indices, @anim_interval if @anim_interval > 0
		else
			animate @s1_indices, @anim_interval if @anim_interval > 0
		end
	end
end

################################################################################

class Bombie < GameObject
	def initialize x, y, args, section
		super x, y, 32, 32, :sprite_Bombie, Vector.new(1, -2), 6, 1
		@msg_id = "msg#{args.to_i}".to_sym
		@balloon = Res.img :fx_Balloon1
		@facing_right = false
		@active = false
		@speaking = false
		@interval = 8

		@active_bounds = Rectangle.new x, y, 32, 32
	end

	def update section
		if G.player.bomb.collide? self
			if not @facing_right and G.player.bomb.bounds.x > @x + @w / 2
				@facing_right = true
				@indices = [3, 4, 5]
				set_animation 3
			elsif @facing_right and G.player.bomb.bounds.x < @x - @w / 2
				@facing_right = false
				@indices = [0, 1, 2]
				set_animation 0
			end
			if KB.key_pressed? Gosu::KbUp
				@speaking = (not @speaking)
				if @speaking
					if @facing_right; @indices = [3, 4, 5]
					else; @indices = [0, 1, 2]; end
					@active = false
				else
					if @facing_right; set_animation 3
					else; set_animation 0; end
				end
			end
			@active = (not @speaking)
		else
			@active = false
			@speaking = false
			if @facing_right; set_animation 3
			else; set_animation 0; end
		end

		animate @indices, @interval if @speaking
	end

	def draw map
		super map
		@balloon.draw @x - map.cam.x, @y - map.cam.y - 32, 0 if @active
		if @speaking
			G.window.draw_quad 5, 495, 0x80abcdef,
			                   795, 495, 0x80abcdef,
			                   795, 595, 0x80abcdef,
			                   5, 595, 0x80abcdef, 0
			G.font.draw G.text(@msg_id), 10, 500, 0, 1, 1, 0xff000000
		end
	end
end

class Door < GameObject
	def initialize x, y, args, section, switch
		super x + 15, y + 63, 2, 1, :sprite_Door, Vector.new(-15, -63), 5, 1
		@id = args.to_i
		@locked = (switch[:state] != :taken and args.split(',').length == 2)
		@open = false
		@active_bounds = Rectangle.new x, y, 32, 64
		@lock = Res.img(:sprite_Lock) if @locked
	end

	def update section
		collide = G.player.bomb.collide? self
		if @locked and collide
			section.locked_door = self
		end
		if not @locked and not @opening and collide
			if KB.key_pressed? Gosu::KbUp
				set_animation 1
				@opening = true
			end
		end
		if @opening
			animate [1, 2, 3, 4, 0], 5
			if @img_index == 0
				section.warp = @id
				@opening = false
			end
		end
	end

	def unlock
		@locked = false
		@lock = nil
	end

	def draw map
		super map
		@lock.draw(@x + 4 - map.cam.x, @y - 38 - map.cam.y, 0) if @lock
	end
end

class GunPowder < GameObject
	def initialize x, y, args, section, switch
		return if switch[:state] == :taken
		super x + 3, y + 19, 26, 13, :sprite_GunPowder, Vector.new(-2, -2)
		@life = 10
		@counter = 0

		@active_bounds = Rectangle.new x + 1, y + 17, 30, 15
	end

	def update section
		if G.player.bomb.collide? self
			G.player.bomb.set_exploding
			G.stage.set_switch self
			@dead = true
		end
	end
end

class Crack < GameObject
	def initialize x, y, args, section, switch
		super x + 32, y, 32, 32, :sprite_Crack
		@active_bounds = Rectangle.new x + 32, y, 32, 32
		@broken = switch[:state] == :taken
	end

	def update section
		if @broken or G.player.bomb.explode? self
			i = (@x / C::TILE_SIZE).floor
			j = (@y / C::TILE_SIZE).floor
			section.tiles[i][j].broken = true
			G.stage.set_switch self
			@dead = true
		end
	end
end

class Elevator < GameObject
	def initialize x, y, args, section
		a = args.split(':')
		type = a[0].to_i
		case type
			when 1 then w = 32; cols = nil; rows = nil
			when 2 then w = 64; cols = 4; rows = 1
		end
		super x, y, w, 1, "sprite_Elevator#{type}", Vector.new(0, 0), cols, rows
		@passable = true

		@speed_m = a[1].to_i
		@moving = false
		@cur_point = 0
		@points = []
		min_x = x; min_y = y
		max_x = x; max_y = y
		ps = a[2..-1]
		ps.each do |p|
			coords = p.split ','
			p_x = coords[0].to_i * C::TILE_SIZE; p_y = coords[1].to_i * C::TILE_SIZE

			min_x = p_x if p_x < min_x
			min_y = p_y if p_y < min_y
			max_x = p_x if p_x > max_x
			max_y = p_y if p_y > max_y

			@points << Vector.new(p_x, p_y)
		end
		@points << Vector.new(x, y)
		@active_bounds = Rectangle.new min_x, min_y, (max_x - min_x + w), (max_y - min_y + @img[0].height)

		section.obstacles << self
	end

	def update section
		obst = [G.player.bomb] #verificar...
		@cur_point = cycle @points, @cur_point, @speed_m, obst
	end
end

class SaveBombie < GameObject
	def initialize x, y, args, section, switch
		super x - 16, y, 64, 32, :sprite_Bombie2, Vector.new(-16, -26), 4, 2
		@id = args.to_i
		@active_bounds = Rectangle.new x - 32, y - 26, 96, 58
		@saved = switch[:state] == :taken
		@indices = [1, 2, 3]
		set_animation 1 if @saved
	end

	def update section
		if not @saved and G.player.bomb.collide? self
			section.save_check_point @id, self
			@saved = true
		end

		if @saved
			animate @indices, 8
		end
	end
end

class Pin < TwoStateObject
	def initialize x, y, args, section
		super x, y, 32, 32, :sprite_Pin, Vector.new(0, 0), 5, 1,
			60, 0, 3, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4], (not args.nil?)

		@active_bounds = Rectangle.new x, y, 32, 32
		section.obstacles << Block.new(x, y, 32, 32, true) if args
	end

	def s1_to_s2 section
		section.obstacles << Block.new(@x, @y, @w, @h, true)
	end

	def s2_to_s1 section
		section.obstacles.each do |o|
			if o.x == @x and o.y == @y
				section.obstacles.delete o
				break
			end
		end
	end
end

class Spikes < TwoStateObject
	def initialize x, y, args, section
		super x, y, 32, 32, :sprite_Spikes, Vector.new(0, 0), 5, 1,
			120, 0, 2, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4]

		@active_bounds = Rectangle.new x, y, 32, 33
	end

	def s1_to_s2 section
		section.obstacles << Block.new(@x, @y + 30, @w, @h, false)
	end

	def s2_to_s1 section
		section.obstacles.each do |o|
			if o.x == @x and o.y == @y + 30
				section.obstacles.delete o
				break
			end
		end
	end

	def update section
		super section

		if G.player.bomb.collide? self and @state2
			G.player.die
		end
	end
end

class MovingWall < GameObject
	attr_reader :id

	def initialize x, y, args, section
		super x + 2, y, 28, 32, :sprite_MovingWall, Vector.new(0, 0), 1, 2
		@id = args.to_i
		until section.obstacle_at? @x, @y - 1
			@y -= C::TILE_SIZE
			@h += C::TILE_SIZE
		end
		@active_bounds = Rectangle.new @x, @y, @w, @h
		section.obstacles << self
	end

	def update section
		if @opening
			@timer += 1
			if @timer == 30
				@y += 16
				@h -= 16
				@active_bounds = Rectangle.new @x, @y, @w, @h
				@timer = 0
				if @h == 0
					@dead = true
				end
			end
		end
	end

	def open
		@opening = true
		@timer = 0
	end

	def draw map
		y = 16
		@img[0].draw @x - map.cam.x, @y - map.cam.y, 0
		while y < @h
			@img[1].draw @x - map.cam.x, @y + y - map.cam.y, 0
			y += 16
		end
	end
end

class Ball < GameObject
	def initialize x, y, args, section, switch
		super x, y, 32, 32, :sprite_Ball
		if switch[:state] == :taken
			@x = switch[:extra].x
			@y = switch[:extra].y - 31
			@rec = switch[:extra]
			@set = true
		end
		@start_x = x
		@rotation = 0
		@active_bounds = Rectangle.new @x, @y, @w, @h
	end

	def update section
		if @set
			@x += (0.1 * (@rec.x - @x)) if @x.round(2) != @rec.x
		else
			forces = Vector.new 0, 0
			if G.player.bomb.collide? self
				if G.player.bomb.x < @x; forces.x = (G.player.bomb.x + G.player.bomb.w - @x) * 0.15
				else; forces.x = -(@x + @w - G.player.bomb.x) * 0.15; end
			end
			if @bottom
				if @speed.x != 0
					forces.x -= 0.15 * @speed.x
				end

				G.stage.switches.each do |s|
					if s[:type] == BallReceptor and bounds.intersects s[:obj].bounds
						s[:obj].set section
						s2 = G.stage.find_switch self
						s2[:extra] = @rec = s[:obj]
						s2[:state] = :temp_taken
						@set = true
						break
					end
				end
			end
			move forces, section.get_obstacles(@x, @y), section.ramps

			@active_bounds = Rectangle.new @x, @y, @w, @h
			@rotation = 3 * (@x - @start_x)
		end
	end

	def draw map
		@img[0].draw_rot @x + (@w / 2) - map.cam.x, @y + (@h / 2) - map.cam.y, 0, @rotation
	end
end

class BallReceptor < GameObject
	attr_reader :id

	def initialize x, y, args, section, switch
		super x, y + 31, 32, 1, :sprite_BallReceptor, Vector.new(0, -8), 1, 2
		@id = args.to_i
		@will_set = switch[:state] == :taken
		@active_bounds = Rectangle.new x, y + 23, 32, 13
	end

	def update section
		if @will_set
			section.open_wall @id
			@img_index = 1
			@will_set = false
		end
	end

	def set section
		G.stage.set_switch self
		section.open_wall @id
		@img_index = 1
	end
end

class HideTile
	def initialize i, j, group, tiles, num
		@state = 0
		@alpha = 0xff
		@color = 0xffffffff

		@group = group
		@points = []
		check_tile i, j, tiles, 4

		@img = Res.imgs "sprite_ForeWall#{num}".to_sym, 5, 1
	end

	def check_tile i, j, tiles, dir
		return -1 if tiles[i].nil? or tiles[i][j].nil?
		return tiles[i][j].wall if tiles[i][j].hide < 0
		return 0 if tiles[i][j].hide == @group

		tiles[i][j].hide = @group
		t = 0; r = 0; b = 0; l = 0
		t = check_tile i, j-1, tiles, 0 if dir != 2
		r = check_tile i+1, j, tiles, 1 if dir != 3
		b = check_tile i, j+1, tiles, 2 if dir != 0
		l = check_tile i-1, j, tiles, 3 if dir != 1
		if t < 0 and r >= 0 and b >= 0 and l >= 0; img = 1
		elsif t >= 0 and r < 0 and b >= 0 and l >= 0; img = 2
		elsif t >= 0 and r >= 0 and b < 0 and l >= 0; img = 3
		elsif t >= 0 and r >= 0 and b >= 0 and l < 0; img = 4
		else; img = 0; end

		@points << {x: i * C::TILE_SIZE, y: j * C::TILE_SIZE, img: img}
		0
	end

	def update section
		will_show = false
		@points.each do |p|
			rect = Rectangle.new p[:x], p[:y], C::TILE_SIZE, C::TILE_SIZE
			if G.player.bomb.bounds.intersects rect
				will_show = true
				break
			end
		end
		if will_show; show
		else; hide; end
	end

	def show
		if @state != 2
			@alpha -= 17
			if @alpha == 51
				@state = 2
			else
				@state = 1
			end
			@color = 0x00ffffff | (@alpha << 24)
		end
	end

	def hide
		if @state != 0
			@alpha += 17
			if @alpha == 0xff
				@state = 0
			else
				@state = 1
			end
			@color = 0x00ffffff | (@alpha << 24)
		end
	end

	def is_visible map
		true
	end

	def draw map
		@points.each do |p|
			@img[p[:img]].draw p[:x] - map.cam.x, p[:y] - map.cam.y, 0, 1, 1, @color
		end
	end
end

class Projectile < GameObject
	def initialize x, y, type, angle
		case type
		when 1 then w = 20; h = 12; img = :sprite_Projectile1; x_g = -2; y_g = -2; cols = 3; rows = 1; @speed_m = 3
		end

		super x - x_g, y - y_g, w, h, img, Vector.new(x_g, y_g), cols, rows
		@aim = Vector.new @x + (1000000 * Math.cos(angle)), @y - (1000000 * Math.sin(angle))
		@active_bounds = Rectangle.new @x + @img_gap.x, @y + @img_gap.y, @img[0].width, @img[0].height
		@angle = angle
		puts angle
	end

	def update section
		move_free @aim, @speed_m

		t = (@y + @img_gap.y).floor
		r = (@x + @img_gap.x + @img[0].width).ceil
		b = (@y + @img_gap.y + @img[0].height).ceil
		l = (@x + @img_gap.x).floor
		if t > section.size.y; @dead = true
		elsif r < 0; @dead = true
		elsif b < C::TOP_MARGIN; @dead = true #para sumir por cima, a margem deve ser maior
		elsif l > section.size.x; @dead = true
		end
	end

	def draw map
		@img[@img_index].draw_rot @x + (@w / 2) - map.cam.x, @y + (@h / 2) - map.cam.y, 0, (@angle * 180 / Math::PI)
	end
end