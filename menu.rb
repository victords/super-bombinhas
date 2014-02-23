require './world'
require './player'

class Menu
	def initialize
		@bg = Res.img :bg_start1, true, false, ".jpg"
		@title = Res.img :other_title, true
	end
	
	def update
		if KB.key_pressed? Gosu::KbA
			G.world = World.new
			G.player = Player.new
			G.state = :map
		end
	end
	
	def draw
		@bg.draw 0, 0, 0
		@title.draw 0, 0, 0
		G.font.draw_rel "Press 'A' to start", 400, 300, 0, 0.5, 0.5, 2, 2, 0xff000000
	end
end
