require './global'
require './ramp'
require './elements'
require './enemies'
require './map'

Tile = Struct.new :back, :fore, :pass, :wall, :hide, :broken

class Section
	attr_reader :reload, :obstacles, :ramps, :size
	attr_accessor :entrance, :warp, :loaded, :locked_door
	
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
				Tile.new -1, -1, -1, -1, -1, false
			}
		}
		@border_exit = s[2].to_i # 0: top, 1: right, 2: down, 3: left, 4: none
		@bg1 = Res.img "bg_#{s[3]}".to_sym, false, true, ".jpg"
		@bg2 = Res.img "bg_#{s[4]}".to_sym, false, true if s[4] != "0"
		@tileset_num = s[5].to_i
		@tileset = Res.tileset s[5]
		@map = Map.new C::TileSize, C::TileSize, t_x_count, t_y_count
		@map.set_camera 4500, 1200
		@size = @map.get_absolute_size
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
								if e[i] == '$'
									el[:state] = :normal
									el[:section] = self
									G.switches << el
								else
									@element_info << el
								end
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
			when  1 then Wheeliam
			when  2 then FireRock
			when  3 then Bombie
			when  4 then Sprinny
			####  5      Sprinny dois pulos
			####  6      Sprinny três pulos
			when  7 then Life
			when  8 then Key
			when  9 then Door
			#### 10      Door locked
			#### 11      warp (virou entrance)
			when 12 then GunPowder
			when 13 then Crack
			#### 14      gambiarra da rampa, eliminada!
			#### 15      gambiarra da rampa, eliminada!
			#### 16      Wheeliam dont_fall false
			when 17 then Elevator
			when 18 then Fureel
			#### 19      Fureel dont_fall false
			when 20 then SaveBombie
			when 21 then Pin
			#### 22      Pin com obstáculo
			when 23 then Spikes
			when 24 then Attack1
			when 25 then MovingWall
			when 26 then Ball
			when 27 then BallReceptor
			when 28 then Yaw
			when 29 then Ekips
			#### 30      ForeWall
			when 31 then Spec
			when 32 then Faller
			when 33 then Turner
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
		@elements = []
		@obstacles = [] #vetor de obstáculos não-tile
		@locked_door = nil
		@reload = false
		@loaded = true
		
		G.switches.each do |s|
			if s[:section] == self
				@elements << s[:obj]
			end
		end
		
		@element_info.each do |e|
			@elements << e[:type].new(e[:x], e[:y], e[:args], self)
		end
		
		index = 1
		@tiles.each_with_index do |v, i|
			v.each_with_index do |t, j|
				if @tiles[i][j].hide == 0
					@hide_tiles << HideTile.new(i, j, index, @tiles, @tileset_num)
					index += 1
				elsif @tiles[i][j].broken
					@tiles[i][j].broken = false
				end
			end
		end
		
		@elements << (@bomb = G.player.bomb)
		@margin = Vector.new((C::ScreenWidth - @bomb.w) / 2, (C::ScreenHeight - @bomb.h) / 2)
		do_warp bomb_x, bomb_y
	end
	
	def do_warp x, y
		@bomb.do_warp x, y
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
		@warp = nil
	end
	
	def get_obstacles x, y
		obstacles = []
		if x > @size.x - 4 * C::TileSize and @border_exit != 1
			obstacles << Block.new(@size.x, 0, 1, @size.y, false)
		end
		if x < 4 * C::TileSize and @border_exit != 3
			obstacles << Block.new(-1, 0, 1, @size.y, false)
		end
		
		i = (x / C::TileSize).round
		j = (y / C::TileSize).round
		for k in (i-2)..(i+2)
			for l in (j-2)..(j+2)
				if @tiles[k] and @tiles[k][l]
					if @tiles[k][l].pass >= 0
						obstacles << Block.new(k * C::TileSize, l * C::TileSize, C::TileSize, C::TileSize, true)
					elsif not @tiles[k][l].broken and @tiles[k][l].wall >= 0
						obstacles << Block.new(k * C::TileSize, l * C::TileSize, C::TileSize, C::TileSize, false)
					end
				end
			end
		end
		
		@obstacles.each do |o|
#			if o.x > x - 2 * C::TileSize and o.x < x + 2 * C::TileSize and
#			   o.y > y - 2 * C::TileSize and o.y < y + 2 * C::TileSize
				obstacles << o
#			end
		end
		
		obstacles
	end
	
	def obstacle_at? x, y
		i = x / C::TileSize
		j = y / C::TileSize
		@tiles[i] and @tiles[i][j] and not @tiles[i][j].broken and @tiles[i][j].pass + @tiles[i][j].wall >= 0
	end
	
	def projectile_hit? obj
		@elements.each do |e|
			if e.class == Projectile
				if e.bounds.intersects obj.bounds
					@elements.delete e
					return true
				end
			end
		end
		false
	end
	
	def add element
		@elements << element
	end
	
	def save_check_point id, obj
		@entrance = id
		G.set_switch obj
		G.save_switches
	end
	
	def unlock_door
		if @locked_door
			@locked_door.unlock
			G.set_switch @locked_door
			return true
		end
		false
	end
	
	def open_wall id
		@elements.each do |e|
			if e.class == MovingWall and e.id == id
				e.open
				break
			end
		end
	end
	
	def on_tiles
		yield @tiles
	end
	def on_obstacles
		yield @obstacles
	end
	
	def update
		@showing_tiles = false
		@locked_door = nil
		@elements.each do |e|
			e.update self if e.is_visible @map
			@elements.delete e if e.dead?
		end
		@hide_tiles.each do |t|
			t.update self if t.is_visible @map
		end
		
		@map.set_camera @bomb.x - @margin.x, @bomb.y - @margin.y
		
		@reload = true if G.player.dead? or KB.key_pressed? Gosu::KbEscape
	end
	
	def draw
		draw_bg1
		draw_bg2 if @bg2
		
		@map.foreach do |i, j, x, y|
			@tileset[@tiles[i][j].back].draw x, y, 0 if @tiles[i][j].back >= 0
			@tileset[@tiles[i][j].pass].draw x, y, 0 if @tiles[i][j].pass >= 0
			@tileset[@tiles[i][j].wall].draw x, y, 0 if @tiles[i][j].wall >= 0 and not @tiles[i][j].broken
		end
		
		@elements.each do |e|
			e.draw @map if e.is_visible @map
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
		back_x = -@map.cam.x * 0.3; back_y = -@map.cam.y * 0.3
		tiles_x = @size.x / @bg1.width; tiles_y = @size.y / @bg1.height
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
		tiles_x = @size.x / @bg2.width
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
