#!/home/victor/.rvm/rubies/ruby-2.0.0-p353/bin/ruby
#encoding: UTF-8

require 'gosu'
require './menu'

class Game < Gosu::Window
	attr_reader :frame
	
	def initialize
		super C::ScreenWidth, C::ScreenHeight, false
		self.caption = "Super Bombinhas"
		
		Res.initialize
		KB.initialize
		G.initialize self
		G.menu = Menu.new
		
		@frame = 0
	end
	
	def update
		@frame += 1
		if @frame == 60
			puts G.window.send(:fps)
			@frame = 0
		end
		KB.update
		
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

game = Game.new
game.show
