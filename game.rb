#!/home/victor/.rvm/rubies/ruby-2.0.0-p353/bin/ruby
#encoding: UTF-8

require_relative 'menu'

class SBGame < Gosu::Window
	def initialize
		super C::SCREEN_WIDTH, C::SCREEN_HEIGHT, false
		self.caption = 'Super Bombinhas'

		Game.initialize self, Vector.new(0, 0.9)
		G.initialize
		G.menu = Menu.new

#		@frame = 0
	end

	def needs_cursor?
		G.state != :main
	end

	def update
#		@frame += 1
#		if @frame == 60
#			puts @fps
#			@frame = 0
#		end
		KB.update
		Mouse.update

		close if KB.key_pressed? Gosu::KbEscape

		if G.state == :presentation

		elsif G.state == :menu
			G.menu.update
		elsif G.state == :map
			G.world.update
		elsif G.state == :main
			G.stage.update
		end
	end

	def draw
		if G.state == :presentation

		elsif G.state == :menu
			G.menu.draw
		elsif G.state == :map
			G.world.draw
		elsif G.state == :main
			G.stage.draw
		end
	end
end

class AGL::GameObject
	def is_visible map
		return map.cam.intersects @active_bounds if @active_bounds
		false
	end

	def dead?
		@dead
	end
end

game = SBGame.new
game.show
