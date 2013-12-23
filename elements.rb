require './game_object'

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
		move @forces, section.obstacles, section.ramps
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

class FireRock < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Bombie < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Sprinny < GameObject
	def initialize x, y, args
		@ready = true
	end
end

class Life < GameObject
	def initialize x, y, args, index
		@ready = true
	end
end

class Key < GameObject
	def initialize x, y, args, index
		super x + 3, y + 4, 26, 26, :sprite_Key, Vector.new(-3, -4)
		@index = index
		@active_bounds = Rectangle.new x + 3, y + 2, 26, 28
		@ready = true
	end
	
	def update section
		if section.collide_with_player? self
			section.take_item @index
		end
	end
end

class Door < GameObject
	def initialize x, y, args
		super x, y + 63, 32, 1, :sprite_Door, Vector.new(0, -63), 5, 1
		s = args.split ','
		@id = s[0].to_i
		@locked = (not s[1].nil?)
		@open = false
		@active_bounds = Rectangle.new x, y, 32, 64
		@ready = true
	end
	
	def update section
		if not @opening and section.collide_with_player? self
			if G.window.button_down? Gosu::KbA
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

class Attack1 < GameObject
	def initialize x, y, args, index
		@ready = true
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

