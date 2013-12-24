class KeyItem
	def use section
		if section.locked_door
			section.unlock_door
			return true
		end
		false
	end
end
