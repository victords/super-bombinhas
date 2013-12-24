require './global'
require './ramp'
require './elements'
require './bomb'
require './map'

Tile = Struct.new :back, :fore, :pass, :wall, :hidden

class Section
	attr_reader :entrance, :reload, :obstacles, :ramps, :loaded
	attr_accessor :warp, :locked_door
	
	def initialize file, entrances
		parts = File.read(file).split '#'
		p1 = parts[0].split ','
		set_map_tileset_bg p1
		p2 = parts[1].split ';'
		set_elements p2, entrances
		p3 = parts[2].split ';'
		set_ramps p3
		@taken_items = []
	end
	
	# initialization
	def set_map_tileset_bg s
		t_x_count = s[0].to_i; t_y_count = s[1].to_i
		@tiles = Array.new(t_x_count) {
			Array.new(t_y_count) {
				Tile.new -1, -1, -1, -1, false
			}
		}
		@border_exit = s[2].to_i # 0: top, 1: right, 2: down, 3: left, 4: none
		@bg1 = Res.img "bg_#{s[3]}".to_sym, false, ".jpg"
		@bg2 = Res.img "bg_#{s[4]}".to_sym if s[4] != "0"
		@tileset = Res.tileset s[5]
		@map = Map.new C::TileSize, C::TileSize, t_x_count, t_y_count
		@map.set_camera 4500, 1200
	end
	
	def set_elements s, entrances
		x = 0; y = 0
		@element_info = []
		@hiding_walls = []
		@obstacles = []
		s.each do |e|
			if e[0] == '_'; x, y = set_spaces e[1..-1].to_i, x, y
			elsif e[3] == '*'; x, y = set_tiles e[4..-1].to_i, x, y, tile_type(e[0]), e[1, 2]
			else
				i = 0
				begin
					t = tile_type e[i]
					if t != :none
						set_tile x, y, t, e[i+1, 2]
					else
						if e[i] == '!'
							entrances[e[(i+1)..-1].to_i] = {x: x * C::TileSize, y: y * C::TileSize, section: self}
						else
							t, a = element_type e[(i+1)..-1]
							if t != :none # teste poderá ser removido no final
								el = {x: x * C::TileSize, y: y * C::TileSize, type: t, args: a}
								el[:index] = @element_info.length if e[i] == '$'
								@element_info << el
							end           # teste poderá ser removido no final
						end
						i += 1000
					end
					i += 3
				end until e[i].nil?
				x += 1
				begin y += 1; x = 0 end if x == @tiles.length
			end
		end
	end
	
	def tile_type c
		case c
			when 'B' then :back
			when 'F' then :fore
			when 'P' then :pass
			when 'W' then :wall
			else :none
		end
	end
	
	def element_type s
		i = s.index ':'
		if i; n = s[0..i].to_i
		else; n = s.to_i; end
		type = case n
			when  1 then :Wheeliam
			when  2 then :FireRock
			when  3 then :Bombie
			when  4 then :Sprinny
			when  7 then :Life
			when  8 then :Key
			when  9 then :Door
			when 12 then :GunPowder
			when 13 then :Crack
			when 17 then :Elevator
			when 18 then :Fureel
			when 20 then :SaveBombie
			when 21 then :Pin
			when 23 then :Spikes
			when 24 then :Attack1
			when 25 then :MovingWall
			when 26 then :Ball
			when 27 then :BallReceptor
			when 28 then :Yaw
			when 29 then :Ekips
			when 31 then :Spec
			when 32 then :Faller
			when 33 then :Turner
			else :none
		end
		args = s[(i+1)..-1] if i
		[type, args]
	end
	
	def set_spaces amount, x, y
		x += amount
		if x >= @tiles.length
			y += x / @tiles.length
			x %= @tiles.length
		end
		[x, y]
	end
	
	def set_tiles amount, x, y, type, s
		amount.times do
			set_tile x, y, type, s
			x += 1
			begin y += 1; x = 0 end if x == @tiles.length
		end
		[x, y]
	end
	
	def set_tile x, y, type, s
		@tiles[x][y].send "#{type}=", s.to_i
		if type == :pass
			@obstacles << Block.new(x * C::TileSize, y * C::TileSize, C::TileSize, C::TileSize, true)
		elsif type == :wall
			@obstacles << Block.new(x * C::TileSize, y * C::TileSize, C::TileSize, C::TileSize, false)
		end
	end
	
	def set_ramps s
		@ramps = []
		s.each do |r|
			left = r[0] == 'l'
			w = r[1].to_i * C::TileSize
			h = r[2].to_i * C::TileSize
			coords = r.split(':')[1].split(',')
			x = coords[0].to_i * C::TileSize
			y = coords[1].to_i * C::TileSize
			@ramps << Ramp.new(x, y, w, h, left)
		end
	end
	#end initialization
	
	def load x, y
		G.player.clear
		@taken_items.each do |i|
			G.player.add_item i[:type]
		end
		@temp_taken_items = []
		@elements = []
		@element_info.each do |e|
			if e[:index]
				@elements << Object.const_get(e[:type]).new(e[:x], e[:y], e[:args], e[:index])
			else
				@elements << Object.const_get(e[:type]).new(e[:x], e[:y], e[:args])
			end
		end
		@elements << (@bomb = Bomb.new(x, y, :azul))
		@margin = Vector.new((C::ScreenWidth - @bomb.w) / 2, (C::ScreenHeight - @bomb.h) / 2)
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
		
		map_size = @map.get_absolute_size
		@obstacles << Block.new(map_size.x, 0, 1, map_size.y, false) if @border_exit != 1
		@obstacles << Block.new(-1, 0, 1, map_size.y, false) if @border_exit != 3
		
		@loaded = false
		@reload = false
		@entrance = nil
		@warp = nil
		@locked_door = false
	end
	
	def obstacle_at? x, y
		i = x / @map.tile_size.x
		j = y / @map.tile_size.y
		return @tiles[i][j].pass + @tiles[i][j].wall >= 0
	end
	
	def collide_with_player? obj
		@bomb.bounds.intersects obj.bounds
	end
	
	def take_item index, type
		@temp_taken_items << {index: index, type: type}
		@elements.delete_at index
		G.player.add_item type
	end
	
	def save_check_point id
		@temp_taken_items.each do |i|
			@element_info.delete_at i[:index]
			@taken_items << i
		end
		@temp_taken_items.clear
		@entrance = id
	end
	
	def do_warp x, y
		@bomb.do_warp x, y
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
		@warp = nil
	end
	
	def unlock_door
		@locked_door.unlock
		@locked_door = nil
	end
	
	def update
		# testar construção da lista de obstáculos a cada turno
		
		@reload = true if G.window.button_down? Gosu::KbEscape
		G.player.use_item self if G.window.button_down? Gosu::KbA
		
		@loaded = true
		@elements.each do |e|
			e.update self if e.is_visible @map
			@loaded = false if not e.ready?
		end
		
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
	end
	
	def draw
		@map.foreach do |i, j, x, y|
			@tileset[@tiles[i][j].back].draw x, y, 0 if @tiles[i][j].back >= 0
			@tileset[@tiles[i][j].pass].draw x, y, 0 if @tiles[i][j].pass >= 0
			@tileset[@tiles[i][j].wall].draw x, y, 0 if @tiles[i][j].wall >= 0
		end
	
		@elements.each do |e|
			e.draw @map if e.is_visible @map
		end
	
		@map.foreach do |i, j, x, y|
			@tileset[@tiles[i][j].fore].draw x, y, 0 if @tiles[i][j].fore >= 0
		end
	end
end
