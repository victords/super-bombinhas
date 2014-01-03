require './game_object'

class FloatingItem < GameObject
	def initialize x, y, w, h, img, img_gap = nil, sprite_cols = nil, sprite_rows = nil, indices = nil, interval = nil
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
		if img_gap
			@active_bounds = Rectangle.new x + img_gap.x, y - img_gap.y, @img[0].width, @img[0].height
		else
			@active_bounds = Rectangle.new x, y, @img[0].width, @img[0].height
		end
		@ready = true
		@state = 3
		@move_counter = 0
		@indices = indices
		@interval = interval
	end
	
	def update section
		if section.collide_with_player? self
			yield
			@dead = true
		end
		@move_counter += 1
		if @move_counter == 10
			if @state == 0 or @state == 1; @y -= 1
			else; @y += 1; end
			@state += 1
			@state = 0 if @state == 4
			@move_counter = 0
		end
		animate @indices, @interval if @indices
	end
end

class Wheeliam < GameObject
	def initialize x, y, args
		super x, y, 32, 32, :sprite_Wheeliam, Vector.new(-4, -3), 4, 1
		
		@dont_fall = args.nil?
		@interval = 8
		@indices = [0, 1]
		@forces = Vector.new -4, 0
		@facing_right = false
		
		@active_bounds = Rectangle.new -1000, @y + @img_gap.y, 0, 35
	end
	
	def update section
		if section.player_over? self
			G.player.score += 100
			@dead = true
		elsif section.collide_with_player? self
			G.player.die
		end
		
		move @forces, section.get_obstacles(@x, @y), section.ramps
		@forces.x = 0
		if @left
			set_direction :right
		elsif @right
			set_direction :left
		elsif @dont_fall
			if @facing_right
				set_direction :left if not section.obstacle_at? @x + @w, @y + @h
			elsif not section.obstacle_at? @x - 1, @y + @h
				set_direction :right
			end
		end
		
		animate @indices, @interval
	end
	
	def set_direction dir
		@speed.x = 0
		if dir == :left
			@forces.x = -3
			@facing_right = false
			@indices[0] = 0; @indices[1] = 1
			set_animation 0
			if @active_bounds.w == 0
				@active_bounds.w = @x + @img_gap.x + @img[0].width - @active_bounds.x
				@ready = true
			end
		else
			@forces.x = 3
			@facing_right = true
			@indices[0] = 2; @indices[1] = 3
			set_animation 2
			@active_bounds.x = @x + @img_gap.x if @active_bounds.x < 0
		end
	end
end

class FireRock < FloatingItem
	def initialize x, y, args
		super x + 6, y + 7, 20, 20, :sprite_FireRock, Vector.new(-2, -17), 4, 1, [0, 1, 2, 3], 5
	end
	
	def update section
		super section do
			G.player.score += 10
		end
	end
end

class Bombie < GameObject
	def initialize x, y, args
		super x, y, 32, 32, :sprite_Bombie, Vector.new(1, -2), 6, 1
		@msg_id = "msg#{args.to_i}".to_sym
		@balloon = Res.img :fx_Balloon1
		@facing_right = false
		@active = false
		@speaking = false
		@interval = 8
		
		@active_bounds = Rectangle.new x, y, 32, 32
		@ready = true
	end
	
	def update section
		if section.collide_with_player? self
			if not @facing_right and section.bomb_bounds.x > @x + @w / 2
				@facing_right = true
				@indices = [3, 4, 5]
				set_animation 3
			elsif @facing_right and section.bomb_bounds.x < @x - @w / 2
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
			G.font.draw Res.text(@msg_id), 10, 500, 0, 1, 1, 0xff000000
		end
	end
end

