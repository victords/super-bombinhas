class TextHelper
	def initialize font, line_spacing
		@font = font
		@line_spacing = line_spacing
	end
	
	def write_breaking text, x, y, width, justified = false
		text.split("\n").each do |p|
			if justified
				y = write_paragraph_justified p, x, y, width
			else
				y = write_paragraph p, x, y, width
			end
		end
	end
	
	def write_paragraph text, x, y, width
		new_x = x
		text.split(' ').each do |word|
			w = @font.text_width word
			if new_x + w > x + width
				new_x = x
				y += @font.height + @line_spacing
			end
			@font.draw word, new_x, y, 0
			new_x += @font.text_width "#{word} "
		end
		y + @font.height + @line_spacing
	end
	
	def write_paragraph_justified text, x, y, width
		space_width = @font.text_width " "
		spaces = [[]]
		line_index = 0
		new_x = x
		words = text.split(' ')
		words.each do |word|
			w = @font.text_width word
			if new_x + w > x + width
				space = x + width - new_x + space_width
				index = 0
				while space > 0
					spaces[line_index][index] += 1
					space -= 1
					index += 1
					index = 0 if index == spaces[line_index].size - 1
				end
				
				spaces << []
				line_index += 1
				
				new_x = x
			end
			new_x += @font.text_width(word) + space_width
			spaces[line_index] << space_width
		end
		
		index = 0
		spaces.each do |line|
			new_x = x
			line.each do |s|
				@font.draw words[index], new_x, y, 0
				new_x += @font.text_width(words[index]) + s
				index += 1
			end
			y += @font.height + @line_spacing
		end
		y
	end
end
