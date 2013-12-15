#!/home/victor/.rvm/rubies/ruby-2.0.0-p353/bin/ruby
#encoding: UTF-8

require 'gosu'
require './stage'

class Game < Gosu::Window
	attr_reader :frame
	
	def initialize
		super C::ScreenWidth, C::ScreenHeight, false
		self.caption = "Super Bombinhas"
		G.initialize(self)
		Res.initialize
		
		@frame = 0
		
		@stage = Stage.new 2
	end

	def update
		@frame += 1
#		if @frame == 60
#			@frame = 0
#		end
		
		@stage.update
	end

	def draw
		@stage.draw
	end
end

game = Game.new
game.show
puts game.frame
