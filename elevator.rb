require 'gosu'
require './global.rb'

class Elevator
	attr_reader :x, :y, :w, :h, :passable
	
	def initialize(x, y, w, h, speed, window, img)
		@x = x; @y = y; @w = w; @h = h
		@speed = Vector.new(0, 0)
		@speed_m = speed
		@point = 0
		@moving = false
		@passable = true
		@img = Gosu::Image.new(window, img)
	end
	
	def move_to(x, y, obst)
		if !@moving
			x_dist = x - @x; y_dist = y - @y
			puts "#{x_dist} #{y_dist}"
			freq = @speed_m / Math.sqrt(x_dist * x_dist + y_dist * y_dist)
			@speed.x = x_dist * freq
			@speed.y = y_dist * freq
			@moving = true
		end
		x_aim = @x + @speed.x; y_aim = @y + @speed.y
		passengers = []
		obst.each do |o|
			if @x + @w > o.x && o.x + o.w > @x
				foot = o.y + o.h
				if foot.round(6) == @y.round(6) || @speed.y < 0 && foot < @y && foot > y_aim
					passengers.push(o)
				end
			end
		end
		
		if @speed.x > 0 && x_aim >= x || @speed.x < 0 && x_aim <= x
			passengers.each do |p| p.x += x - @x end
			@x = x; @speed.x = 0
		else
			passengers.each do |p| p.x += @speed.x end
			@x = x_aim
		end
		if @speed.y > 0 && y_aim >= y || @speed.y < 0 && y_aim <= y
			@y = y; @speed.y = 0
		else; @y = y_aim; end
		passengers.each do |p| p.y = @y - p.h end
		@moving = false if @speed.x == 0 && @speed.y == 0
	end
	
	def cycle(points, obst)
		move_to(points[@point][0], points[@point][1], obst)
		if !@moving
			if @point == points.length - 1; @point = 0
			else; @point += 1; end
		end
	end
	
	def is_visible
		true
	end
	
	def draw
		@img.draw(@x, @y, 0)
	end
end
