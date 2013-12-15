require './game_object'

class Wheeliam < GameObject
	def initialize map_x, map_y, args
		super map_x * C::TileSize, map_y * C::TileSize, 32, 32,
			:sprite_Wheeliam, 40, 35, Vector.new(-4, -3)
		
		@dont_fall = args.nil?
		@interval = 8
		@indices = [0, 1]
		@forces = Vector.new -13, 0
		@facing_right = false
	end
	
	def update section
		move @forces, section.obstacles, []
		if @forces.x != 0
			@forces.x = 0
		elsif @left
			set_direction C::Right
		elsif @right
			set_direction C::Left
		elsif @dont_fall
			if @facing_right
				set_direction C::Left if not section.obstacle_at? @x + @w, @y + @h
			elsif not section.obstacle_at? @x - 1, @y + @h
				set_direction C::Right
			end
		end
		
		animate @interval, @indices
	end
	
	def set_direction dir
		@speed.x = 0
		if dir == C::Left
			@forces.x = -13
			@facing_right = false
			@indices[0] = 0; @indices[1] = 1
			set_animation 0
		else
			@forces.x = 13
			@facing_right = true
			@indices[0] = 2; @indices[1] = 3
			set_animation 2
		end
	end
end

class FireRock < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Bombie < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Sprinny < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Life < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Key < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Door < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class GunPowder < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Crack < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Elevator < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Fureel < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class SaveBombie < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Pin < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Spikes < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Attack1 < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class MovingWall < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Ball < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class BallReceptor < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Yaw < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Ekips < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Spec < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Faller < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

class Turner < GameObject
	def initialize map_x, map_y, args
		@args = args
	end
end

