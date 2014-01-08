class Enemy < GameObject
	def initialize x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
		
		@indices = indices
		@interval = interval
		@score = score
		@hp = hp
		@timer = 0
		
		@active_bounds = Rectangle.new x + img_gap.x, y + img_gap.y, @img[0].width, @img[0].height
	end
	
	def set_active_bounds section
		t = (@y + @img_gap.y).floor
		r = (@x + @img_gap.x + @img[0].width).ceil
		b = (@y + @img_gap.y + @img[0].height).ceil
		l = (@x + @img_gap.x).floor
		
		if t > section.size.y; @dead = true
		elsif r < 0; @dead = true
		elsif b < C::TopMargin; @dead = true #para sumir por cima, a margem deve ser maior
		elsif l > section.size.x; @dead = true
		else
			if t < @active_bounds.y
				@active_bounds.h += @active_bounds.y - t
				@active_bounds.y = t
			end
			@active_bounds.w = r - @active_bounds.x if r > @active_bounds.x + @active_bounds.w
			@active_bounds.h = b - @active_bounds.y if b > @active_bounds.y + @active_bounds.h
			if l < @active_bounds.x
				@active_bounds.w += @active_bounds.x - l
				@active_bounds.x = l
			end
		end
	end
	
	def update section
		if section.bomb.over? self
			if @invulnerable			
				section.bomb.stored_forces.y -= C::BounceForce
			else
				hit section.bomb
			end
		elsif section.bomb.explode? self
			G.player.score += @score
			@dead = true
		elsif section.bomb.collide? self
			G.player.die
		end
		
		if @invulnerable
			@timer += 1
			if @timer == C::InvulnerableTime
				@invulnerable = false
				@timer = 0
			end
		end
		
		yield
		
		set_active_bounds section
		animate @indices, @interval
	end
	
	def hit bomb
		@hp -= 1
		if @hp == 0
			G.player.score += @score
			@dead = true
		else
			@invulnerable = true
			bomb.stored_forces.y -= C::BounceForce
		end
	end
end

class FloorEnemy < Enemy
	def initialize x, y, args, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1, speed = 3
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp
		
		@dont_fall = args.nil?
		@speed_m = speed
		@forces = Vector.new -@speed_m, 0
		@facing_right = false
	end
	
	def update section
		super section do
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
		end
	end
	
	def set_direction dir
		@speed.x = 0
		if dir == :left
			@forces.x = -@speed_m
			@facing_right = false
			@indices[0] = 0; @indices[1] = 1
			set_animation 0
		else
			@forces.x = @speed_m
			@facing_right = true
			@indices[0] = 2; @indices[1] = 3
			set_animation 2
		end
		change_animation dir
	end
end

class Wheeliam < FloorEnemy
	def initialize x, y, args
		super x, y, args, 32, 32, :sprite_Wheeliam, Vector.new(-4, -3), 4, 1, [0, 1], 8, 100
	end
	
	def change_animation dir
		if dir == :left
			@indices[0] = 0; @indices[1] = 1
			set_animation 0
		else
			@indices[0] = 2; @indices[1] = 3
			set_animation 2
		end
	end
end

class Sprinny < Enemy
	def initialize x, y, args
		super x + 3, y - 4, 26, 36, :sprite_Sprinny, Vector.new(-2, -5), 6, 1, [0], 5, 350
		
		@leaps = 1000
		@max_leaps = args.to_i
		@facing_right = true
	end
	
	def update section
		super section do
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
		end
	end
end

class Fureel < FloorEnemy
	def initialize x, y, args
		super x - 4, y - 4, args, 40, 36, :sprite_Fureel, Vector.new(-10, -3), 6, 1, [0, 1], 8, 300, 2, 4
	end
	
	def change_animation dir
		if dir == :left
			@indices[0] = 0; @indices[1] = 1
			set_animation 0
		else
			@indices[0] = 3; @indices[1] = 4
			set_animation 3
		end
	end
end

class Yaw < GameObject
	def initialize x, y, args
		
	end
end

class Ekips < GameObject
	def initialize x, y, args
		
	end
end

class Faller < GameObject
	def initialize x, y, args
		
	end
end

class Turner < GameObject
	def initialize x, y, args
		
	end
end
