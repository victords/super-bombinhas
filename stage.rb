require './section'

class Stage
	def initialize num
		@name = File.read "data/stage/#{num}.sbs"
		@sections = []
		@entrances = []
		sections = Dir["data/stage/#{num}-*.sbs"]
		sections.sort.each do |s|
			@sections << Section.new(s, @entrances)
		end
		@cur_section = @sections[0]
		@cur_entrance = @entrances[0]
		@cur_section.load @cur_entrance[:x], @cur_entrance[:y]
	end
	
	def update
		@cur_section.update
		check_reload
		check_entrance
		check_warp
	end
	
	def check_reload
		if @cur_section.reload
			@sections.each do |s|
				s.loaded = false
			end
			@cur_section = @cur_entrance[:section]
			@cur_section.load @cur_entrance[:x], @cur_entrance[:y]
		end
	end
	
	def check_entrance
		if @cur_section.entrance
			@cur_entrance = @entrances[@cur_section.entrance]
			@cur_section.entrance = nil
		end
	end
	
	def check_warp
		if @cur_section.warp
			entrance = @entrances[@cur_section.warp]
			@cur_section = entrance[:section]
			if @cur_section.loaded
				@cur_section.do_warp entrance[:x], entrance[:y]
			else
				@cur_section.load entrance[:x], entrance[:y]
			end
		end
	end
	
	def draw
		# cuidar das transições
		@cur_section.draw
	end
end
