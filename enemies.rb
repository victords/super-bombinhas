class Enemy < GameObject
	def initialize x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
		
		@indices = indices
		@interval = interval
		@score = score
		
		@active_bounds = Rectangle.new x + img_gap.x, y + img_gap.y, @img[0].width, @img[0].height
	end
	
	def set_active_bounds section
		t = (@y + @img_gap.y).floor
		r = (@x + @img_gap.x + @img[0].width).ceil
		b = (@y + @img_gap.y + @img[0].height).ceil
		l = (@x + @img_gap.x).floor
		
		if t > section.size.y; @dead = true; puts "morrendo baixo"
		elsif r < 0; @dead = true; puts "morrendo esq"
		elsif b < C::TopMargin; @dead = true #para sumir por cima, a margem deve ser maior
		elsif l > section.size.x; @dead = true; puts "morrendo dir"
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
		if section.player_over? self
			G.player.score += @score
			@dead = true
		elsif section.bomb.explode? self
			G.player.score += @score
			@dead = true
		elsif section.collide_with_player? self
			G.player.die
		end
		
		yield
		
		set_active_bounds section
		animate @indices, @interval
	end
end

class Wheeliam < Enemy
	def initialize x, y, args
		super x, y, 32, 32, :sprite_Wheeliam, Vector.new(-4, -3), 4, 1, [0, 1], 8, 100
		
		@dont_fall = args.nil?
		@forces = Vector.new -4, 0
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
		puts "cheguei! #{@x}" if @x < 0
	end
	
	def set_direction dir
		@speed.x = 0
		if dir == :left
			@forces.x = -3
			@facing_right = false
			@indices[0] = 0; @indices[1] = 1
			set_animation 0
		else
			@forces.x = 3
			@facing_right = true
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
