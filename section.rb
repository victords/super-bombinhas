require './global'
require './resources'

Tile = Struct.new :back, :fore, :pass, :wall, :hidden

class Section
	def initialize file, entrances, items
		parts = File.read(file).split '#'
		p1 = parts[0].split ','
		set_map_tileset_bg p1
		p2 = parts[1].split ';'
		set_elements p2, entrances, items
		p3 = parts[2].split ';'
		set_ramps p3
	end
	
	def set_map_tileset_bg s
		@tiles = Array.new(s[0].to_i) {
			Array.new(s[1].to_i) {
				Tile.new Vector.new(-1, 0), Vector.new(-1, 0), Vector.new(-1, 0), Vector.new(-1, 0), false
			}
		}
		@border_exit = s[2].to_i # should be C::Up, C::Right, C::Down or C::Left
		@bg1 = Res.img "bg_#{s[3]}".to_sym, false, ".jpg"
		@bg2 = Res.img "bg_#{s[4]}".to_sym if s[4] != "0"
		@tileset = Res.tileset s[5]
	end
	
	def set_elements s, entrances, items
		x = 0; y = 0
		@elements = []
		@hiding_walls = []
		s.each do |e|
			if e[0] == '_'
				x += e[1..-1].to_i
			else
				case e[0]
					when 'b' then set_tile x, y, :back, e[1..-1]
					when 'f' then set_tile x, y, :fore, e[1..-1]
					when 'p' then set_tile x, y, :pass, e[1..-1]
					when 'w' then set_tile x, y, :wall, e[1..-1]
				end
				x += 1
			end
			if x >= @tiles.length
				y += x / @tiles.length
				x %= @tiles.length
			end
		end
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
		@elements.each do |e|
			e.draw
		end
	end
end
