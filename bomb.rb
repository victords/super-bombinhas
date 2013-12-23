require './game_object'

class Bomb < GameObject
	def initialize x, y, type
		t_img_gap = -10
		case type
		when :azul then @name = "Bomba Azul"; img = :sprite_BombaAzul; l_img_gap = -5; r_img_gap = -5
		when :vermelha then @name = "Bomba Vermelha"; img = :sprite_BombaVermelha; l_img_gap = -4; r_img_gap = -6
		when :amarela then @name = "Bomba Amarela"; img = :sprite_BombaAmarela; l_img_gap = -6; r_img_gap = -14
		when :verde then @name = "Bomba Verde"; img = :sprite_BombaVerde; l_img_gap = -6; r_img_gap = -14
		when :aldan then @name = "Aldan"; img = :sprite_Aldan; l_img_gap = -6; r_img_gap = -14; t_img_gap = -26
		end
		
		super x + 6, y + 2, 20, 30, img, Vector.new(r_img_gap, t_img_gap), 5, 2
		@max_speed.x = 5
		@indices = [0, 1, 0, 2]
		@facing_right = true
		@type = type
	end
	
	def update section
		forces = Vector.new 0, 0
		if G.window.button_down? Gosu::KbLeft
			set_direction :left if @facing_right
			forces.x -= 0.15
		elsif @speed.x < 0
			forces.x -= 0.15 * @speed.x
		end
		if G.window.button_down? Gosu::KbRight
			set_direction :right if not @facing_right
			forces.x += 0.15
		elsif @speed.x > 0
			forces.x -= 0.15 * @speed.x
		end
		if G.window.button_down? Gosu::KbSpace and @bottom
			forces.y -= 7.1 + 0.2 * @speed.x.abs
		end
		move forces, section.obstacles, section.ramps
		if @speed.x != 0
			animate @indices, 30 / @speed.x.abs
		elsif @facing_right
			set_animation 0
		else
			set_animation 5
		end
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
	
	def is_visible map
		true
	end
end
