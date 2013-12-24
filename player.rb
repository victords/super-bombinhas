require './items'

class Player
	def initialize score = 0, stage = 0, bomb = :azul
		@score = score
		@stage = stage
		@bomb = bomb
		@items = {}
	end
	
	def add_item type
		if @items[type]
			@items[type] += 1
		else
			@items[type] = 1
		end
		@cur_item_type = type if @cur_item_type.nil?
	end
	
	def use_item section
		puts "antes: #{@items}"
		return if @items[@cur_item_type].nil?
		item = Object.const_get("#{@cur_item_type}Item").new
		if item.use section
			@items[@cur_item_type] -= 1
			@items.delete @cur_item_type if @items[@cur_item_type] == 0
		end
		puts "depois: #{@items}"
	end
	
	def clear
		@items.clear
		@cur_item_type = nil
	end
end
