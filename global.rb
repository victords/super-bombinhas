require 'joystick'

Vector = Struct.new :x, :y

module C
	Up = 0
	Right = 1
	Down = 2
	Left = 3
	TileSize = 32
	ScreenWidth = 800
	ScreenHeight = 600
end

class G	
	def self.window
		@@window
	end
	def self.gravity
		@@gravity
	end
	def self.gravity= value
		@@gravity = value
	end
	def self.lang
		@@lang
	end
	def self.lang= value
		@@lang = value
	end
	
	def self.initialize window
		@@window = window
		@@gravity = Vector.new 0, 1
		@@lang = :portuguese
	end
end

class Rectangle
	attr_reader :x, :y, :w, :h
	
	def initialize x, y, w, h
		@x = x; @y = y; @w = w; @h = h
	end
	
	def intersects r
		@x < r.x + r.w && @x + @w > r.x && @y < r.y + r.h && @y + @h > r.y
	end
end

class JSHelper
	attr_reader :is_valid
	
	def initialize index
		@j = Joystick::Device.new "/dev/input/js#{index}"
		@axes = {}
		@axesPrev = {}
		@btns = {}
		@btnsPrev = {}
		if @j
			e = @j.event(true)
			while e
				if e.type == :axis
					@axes[e.number] = @axesPrev[e.number] = 0
				else
					@btns[e.number] = @btnsPrev[e.number] = 0
				end
				e = @j.event(true)
			end
			@is_valid = true
		else
			@is_valid = false
		end
	end
	
	def update
		return if !@is_valid
		
		for k in @axesPrev.keys
			@axesPrev[k] = 0
		end
		for k in @btnsPrev.keys
			@btnsPrev[k] = 0
		end
		
		e = @j.event(true)
		while e
			if e.type == :axis
				@axesPrev[e.number] = @axes[e.number]
				@axes[e.number] = e.value
			else
				@btnsPrev[e.number] = @btns[e.number]
				@btns[e.number] = e.value
			end
			e = @j.event(true)
		end
	end
	
	def button_down btn
		return false if !@is_valid
		@btns[btn] == 1
	end
	
	def button_pressed btn
		return false if !@is_valid
		@btns[btn] == 1 && @btnsPrev[btn] == 0
	end
	
	def button_released btn
		return false if !@is_valid
		@btns[btn] == 0 && @btnsPrev[btn] == 1
	end
	
	def axis_down axis, dir
		return false if !@is_valid
		return @axes[axis+1] < 0 if dir == C::Up
		return @axes[axis] > 0 if dir == C::Right
		return @axes[axis+1] > 0 if dir == C::Down
		return @axes[axis] < 0 if dir == C::Left
	end
	
	def axis_pressed axis, dir
		return false if !@is_valid
		return @axes[axis+1] < 0 && @axesPrev[axis+1] >= 0 if dir == C::Up
		return @axes[axis] > 0 && @axesPrev[axis] <= 0 if dir == C::Right
		return @axes[axis+1] > 0 && @axesPrev[axis+1] <= 0 if dir == C::Down
		return @axes[axis] < 0 && @axesPrev[axis] >= 0 if dir == C::Left
	end
	
	def axis_released axis, dir
		return false if !@is_valid
		return @axes[axis+1] >= 0 && @axesPrev[axis+1] < 0 if dir == C::Up
		return @axes[axis] <= 0 && @axesPrev[axis] > 0 if dir == C::Right
		return @axes[axis+1] <= 0 && @axesPrev[axis+1] > 0 if dir == C::Down
		return @axes[axis] >= 0 && @axesPrev[axis] < 0 if dir == C::Left
	end
	
	def close
		@j.close if @is_valid
	end
end
