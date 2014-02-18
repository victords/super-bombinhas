require './game_object'

class MapStage < Sprite
	attr_reader :name
	
	def initialize world, num, x, y, img, glows = true
		super x, y, "other_#{img}"
		@state = 0
		if glows
			@alpha = 0xff
		else
			@alpha = 0x7f
		end
		@color = 0x00ffffff | (@alpha << 24)
		@glows = glows
		
		@name = Res.text("stage_#{world}_#{num+1}").split '|'
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
		@num = 1
		@name = Res.text "world_#{@num}"
		
		@water = Sprite.new 0, 0, :other_water, 2, 2
		@parchment = Res.img :other_parchment
		@mark = Res.img :other_mark
		@map = Res.img :other_world1
		@bomb = Sprite.new 631, 245, :sprite_BombaAzul, 5, 2
		
		@stages = []
		File.open("data/stage/#{@num}/world").each_with_index do |l, i|
			coords = l.split ','
			@stages << MapStage.new(@num, i, coords[0].to_i, coords[1].to_i, :unknown, false)
		end
		@cur = 0
	end
	
	def update
		@water.animate [0, 1, 2, 3], 6
		@bomb.animate [0, 1, 0, 2], 8
		@stages.each { |i| i.update }
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
		@stages.each { |s| s.draw }
		@bomb.draw
		
		G.font.draw_rel "Choose your destiny!", 525, 20, 0, 0.5, 0, 2, 2, 0xff000000		
		G.font.draw_rel @name, 125, 100, 0, 0.5, 0, 1, 1, 0xff3d361f
		G.font.draw_rel "*** Stage #{@num}-#{@cur+1} ***", 125, 125, 0, 0.5, 0, 1, 1, 0xff3d361f
		@stages[@cur].name.each_with_index do |n, i|
			G.font.draw_rel n, 125, 150 + i * 25, 0, 0.5, 0, 1, 1, 0xff3d361f
		end
	end
end
