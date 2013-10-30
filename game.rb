#encoding: UTF-8

require 'gosu'
require './movement.rb'
require './ramp.rb'
require './elevator.rb'
require './map.rb'

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

		@j = JSHelper.new(0)
		
		PhysicalEnvironment.initialize
		#PhysicalEnvironment.gravity = Vector.new(0, 0)
		@obj = GameObject.new(self, "face.png", 10, 10, 100, 100)
		@obst = []
		for i in 1..12
			@obst.push(GameObject.new(self, "test.png", 400, 32 * i, 32, 32))
			@obst.push(GameObject.new(self, "test.png", 32 * i, 400, 32, 32))
		end
		@ramps = []
		@ramps.push(Ramp.new(300, 340, 100, 60, true))
		
		@el = Elevator.new(0, 0, 100, 20, 4, self, "el.png")
		@obst.push(@el)
		
		@map = Map.new(32, 32, 10, 10)
	end

	def update
		if button_down? Gosu::KbEscape
			@j.close
			close
		end
		#puts "#{@obj.x} #{@obj.y}"
		@j.update
		
		forces = Vector.new(0, 0)
		forces.x -= 0.5 if @j.axis_down(0, Direction::LEFT)
		forces.x += 0.5 if @j.axis_down(0, Direction::RIGHT)
		forces.y -= 15 if @j.axis_down(0, Direction::UP) && @obj.bottom
		if @obj.bottom
			forces.x -= 0.15 if @obj.speed.x > 0
			forces.x += 0.15 if @obj.speed.x < 0
		end
		@obj.move(forces, @obst, @ramps)
		
		@el.cycle([[300, 10], [87, 330], [0, 0]], [@obj])
	end

	def draw
		@obj.draw
		@obst.each do |o| o.draw end
		@el.draw
#		@ramps.each do |r|
#			
#		end
	end
end

game = Game.new
game.show
