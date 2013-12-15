require './global'
require './elements'
require './map'

Tile = Struct.new :back, :fore, :pass, :wall, :hidden

class Section
	attr_reader :change_section, :obstacles
	
	def initialize file, entrances, items
		parts = File.read(file).split '#'
		p1 = parts[0].split ','
		set_map_tileset_bg p1
		p2 = parts[1].split ';'
		set_elements p2, entrances, items
		p3 = parts[2].split ';'
		set_ramps p3
		@change_section = false
		@elements = []
	end
	
	# initialization
	def set_map_tileset_bg s
		t_x_count = s[0].to_i; t_y_count = s[1].to_i
		@tiles = Array.new(t_x_count) {
			Array.new(t_y_count) {
				Tile.new Vector.new(-1, 0), Vector.new(-1, 0), Vector.new(-1, 0), Vector.new(-1, 0), false
			}
		}
		@border_exit = s[2].to_i # should be C::Up, C::Right, C::Down or C::Left
		@bg1 = Res.img "bg_#{s[3]}".to_sym, false, ".jpg"
		@bg2 = Res.img "bg_#{s[4]}".to_sym if s[4] != "0"
		@tileset = Res.tileset s[5]
		@map = Map.new C::TileSize, C::TileSize, t_x_count, t_y_count
		@map.set_camera 350, 900
	end
	
	def set_elements s, entrances, items
		x = 0; y = 0
		@element_info = []
		@hiding_walls = []
		@obstacles = []
		s.each do |e|
			if e[0] == '_'; x, y = set_spaces e[1..-1].to_i, x, y
			elsif e[0] == '!'
				puts "entrance"
				x += 1
				begin y += 1; x = 0 end if x == @tiles.length
			elsif e[0] == '?'; puts "exit"
			elsif e[3] == '*'; x, y = set_tiles e[4..-1].to_i, x, y, tile_type(e[0]), e[1, 2]
			else
				i = 0
				begin
					t = tile_type e[i]
					if t == :none
						t, a = element_type e[(i+1)..-1]
						@element_info << { x: x, y: y, type: t, args: a } if t != :none
						i += 1000
					else; set_tile x, y, t, e[i+1, 2]; end
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
			else :none
		end
	end
	
	def element_type s
		i = s.index ':'
		if i; n = s[0..i].to_i
		else; n = s.to_i; end
		case n
			when  1 then type = :Wheeliam
			when  2 then type = :FireRock
			when  3 then type = :Bombie
			when  4 then type = :Sprinny
			when  7 then type = :Life
			when  8 then type = :Key
			when  9 then type = :Door
			when 12 then type = :GunPowder
			when 13 then type = :Crack
			when 17 then type = :Elevator
			when 18 then type = :Fureel
			when 20 then type = :SaveBombie
			when 21 then type = :Pin
			when 23 then type = :Spikes
			when 24 then type = :Attack1
			when 25 then type = :MovingWall
			when 26 then type = :Ball
			when 27 then type = :BallReceptor
			when 28 then type = :Yaw
			when 29 then type = :Ekips
			when 31 then type = :Spec
			when 32 then type = :Faller
			when 33 then type = :Turner
			else type = :none
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
		v = @tiles[x][y].send type
		v.x = s[0].to_i - 1
		v.y = s[1].to_i - 1
		if type == :pass
			@obstacles << Block.new(x * C::TileSize, y * C::TileSize, C::TileSize, C::TileSize, true)
		elsif type == :wall
			@obstacles << Block.new(x * C::TileSize, y * C::TileSize, C::TileSize, C::TileSize, false)
		end
	end
	
	def set_ramps s
		puts "Rampas: #{s.length}"
	end
	#end initialization
	
	def load
		@element_info.each do |e|
			@elements << Object.const_get(e[:type]).new(e[:x], e[:y], e[:args])
		end
	end
	
	def obstacle_at? x, y
		pos = Vector.new(x / @map.tile_size.x, y / @map.tile_size.y)
		return @tiles[pos.x][pos.y].pass.x + @tiles[pos.x][pos.y].wall.x >= 0
	end
	
	def update
		@elements.each do |e|
			e.update self if e.is_visible @map
		end
	end
	
	def draw
		@map.foreach do |i, j, x, y|
			draw_tile @tiles[i][j].back, x, y if @tiles[i][j].back.x >= 0
			draw_tile @tiles[i][j].pass, x, y if @tiles[i][j].pass.x >= 0
			draw_tile @tiles[i][j].wall, x, y if @tiles[i][j].wall.x >= 0
		end
		
		@elements.each do |e|
			e.draw @map if e.is_visible @map
		end
		
		@map.foreach do |i, j, x, y|
			draw_tile @tiles[i][j].fore, x, y if @tiles[i][j].fore.x >= 0
		end
	end
	
	def draw_tile v, x, y
		index = v.y * C::TilesetSize + v.x
		@tileset[index].draw x, y, 0
	end
end
