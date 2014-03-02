require './world'
require './player'
require './forms'

class Menu
	def initialize
		@bg = Res.img :bg_start1, true, false, ".jpg"
		@title = Res.img :other_title, true
		@cursor = Sprite.new 180, 288, :other_cursor, 4, 2
		@cursor_indices = [0, 1, 2, 3, 4, 5, 6, 7]
		@cursor_timer = 0
		@cursor_state = 0
		
		@btn = TestButton.new(400, 400, "Play", :other_btn1) do
			G.world = World.new
			G.player = Player.new
			G.state = :map
		end
	end
	
	def update
		@btn.update
		
		if KB.key_pressed? Gosu::KbA
			G.world = World.new
			G.player = Player.new
			G.state = :map
		end
		@cursor.animate @cursor_indices, 5
		@cursor_timer += 1
		if @cursor_timer == 10
			if @cursor_state < 3; @cursor.x += @cursor_state + 1
			else; @cursor.x -= 6 - @cursor_state; end
			@cursor_state += 1
			@cursor_state = 0 if @cursor_state == 6
			@cursor_timer = 0
		end
	end
	
	def draw
		@bg.draw 0, 0, 0
		@title.draw 0, 0, 0
		@cursor.draw
		G.font.draw_rel "Press 'A' to start", 400, 300, 0, 0.5, 0.5, 2, 2, 0xff000000
		@btn.draw
	end
end
