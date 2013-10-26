#encoding: UTF-8

require 'gosu'
require 'joystick'
require './movement.rb'

class GameObject
	include Movement
	def initialize(window, img, x, y, w, h, passable = false)
		@x = x
		@y = y
		@w = w
		@h = h
		@speed = Vector.new(0, 0)
		@stored_forces = Vector.new(0, 0)
		@passable = passable
		@img = Gosu::Image.new(window, img)
	end
	
	def draw
		@img.draw(@x, @y, 0)
	end
end

class Game < Gosu::Window
	def initialize
		super 800, 600, false
		self.caption = "Super Bombinhas"

		@j = Joystick::Device.new "/dev/input/js0"    
		begin e = @j.event(true) end while e
		
		PhysicalEnvironment.initialize
		#PhysicalEnvironment.gravity = Vector.new(0, 0)
		@obj = GameObject.new(self, "face.png", 10, 10, 100, 100)
		@obst = []		
		for i in 1..12
			@obst.push(GameObject.new(self, "test.png", 400, 32 * i, 32, 32))
			@obst.push(GameObject.new(self, "test.png", 32 * i, 400, 32, 32))
		end
	end

	def update
		e = @j.event(true)
		if e
			close if e.value == 1
		end

		if button_down? Gosu::KbEscape
			@j.close
			close
		end
		
		forces = Vector.new(0.4, 0)
		@obj.move(forces, @obst, [])
	end

	def draw
		@obj.draw
		@obst.each do |o| o.draw end
	end
end

game = Game.new
game.show