class Sprinny < GameObject
	def initialize x, y, args
		super x + 3, y - 4, 26, 36, :sprite_Sprinny, Vector.new(-2, -5), 6, 1
		
		@leaps = 1000
		@max_leaps = args.to_i
		@facing_right = true
		@interval = 5
		@indices = [0]
		
		@active_bounds = Rectangle.new x - 4 * C::TileSize * @max_leaps, y - 4 * C::TileSize,
			4 * C::TileSize * @max_leaps + C::TileSize, 5 * C::TileSize
		@ready = true
	end
	
	def update section
		if section.player_over? self
			G.player.score += 350
			@dead = true
		elsif section.collide_with_player? self
			G.player.die
		end
		
		forces = Vector.new 0, 0
		if @bottom
			@leaps += 1
			if @leaps > @max_leaps
				@leaps = 1
				if @facing_right
					@facing_right = false
					@indices = [0, 1, 2, 1]
					set_animation 0
				else
					@facing_right = true
					@indices = [3, 4, 5, 4]
					set_animation 3
				end
			end
			@speed.x = 0
			if @facing_right; forces.x = 4
			else; forces.x = -4; end
			forces.y = -15
		end
		move forces, section.get_obstacles(@x, @y), section.ramps
		
		animate @indices, @interval
	end
end

class Life < FloatingItem
	def initialize x, y, args, index
		super x + 3, y + 3, 26, 26, :sprite_Life, Vector.new(-3, -3), 8, 1,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
		@index = index
	end
	
	def update section
		super section do
			section.take_item @index, :Life, true, false
		end
	end
end

class Key < FloatingItem
	def initialize x, y, args, index
		super x + 3, y + 3, 26, 26, :sprite_Key, Vector.new(-3, -3)
		@index = index
	end
	
	def update section
		super section do
			section.take_item @index, :Key, true, true
		end
	end
end

class Door < GameObject
	def initialize x, y, args
		super x + 15, y + 63, 2, 1, :sprite_Door, Vector.new(-15, -63), 5, 1
		s = args.split ','
		@id = s[0].to_i
		@locked = (not s[1].nil?)
		@open = false
		@active_bounds = Rectangle.new x, y, 32, 64
		@ready = true
		@lock = Res.img(:sprite_Lock) if @locked
	end
	
	def update section
		collide = section.collide_with_player? self
		if @locked and collide
			section.locked_door = self
		else
			section.locked_door = nil
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
	def initialize x, y, args, index
		@ready = true
	end
end

class Crack < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Elevator < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Fureel < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class SaveBombie < GameObject
	def initialize x, y, args
		super x - 16, y, 64, 32, :sprite_Bombie2, Vector.new(-16, -26), 4, 2
		@id = args.to_i
		@active_bounds = Rectangle.new x - 32, y - 26, 96, 58
		@saved = false
		@ready = true
	end
	
	def update section
		if not @saved and section.collide_with_player? self
			section.save_check_point @id
			@saved = true
			@indices = [1, 2, 3]
		end
		
		if @saved
			animate @indices, 8
		end
	end
end

class Pin < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Spikes < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Attack1 < FloatingItem
	def initialize x, y, args, index
		super x + 3, y + 3, 26, 26, :sprite_Attack1, Vector.new(-3, -3), 8, 1,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
	end
	
	def update section
		super section do
			section.take_item -1, :Attack1, false, true
		end
	end
end

class MovingWall < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Ball < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class BallReceptor < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Yaw < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Ekips < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Spec < GameObject
	def initialize x, y, args, index
		@ready = true
	end
end

class Faller < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Turner < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class HideTile
	#falta fazer a checagem de bordas e implementar is_visible
	
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
		return if tiles[i][j].nil?
		return if tiles[i][j].hide < 0 or tiles[i][j].hide == @group
		tiles[i][j].hide = @group
		@points << Vector.new(i, j)
		check_tile i, j-1, tiles, 0 if dir != 2
		check_tile i+1, j, tiles, 1 if dir != 3
		check_tile i, j+1, tiles, 2 if dir != 0
		check_tile i-1, j, tiles, 3 if dir != 1
	end
	
	def update section
		will_show = false
		bounds = section.bomb_bounds
		@points.each do |p|
			rect = Rectangle.new p.x * C::TileSize, p.y * C::TileSize, C::TileSize, C::TileSize
			if bounds.intersects rect
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
			@img[0].draw p.x * C::TileSize - map.cam.x, p.y * C::TileSize - map.cam.y, 0, 1, 1, @color
		end
	end
end

