require './items'

class Player
	attr_accessor :score, :lives
	
	def initialize score = 0, stage = 0, bomb = :azul, lives = 5, items = {}
		@score = score
		@stage = stage
		@bomb = bomb		
		@lives = lives
		@items = items
		@item_index = 0
	end
	
	def dead?
		@dead
	end
	
	def die
		@dead = true
	end
	
	def add_item type
		if @items[type]
			@items[type].amount += 1
		else
			@items[type] = Object.const_get("#{type}Item").new type
		end
		@cur_item_type = type if @cur_item_type.nil?
	end
	
	def use_item section
		item = @items[@cur_item_type]
		return if item.nil?
		if item.use section
			item.amount -= 1
			if item.amount == 0
				@items.delete @cur_item_type
				@item_index = 0 if @item_index >= @items.length
				@cur_item_type = @items.keys[@item_index]
			end
		end
	end
	
	def change_item
		@item_index += 1
		@item_index = 0 if @item_index >= @items.length
		@cur_item_type = @items.keys[@item_index]
	end
	
	def draw_stats
		G.window.draw_quad 5, 5, 0x80abcdef,
		                   205, 5, 0x80abcdef,
		                   205, 55, 0x80abcdef,
		                   5, 55, 0x80abcdef, 0
		G.font.draw "Lives", 10, 10, 0, 1, 1, 0xff000000
		G.font.draw @lives, 100, 10, 0, 1, 1, 0xff000000
		G.font.draw "Score", 10, 30, 0, 1, 1, 0xff000000
		G.font.draw @score, 100, 30, 0, 1, 1, 0xff000000
		
		G.window.draw_quad 690, 5, 0x80abcdef,
		                   740, 5, 0x80abcdef,
		                   740, 55, 0x80abcdef,
		                   690, 55, 0x80abcdef, 0
		G.window.draw_quad 745, 5, 0x80abcdef,
		                   795, 5, 0x80abcdef,
		                   795, 55, 0x80abcdef,
		                   745, 55, 0x80abcdef, 0
		
		item = @items[@cur_item_type]
		if not item.nil?
			item.icon.draw 695, 10, 0
			G.font.draw item.amount.to_s, 725, 36, 0, 1, 1, 0xff000000
		end
		if @items.length > 1
			G.window.draw_triangle 690, 30, 0x80123456,
			                       694, 26, 0x80123456,
			                       694, 34, 0x80123456, 0
			G.window.draw_triangle 736, 25, 0x80123456,
			                       741, 30, 0x80123456,
			                       736, 35, 0x80123456, 0
		end
	end
	
	def reset
		@items.clear
		@cur_item_type = nil
		@item_index = 0
		@dead = false
	end
end
