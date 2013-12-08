#!/home/victor/.rvm/rubies/ruby-2.0.0-p247/bin/ruby
#encoding: UTF-8

require 'gosu'
require './resources'
require './movement'
require './ramp'
require './elevator'
require './map'
require './stage'

class GameObject
	include Movement
	def initialize(x, y, w, h, img, img_x = 0, img_y = 0, passable = false)
		@x = x
		@y = y
		@w = w
		@h = h
		@img_x = img_x
		@img_y = img_y
		@speed = Vector.new(0, 0)
		@stored_forces = Vector.new(0, 0)
		@passable = passable
		@img = Res.img(img)
	end
	
	def draw
		@img.draw(@x + @img_x, @y + @img_y, 0)
	end
	
#	def draw(map)
#		@img.draw(@x + @img_x - map.cam.x, @y + @img_y - map.cam.y, 0)
#	end
end

class Game < Gosu::Window
	def initialize
		super 800, 600, false
		self.caption = "Super Bombinhas"
		G.initialize(self)
		Res.initialize
		
		@obj1 = GameObject.new(0, 0, 50, 50, :sprite_Ball)
		@obj2 = GameObject.new(100, 0, 50, 50, :sprite_Ball)
		@obj3 = GameObject.new(200, 0, 50, 50, :sprite_Ball)
		@obj4 = GameObject.new(300, 0, 50, 50, :sprite_Elevator1)
		@obj5 = GameObject.new(0, 100, 50, 50, :fx_Balao1)
		@obj6 = GameObject.new(100, 100, 50, 50, :fx_Balao2)
		@obj7 = GameObject.new(200, 100, 50, 50, :fx_Balao2)
		
		@menu = Res.img(:other_stageMenu, true)
#		@song = Res.song(:caveTheme)
#		@song.play
		
		@frame = 0
		
		@stage = Stage.new 2
	end

	def update
		@frame += 1
		if @frame == 60
			@frame = 0
		end
	end

	def draw
		@obj1.draw
		@obj2.draw
		@obj3.draw
		@obj4.draw
		@obj5.draw
		@obj6.draw
		@obj7.draw
		
		@menu.draw(300, 100, 0)
	end
end

game = Game.new
game.show
