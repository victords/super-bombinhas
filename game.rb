#!/home/victor/.rvm/rubies/ruby-2.0.0-p353/bin/ruby
#encoding: UTF-8

require 'gosu'
require './world'
require './stage'
require './player'

class Game < Gosu::Window
	attr_reader :frame
	
	def initialize
		super C::ScreenWidth, C::ScreenHeight, false
		self.caption = "Super Bombinhas"
		
		Res.initialize
		G.initialize(self)
		G.player = Player.new
		KB.initialize
		
		@frame = 0		
#		@stage = Stage.new 100
		@world = World.new
	end

	def update
		@frame += 1
		if @frame == 60
			puts G.window.send(:fps)
			@frame = 0
		end
		
		KB.update
#		@stage.update
		@world.update
	end

	def draw
#		@stage.draw
		@world.draw
	end
end

game = Game.new
game.show
