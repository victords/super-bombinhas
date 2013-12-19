require './game_object'

class Wheeliam < GameObject
	def initialize x, y, args
		super x, y, 32, 32, :sprite_Wheeliam, 4, 1, Vector.new(-4, -3)
		
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
		
		animate @interval, @indices
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
				@active = true
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
		@args = args
	end
end

class Bombie < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Sprinny < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Life < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Key < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Door < GameObject
	def initialize x, y, args
		@args = args
	end
end

class GunPowder < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Crack < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Elevator < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Fureel < GameObject
	def initialize x, y, args
		@args = args
	end
end

class SaveBombie < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Pin < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Spikes < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Attack1 < GameObject
	def initialize x, y, args
		@args = args
	end
end

class MovingWall < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Ball < GameObject
	def initialize x, y, args
		@args = args
	end
end

class BallReceptor < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Yaw < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Ekips < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Spec < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Faller < GameObject
	def initialize x, y, args
		@args = args
	end
end

class Turner < GameObject
	def initialize x, y, args
		@args = args
	end
end

