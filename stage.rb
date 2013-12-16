require './section'

class Stage
	def initialize num
		@name = File.read "data/stage/#{num}.sbs"
		@sections = []
		@entrances = []
		@items = []
		sections = Dir["data/stage/#{num}-*.sbs"]
		sections.sort.each do |s|
			@sections << Section.new(s, @entrances, @items)
		end
		@cur_section = @sections[0]
		@cur_section.load @entrances[0]
	end
	
	def update
		@cur_section.update
		check_change_section
	end
	
	def check_change_section
		if @cur_section.change_section
			@cur_section = @sections[@cur_section.change_section]
		end
	end
	
	def draw
		# aqui ficará parte relacionada a transições também
		@cur_section.draw
	end
end
