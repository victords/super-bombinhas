require './game_object'

class MapIcon < Sprite
	def initialize x, y, img, glows = true
		super x, y, img
		@state = 0
		if glows
			@alpha = 0xff
		else
			@alpha = 0x7f
		end
		@color = 0x00ffffff | (@alpha << 24)
		@glows = glows
	end
	
	def update
		return unless @glows
		if @state == 0
			@alpha -= 1
			if @alpha == 51
				@state = 1
			end
			@color = 0x00ffffff | (@alpha << 24)
		else
			@alpha += 1
			if @alpha == 0xff
				@state = 0
			end
			@color = 0x00ffffff | (@alpha << 24)
		end
	end
	
	def draw
		@img[0].draw @x, @y, 0, 1, 1, @color
	end
end

class World
	def initialize
		@water = Sprite.new 0, 0, :other_water, 2, 2
		@parchment = Res.img :other_parchment
		@mark = Res.img :other_mark
		@map = Res.img :other_world1
		@icons = [
			MapIcon.new(400, 200, :other_complete),
			MapIcon.new(630, 270, :other_complete),
			MapIcon.new(519, 410, :other_current),
			MapIcon.new(450, 370, :other_unknown, false)
		]
		@bomb = Sprite.new 631, 245, :sprite_BombaAzul, 5, 2
	end
	
	def update
		@water.animate [0, 1, 2, 3], 6
		@bomb.animate [0, 1, 0, 2], 8
		@icons.each { |i| i.update }
	end
	
	def draw
		G.window.draw_quad 0, 0, 0xff6ab8ff,
		                   800, 0, 0xff6ab8ff,
		                   800, 600, 0xff6ab8ff,
		                   0, 600, 0xff6ab8ff, 0
		y = 0
		while y < C::ScreenHeight
			x = 0
			while x < C::ScreenWidth
				@water.x = x; @water.y = y
				@water.draw
				x += 40
			end
			y += 40
		end
		@parchment.draw 0, 0, 0
		@mark.draw 190, 510, 0
		
		@map.draw 250, 100, 0		
		@icons.each { |i| i.draw }		
		@bomb.draw
		
		G.font.draw_rel "Choose your destiny!", 525, 20, 0, 0.5, 0, 2, 2, 0xff000000
		G.font.draw_rel "Tars Island", 125, 100, 0, 0.5, 0, 1, 1, 0xff3d361f
		G.font.draw_rel "*** Stage 1-4 ***", 125, 125, 0, 0.5, 0, 1, 1, 0xff3d361f
		G.font.draw_rel "The Ruins of", 125, 150, 0, 0.5, 0, 1, 1, 0xff3d361f
		G.font.draw_rel "the ancient", 125, 175, 0, 0.5, 0, 1, 1, 0xff3d361f
		G.font.draw_rel "monastery", 125, 200, 0, 0.5, 0, 1, 1, 0xff3d361f
	end
end
