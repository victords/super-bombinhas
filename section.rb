require './global'
require './ramp'
require './elements'
require './bomb'
require './map'

Tile = Struct.new :back, :fore, :pass, :wall, :hide

class Section
	attr_reader :entrance, :reload, :ramps, :loaded
	attr_accessor :warp, :locked_door
	
	def initialize file, entrances
		parts = File.read(file).chomp.split('#', -1)
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
				Tile.new -1, -1, -1, -1, -1
			}
		}
		@border_exit = s[2].to_i # 0: top, 1: right, 2: down, 3: left, 4: none
		@bg1 = Res.img "bg_#{s[3]}".to_sym, false, true, ".jpg"
		@bg2 = Res.img "bg_#{s[4]}".to_sym, false, true if s[4] != "0"
		@tileset_num = s[5].to_i
		@tileset = Res.tileset s[5]
		@map = Map.new C::TileSize, C::TileSize, t_x_count, t_y_count
		@map.set_camera 4500, 1200
	end
	
	def set_elements s, entrances
		x = 0; y = 0
		@element_info = []
		@hide_tiles = []
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
			when 'b' then :back
			when 'f' then :fore
			when 'p' then :pass
			when 'w' then :wall
			when 'h' then :hide
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
			####  5       Sprinny dois pulos
			####  6       Sprinny três pulos
			when  7 then :Life
			when  8 then :Key
			when  9 then :Door
			#### 10       Door locked
			#### 11       warp (virou entrance)
			when 12 then :GunPowder
			when 13 then :Crack
			#### 14       gambiarra da rampa, eliminada!
			#### 15       gambiarra da rampa, eliminada!
			#### 16       Wheeliam dont_fall false
			when 17 then :Elevator
			when 18 then :Fureel
			#### 19       Fureel dont_fall false
			when 20 then :SaveBombie
			when 21 then :Pin
			#### 22       Pin com obstáculo
			when 23 then :Spikes
			when 24 then :Attack1
			when 25 then :MovingWall
			when 26 then :Ball
			when 27 then :BallReceptor
			when 28 then :Yaw
			when 29 then :Ekips
			#### 30       ForeWall
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
	
	def load bomb_x, bomb_y
		G.player.reset
		@taken_items.each do |i|
			G.player.add_item i[:type]
		end
		@temp_taken_items = []
		
		@elements = []
		@element_info.each do |e|
			if e
				type = Object.const_get e[:type]
				if e[:index]; @elements << type.new(e[:x], e[:y], e[:args], e[:index])
				else; @elements << type.new(e[:x], e[:y], e[:args]); end
			end
		end
		
		index = 1
		@tiles.each_with_index do |v, i|
			v.each_with_index do |t, j|
				if @tiles[i][j].hide == 0
					@hide_tiles << HideTile.new(i, j, index, @tiles, @tileset_num)
					index += 1
				end
			end
		end
		
		@elements << (@bomb = Bomb.new(bomb_x, bomb_y, :azul))
		@margin = Vector.new((C::ScreenWidth - @bomb.w) / 2, (C::ScreenHeight - @bomb.h) / 2)
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
		
		@loaded = false
		@reload = false
		@entrance = nil
		@warp = nil
		@locked_door = false
	end
	
	def get_obstacles x, y
		obstacles = []
		map_size = @map.get_absolute_size
		if x > map_size.x - 4 * C::TileSize and @border_exit != 1
			obstacles << Block.new(map_size.x, 0, 1, map_size.y, false)
		end
		if x < 4 * C::TileSize and @border_exit != 3
			obstacles << Block.new(-1, 0, 1, map_size.y, false)
		end
		
		i = (x / @map.tile_size.x).round
		j = (y / @map.tile_size.y).round
		for k in (i-3)..(i+3)
			for l in (j-3)..(j+3)
				if @tiles[k][l]
					if @tiles[k][l].pass >= 0
						obstacles << Block.new(k * C::TileSize, l * C::TileSize, C::TileSize, C::TileSize, true)
					elsif @tiles[k][l].wall >= 0
						obstacles << Block.new(k * C::TileSize, l * C::TileSize, C::TileSize, C::TileSize, false)
					end
				end
			end
		end
		
		obstacles
	end
	
	def obstacle_at? x, y
		i = x / @map.tile_size.x
		j = y / @map.tile_size.y
		return @tiles[i][j].pass + @tiles[i][j].wall >= 0
	end
	
	def player_over? obj
		@bomb.x + @bomb.w > obj.x and obj.x + obj.w > @bomb.x and
			@bomb.y < obj.y - C::PlayerOverTolerance and @bomb.y + @bomb.h > obj.y and
			@bomb.speed.y > 0
	end
	
	def collide_with_player? obj
		@bomb.bounds.intersects obj.bounds
	end
	
	def bomb_bounds
		@bomb.bounds
	end
	
	def take_item index, type, once, store
		if once
			@temp_taken_items << {index: index, type: type}
		end
		if store; G.player.add_item type
		else; Object.const_get("#{type}Item").new.use self; end
	end
	
	def save_check_point id
		@temp_taken_items.each do |i|
			@element_info[i[:index]] = nil
			@taken_items << i
		end
		@temp_taken_items.clear
		@entrance = id
	end
	
	def do_warp x, y
		@reload = false
		@bomb.do_warp x, y
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
		@warp = nil
	end
	
	def unlock_door
		@locked_door.unlock
		@locked_door = nil
	end
	
	def update
		@reload = true if G.player.dead? or KB.key_pressed? Gosu::KbEscape
		G.player.use_item self if KB.key_pressed? Gosu::KbA
		
		@loaded = true
		@showing_tiles = false
		@elements.each_with_index do |e, i|
			if e
				e.update self if e.is_visible @map
				@loaded = false if not e.ready?
				@elements[i] = nil if e.dead?
			end
		end
		@hide_tiles.each do |t|
			t.update self if t.is_visible @map
		end
		
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
	end
	
	def draw
		draw_bg1
		draw_bg2 if @bg2
		
		@map.foreach do |i, j, x, y|
			@tileset[@tiles[i][j].back].draw x, y, 0 if @tiles[i][j].back >= 0
			@tileset[@tiles[i][j].pass].draw x, y, 0 if @tiles[i][j].pass >= 0
			@tileset[@tiles[i][j].wall].draw x, y, 0 if @tiles[i][j].wall >= 0
		end
		
		@elements.each do |e|
			if e
				e.draw @map if e.is_visible @map
			end
		end
		
		@map.foreach do |i, j, x, y|
			@tileset[@tiles[i][j].fore].draw x, y, 0 if @tiles[i][j].fore >= 0
		end
		
		@hide_tiles.each do |t|
			t.draw @map if t.is_visible @map
		end
		
		G.player.draw_stats
	end
	
	def draw_bg1
		map_size = @map.get_absolute_size
		back_x = -@map.cam.x * 0.3; back_y = -@map.cam.y * 0.3
		tiles_x = map_size.x / @bg1.width; tiles_y = map_size.y / @bg1.height
		for i in 1..tiles_x-1
			if back_x + i * @bg1.width > 0
				back_x += (i - 1) * @bg1.width
				break
			end
		end
		for i in 1..tiles_y-1
			if back_y + i * @bg1.height > 0
				back_y += (i - 1) * @bg1.height
				break
			end
		end
		first_back_y = back_y
		while back_x < C::ScreenWidth
			while back_y < C::ScreenHeight
				@bg1.draw back_x, back_y, 0
				back_y += @bg1.height
			end
			back_x += @bg1.width
			back_y = first_back_y
		end
	end
	
	def draw_bg2
		back_x = -@map.cam.x * 0.5
		tiles_x = @map.get_absolute_size.x / @bg2.width
		for i in 1..tiles_x-1
			if back_x + i * @bg2.width > 0
				back_x += (i - 1) * @bg2.width
				break
			end
		end
		while back_x < C::ScreenWidth
			@bg2.draw back_x, 0, 0
			back_x += @bg2.width
		end
	end
end
