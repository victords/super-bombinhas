require 'joystick'

Vector = Struct.new :x, :y

module C
	TileSize = 32
	ScreenWidth = 800
	ScreenHeight = 600
	PlayerOverTolerance = 10
	InvulnerableTime = 40
	BounceForce = 10
	TopMargin = -200
end

class G
	def self.state; @@state; end
	def self.state= value; @@state = value; end
	
	def self.window; @@window; end
	def self.font; @@font; end
	def self.texts; @@texts; end
	def self.lang; @@lang; end
	def self.lang= value; @@lang = value; end
	def self.gravity; @@gravity; end
	def self.gravity= value; @@gravity = value; end
	
	def self.menu; @@menu; end
	def self.menu= value; @@menu = value; end
	def self.player; @@player; end
	def self.player= value; @@player = value; end
	def self.world; @@world; end
	def self.world= value; @@world = value; end
	def self.stage; @@stage; end
	def self.stage= value; @@stage = value; end
	
	def self.initialize window
		@@state = :menu
		
		@@window = window		
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
		@@lang = :portuguese
		@@gravity = Vector.new 0, 0.9
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
			Gosu::KbUp, Gosu::KbDown,
			Gosu::KbReturn, Gosu::KbEscape,
			Gosu::KbLeftControl, Gosu::KbRightControl,
			Gosu::KbA, Gosu::KbB, Gosu::KbC, Gosu::KbD, Gosu::KbE, Gosu::KbF,
			Gosu::KbG, Gosu::KbH, Gosu::KbI, Gosu::KbJ, Gosu::KbK, Gosu::KbL,
			Gosu::KbM, Gosu::KbN, Gosu::KbO, Gosu::KbP, Gosu::KbQ, Gosu::KbR,
			Gosu::KbS, Gosu::KbT, Gosu::KbU, Gosu::KbV, Gosu::KbW, Gosu::KbX,
			Gosu::KbY, Gosu::KbZ, Gosu::Kb1, Gosu::Kb2, Gosu::Kb3, Gosu::Kb4,
			Gosu::Kb5, Gosu::Kb6, Gosu::Kb7, Gosu::Kb8, Gosu::Kb9, Gosu::Kb0,
			Gosu::KbNumpad1, Gosu::KbNumpad2, Gosu::KbNumpad3, Gosu::KbNumpad4,
			Gosu::KbNumpad5, Gosu::KbNumpad6, Gosu::KbNumpad7, Gosu::KbNumpad8,
			Gosu::KbNumpad9, Gosu::KbNumpad0, Gosu::KbSpace, Gosu::KbBackspace,
			Gosu::KbDelete, Gosu::KbLeft, Gosu::KbRight, Gosu::KbHome,
			Gosu::KbEnd, Gosu::KbLeftShift, Gosu::KbRightShift,
			Gosu::KbBacktick, Gosu::KbMinus, Gosu::KbEqual, Gosu::KbBracketLeft,
			Gosu::KbBracketRight, Gosu::KbBackslash, Gosu::KbApostrophe,
			Gosu::KbComma, Gosu::KbPeriod, Gosu::KbSlash
		]
		@@down = []
		@@prev_down = []
		@@held_timer = {}
		@@held_interval = {}
	end
	
	def self.update
		@@held_timer.each do |k, v|
			if v < 40; @@held_timer[k] += 1
			else
				@@held_interval[k] = 0
				@@held_timer.delete k
			end
		end
		
		@@held_interval.each do |k, v|
			if v < 5; @@held_interval[k] += 1
			else; @@held_interval[k] = 0; end
		end
		
		@@prev_down = @@down.clone
		@@down.clear
		@@keys.each do |k|
			if G.window.button_down? k
				@@down << k
				@@held_timer[k] = 0 if @@prev_down.index(k).nil?
			elsif @@prev_down.index(k)
				@@held_timer.delete k
				@@held_interval.delete k
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
	
	def self.key_held? key
		@@held_interval[key] == 5
	end
end

class Mouse
	def self.initialize
		@@down = {}
		@@prev_down = {}
		@@dbl_click = {}
		@@dbl_click_timer = {}
	end
	
	def self.update
		@@prev_down = @@down.clone
		@@down.clear
		@@dbl_click.clear
		
		@@dbl_click_timer.each do |k, v|
			if v < 8; @@dbl_click_timer[k] += 1
			else; @@dbl_click_timer.delete k; end
		end
		
		k1 = [Gosu::MsLeft, Gosu::MsMiddle, Gosu::MsRight]
		k2 = [:left, :middle, :right]
		for i in 0..2
			if G.window.button_down? k1[i]
				@@down[k2[i]] = true
				@@dbl_click[k2[i]] = true if @@dbl_click_timer[k2[i]]
				@@dbl_click_timer.delete k2[i]
			elsif @@prev_down[k2[i]]
				@@dbl_click_timer[k2[i]] = 0
			end
		end
		
		@@x = G.window.mouse_x.round
		@@y = G.window.mouse_y.round
	end
	
	def self.x; @@x; end
	def self.y; @@y; end
	
	def self.button_pressed? btn
		@@down[btn] and not @@prev_down[btn]
	end
	
	def self.button_down? btn
		@@down[btn]
	end
	
	def self.button_released? btn
		@@prev_down[btn] and not @@down[btn]
	end
	
	def self.double_click? btn
		@@dbl_click[btn]
	end
	
	def self.over? x, y, w, h
		@@x >= x and @@x < x + w and @@y >= y and @@y < y + h
	end
end
