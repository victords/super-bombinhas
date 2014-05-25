require 'joystick'
require 'minigl'

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
	
	def self.menu; @@menu; end
	def self.menu= value; @@menu = value; end
	def self.player; @@player; end
	def self.player= value; @@player = value; end
	def self.world; @@world; end
	def self.world= value; @@world = value; end
	def self.stage; @@stage; end
	def self.stage= value; @@stage = value; end
	
	def self.initialize
		@@state = :menu
		
		@@window = Game.window		
		@@font = Gosu::Font.new @@window, "data/font/BankGothicMedium.ttf", 20
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
	end
	
	def self.text id
		@@texts[@@lang][id.to_sym]
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
