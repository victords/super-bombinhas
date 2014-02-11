require './game_object'

class Bomb < GameObject
	attr_reader :facing_right
	
	def initialize type
		t_img_gap = -10
		case type
		when :azul then @name = "Bomba Azul"; img = :sprite_BombaAzul; l_img_gap = -5; r_img_gap = -5
		when :vermelha then @name = "Bomba Vermelha"; img = :sprite_BombaVermelha; l_img_gap = -4; r_img_gap = -6
		when :amarela then @name = "Bomba Amarela"; img = :sprite_BombaAmarela; l_img_gap = -6; r_img_gap = -14
		when :verde then @name = "Bomba Verde"; img = :sprite_BombaVerde; l_img_gap = -6; r_img_gap = -14
		when :aldan then @name = "Aldan"; img = :sprite_Aldan; l_img_gap = -6; r_img_gap = -14; t_img_gap = -26
		end
		
		super -1000, -1000, 20, 30, img, Vector.new(r_img_gap, t_img_gap), 5, 2
		@max_speed.x = 5
		@indices = [0, 1, 0, 2]
		@facing_right = true
		@ready = true
		@type = type
		
		@explosion = Sprite.new 0, 0, :fx_Explosion, 2, 2
		@explosion_timer = 0
		@explosion_counter = 10
	end
	
	def update section
		G.player.change_item if KB.key_pressed? Gosu::KbLeftShift or KB.key_pressed? Gosu::KbRightShift
		G.player.use_item section if KB.key_pressed? Gosu::KbA
		
		forces = Vector.new 0, 0
		if @exploding
			@explosion.animate [0, 1, 2, 3], 5
			@explosion_counter += 1
			@exploding = false if @explosion_counter == 90
			forces.x -= 0.15 * @speed.x if @speed.x != 0
		else
			if @will_explode
				@explosion_timer += 1
				if @explosion_timer == 60
					@explosion_counter -= 1
					explode if @explosion_counter == 0
					@explosion_timer = 0
				end
			end
			if KB.key_down? Gosu::KbLeft
				set_direction :left if @facing_right
				forces.x -= @bottom ? 0.15 : 0.05
			elsif @speed.x < 0
				forces.x -= 0.15 * @speed.x
			end
			if KB.key_down? Gosu::KbRight
				set_direction :right if not @facing_right
				forces.x += @bottom ? 0.15 : 0.05
			elsif @speed.x > 0
				forces.x -= 0.15 * @speed.x
			end
			if @bottom
				if @speed.x != 0
					animate @indices, 30 / @speed.x.abs
				elsif @facing_right
					set_animation 0
				else
					set_animation 5
				end
				if KB.key_pressed? Gosu::KbSpace
					forces.y -= 13.7 + 0.4 * @speed.x.abs
					if @facing_right; set_animation 3
					else; set_animation 8; end
				end
			end
		end
		move forces, section.get_obstacles(@x, @y), section.ramps
	end
	
	def set_direction dir
		if dir == :left
			@facing_right = false
			@indices = [5, 6, 5, 7]
			set_animation 5
		else
			@facing_right = true
			@indices = [0, 1, 0, 2]
			set_animation 0
		end
	end
	
	def do_warp x, y
		@speed.x = @speed.y = 0
		@x = x + 6; @y = y + 2
		@facing_right = true
		@indices = [0, 1, 0, 2]
		set_animation 0
	end
	
	def set_exploding
		@will_explode = true
		@explosion_timer = 0
		@explosion_counter = 10
	end
	
	def explode
		@will_explode = false
		@exploding = true
		@explosion_timer = 0
		@explosion.x = @x - 80
		@explosion.y = @y - 75
		set_animation (@facing_right ? 4 : 9)
	end
	
	def explode? obj
		return false if not @exploding
		radius = @type == :verde ? 120 : 90
		c_x = @x + @w / 2; c_y = @y + @h / 2
		o_c_x = obj.x + obj.w / 2; o_c_y = obj.y + obj.h / 2
		sq_dist = (o_c_x - c_x)**2 + (o_c_y - c_y)**2
		sq_dist <= radius**2
	end
	
	def collide? obj
		bounds.intersects obj.bounds
	end
	
	def over? obj
		@x + @w > obj.x and obj.x + obj.w > @x and
			@y < obj.y - C::PlayerOverTolerance and @y + @h > obj.y and
			@speed.y > 0
	end
	
	def reset
		@will_explode = false
		@exploding = false
		@speed.x = @speed.y = 0
		set_direction :right
	end
	
	def is_visible map
		true
	end
	
	def draw map
		super map
		if @will_explode
			G.font.draw_rel Res.text(:count_down), 400, 200, 0, 0.5, 0.5, 1, 1, 0xff000000 if @explosion_counter > 6
			G.font.draw_rel @explosion_counter.to_s, 400, 220, 0, 0.5, 0.5, 1, 1, 0xff000000
		end
		@explosion.draw map if @exploding
	end
end
