require './global'
require './resources'

Tile = Struct.new :back, :fore, :pass, :wall, :hidden

class Section
	attr_reader :change_section
	
	def initialize file, entrances, items
		parts = File.read(file).split '#'
		p1 = parts[0].split ','
		set_map_tileset_bg p1
		p2 = parts[1].split ';'
		set_elements p2, entrances, items
		p3 = parts[2].split ';'
		set_ramps p3
		@change_section = false
	end
	
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
		@elements = []
		@hiding_walls = []
		s.each do |e|
			if e[0] == '_'
				x += e[1..-1].to_i
				if x >= @tiles.length
					y += x / @tiles.length
					x %= @tiles.length
				end
			elsif e[3] == '*'
				case e[0]
					when 'b' then x, y = set_tiles (e[4..-1].to_i), x, y, :back, e[1..3]
					when 'f' then x, y = set_tiles (e[4..-1].to_i), x, y, :fore, e[1..3]
					when 'p' then x, y = set_tiles (e[4..-1].to_i), x, y, :pass, e[1..3]
					when 'w' then x, y = set_tiles (e[4..-1].to_i), x, y, :wall, e[1..3]
				end
			else
				begin
					case e[0]
						when 'b' then set_tile x, y, :back, e[1..3]
						when 'f' then set_tile x, y, :fore, e[1..3]
						when 'p' then set_tile x, y, :pass, e[1..3]
						when 'w' then set_tile x, y, :wall, e[1..3]
					end
					e = e[3..-1]
				end until e.nil? or e.empty?
				x += 1
				begin y += 1; x = 0 end if x == @tiles.length
			end
		end
	end
	
	def set_tiles amount, x, y, type, s
		amount.times do
			puts "#{s}, #{x}, #{y}"
			v = @tiles[x][y].send type
			v.x = s[0].to_i - 1
			v.y = s[1].to_i - 1
			x += 1
			begin y += 1; x = 0 end if x == @tiles.length
		end
		[x, y]
	end
	
	def set_tile x, y, type, s
		v = @tiles[x][y].send type
		v.x = s[0].to_i - 1
		v.y = s[1].to_i - 1
	end
	
	def set_ramps s
		puts "Rampas: #{s.length}"
	end
	
	def update
		@elements.each do |e|
			e.update
		end
	end
	
	def draw
		@map.foreach do |i, j, x, y|
			draw_tile @tiles[i][j].back, x, y if @tiles[i][j].back.x >= 0
			draw_tile @tiles[i][j].pass, x, y if @tiles[i][j].pass.x >= 0
			draw_tile @tiles[i][j].wall, x, y if @tiles[i][j].wall.x >= 0
		end
		
		@elements.each do |e|
			e.draw
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
