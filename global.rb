# global definitions

Vector = Struct.new(:x, :y)

class Rectangle
	attr_reader :x, :y, :w, :h
	
	def initialize(x, y, w, h)
		@x = x; @y = y; @w = w; @h = h
	end
	
	def intersects(r)
		@x < r.x + r.w && @x + @w > r.x && @y < r.y + r.h && @y + @h > r.y
	end
end

class Ramp
	
end

class PhysicalEnvironment
	def self.gravity
		@@gravity
	end
	def self.gravity=(value)
		@@gravity = value
	end
	
	def self.initialize
		@@gravity = Vector.new(0, 1)
	end
end
