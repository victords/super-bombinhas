class Item
	attr_reader :icon
	attr_accessor :amount
	
	def initialize type = nil
		@amount = 1
		if not type.nil?
			@icon = Res.img "icon_#{type}"
		end
	end
end

class KeyItem < Item
	def use section
		section.on_locked_door do |d|
			if d
				d.unlock
				return true
			end
		end
		false
	end
end

class LifeItem
	def use section
		G.player.lives += 1
		true
	end
end

class Attack1Item < Item
	def use section
		
	end
end
