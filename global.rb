require 'joystick'
require './player'

Vector = Struct.new :x, :y

module C
	TileSize = 32
	ScreenWidth = 800
	ScreenHeight = 600
	PlayerOverTolerance = 10
	InvulnerableTime = 40
	BounceForce = 15
	TopMargin = -200
end

class G
	def self.window; @@window; end
	def self.player; @@player; end
	def self.switches; @@switches; end
	def self.gravity; @@gravity; end
	def self.gravity= value; @@gravity = value; end
	def self.lang; @@lang; end
	def self.lang= value; @@lang = value; end
	def self.font; @@font; end
	def self.texts; @@texts; end
	
	def self.initialize window
		@@window = window
		@@player = Player.new
		@@switches = []
		@@gravity = Vector.new 0, 0.9
		@@lang = :spanish
		@@font = Font.new window, "data/font/BankGothicMedium.ttf", 20
		@@texts = {}
		files = Dir["data/text/*.txt"]
		files.each do |f|
			lang = (f.split('/')[-1].chomp ".txt").to_sym
			@@texts[lang] = {}
			File.open(f).each do |l|
				parts = l.split "\t"
				@@texts[lang][parts[0].to_sym] = parts[-1].chomp
			end
		end
	end
	
	def self.find_switch obj
		@@switches.each do |s|
			return s if s[:obj] == obj
		end
		nil
	end
	
	def self.set_switch obj
		switch = self.find_switch obj
		switch[:state] = :temp_taken
	end
	
	def self.reset_switches
		@@switches.each do |s|
			if s[:state] == :temp_taken or s[:state] == :temp_taken_used
				s[:state] = :normal
			elsif s[:state] == :temp_used
				s[:state] = :taken
			end
			s[:obj] = s[:type].new(s[:x], s[:y], s[:args], s[:section], s)
		end
	end
	
	def self.save_switches
		@@switches.each do |s|
			if s[:state] == :temp_taken
				s[:state] = :taken
			elsif s[:state] == :temp_used or s[:state] == :temp_taken_used
				s[:state] = :used
			end
		end
	end
end

class Rectangle
	attr_accessor :x, :y, :w, :h
	
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
		return @axes[axis+1] < 0 if dir == :up
		return @axes[axis] > 0 if dir == :right
		return @axes[axis+1] > 0 if dir == :down
		return @axes[axis] < 0 if dir == :left
	end
	
	def axis_pressed axis, dir
		return false if !@is_valid
		return @axes[axis+1] < 0 && @axesPrev[axis+1] >= 0 if dir == :up
		return @axes[axis] > 0 && @axesPrev[axis] <= 0 if dir == :right
		return @axes[axis+1] > 0 && @axesPrev[axis+1] <= 0 if dir == :down
		return @axes[axis] < 0 && @axesPrev[axis] >= 0 if dir == :left
	end
	
	def axis_released axis, dir
		return false if !@is_valid
		return @axes[axis+1] >= 0 && @axesPrev[axis+1] < 0 if dir == :up
		return @axes[axis] <= 0 && @axesPrev[axis] > 0 if dir == :right
		return @axes[axis+1] <= 0 && @axesPrev[axis+1] > 0 if dir == :down
		return @axes[axis] >= 0 && @axesPrev[axis] < 0 if dir == :left
	end
	
	def close
		@j.close if @is_valid
	end
end

class KB
	def self.initialize
		@@keys = [
			Gosu::KbUp, Gosu::KbRight, Gosu::KbDown, Gosu::KbLeft,
			Gosu::KbSpace, Gosu::KbReturn, Gosu::KbBackspace, Gosu::KbEscape,
			Gosu::KbLeftControl, Gosu::KbRightControl, Gosu::KbLeftShift, Gosu::KbRightShift,
			Gosu::KbA
		]
		@@down = []
		@@prev_down = []
	end
	
	def self.update
		@@prev_down = @@down.clone
		@@down.clear
		@@keys.each do |k|
			if G.window.button_down? k
				@@down << k
			end
		end
	end
	
	def self.key_pressed? key
		@@prev_down.index(key).nil? and @@down.index(key)
	end
	
	def self.key_down? key
		@@down.index(key)
	end
	
	def self.key_released? key
		@@prev_down.index(key) and @@down.index(key).nil?
	end
end
