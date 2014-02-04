############################### classes abstratas ##############################

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

################################################################################

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

class Yaw < Enemy
	def initialize x, y, args
		super x, y, 32, 32, :sprite_Yaw, Vector.new(-4, -4), 8, 1, [0, 1, 2], 6, 500
		@moving_eye = false
		@eye_timer = 0
		@points = [
			Vector.new(x + 64, y),
			Vector.new(x + 96, y + 32),
			Vector.new(x + 96, y + 96),
			Vector.new(x + 64, y + 128),
			Vector.new(x, y + 128),
			Vector.new(x - 32, y + 96),
			Vector.new(x - 32, y + 32),
			Vector.new(x, y)
		]
		@cur_point = 0
	end
	
	def update section
		super section do
			@cur_point = cycle @points, @cur_point, 3
		end
	end
	
	def hit bomb
		G.player.die
	end
end

class Ekips < GameObject
	def initialize x, y, args
		super x + 10, y - 10, 12, 25, :sprite_Ekips, Vector.new(-42, -8), 2, 3
		
		@act_timer = 0
		@active_bounds = Rectangle.new x - 32, y - 18, 96, 50
		@attack_bounds = Rectangle.new x - 32, y + 10, 96, 12
	end
	
	def update section
		if not @attacking
#			int pInd = checkProjectile();
#			if (pInd != -1)
#			{
#				Projectile *p = dynamic_cast<Projectile*>((*Control::currentStage->elements)[pInd]);
#				p->destroy();
#				disposing = true;
#				return;
#			}
		end
		
		if section.bomb.over? self
			if @attacking
				G.player.score += 240
				@dead = true
			else
				G.player.die
			end
		elsif @attacking and section.bomb.bounds.intersects @attack_bounds
			G.player.die
		elsif section.bomb.collide? self
			G.player.die
		end
		
		@act_timer += 1
		if @preparing and @act_timer >= 60
			animate [2, 3, 4, 5], 5
			if @img_index == 5
				@attacking = true
				@preparing = false
				set_animation 5
				@act_timer = 0
			end
		elsif @attacking and @act_timer >= 150
			animate [4, 3, 2, 1, 0], 5
			if @img_index == 0
				@attacking = false
				set_animation 0
				@act_timer = 0
			end
		elsif @act_timer >= 150
			@preparing = true
			set_animation 1
			@act_timer = 0
		end
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
