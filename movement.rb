require './global'

module Movement
	attr_reader :speed, :w, :h, :passable, :top, :bottom, :left, :right
	attr_accessor :x, :y
	
	def move(forces, obst, ramps)
		@top = @bottom = @left = @right = nil
		forces.x += G.gravity.x; forces.y += G.gravity.y
		forces.x += @stored_forces.x; forces.y += @stored_forces.y
		@stored_forces.x = @stored_forces.y = 0
		
		obst.each do |o|
			x2 = @x + @w; y2 = @y + @h; x2o = o.x + o.w; y2o = o.y + o.h
			begin forces.x = 0; @right = o end if !o.passable && x2.round(6) == o.x.round(6) && y2 > o.y && @y < y2o && forces.x > 0
			begin forces.x = 0; @left = o end if !o.passable && @x.round(6) == x2o.round(6) && y2 > o.y && @y < y2o && forces.x < 0
			begin forces.y = 0; @bottom = o end if y2.round(6) == o.y.round(6) && x2 > o.x && @x < x2o && forces.y > 0
			begin forces.y = 0; @top = o end if !o.passable && @y.round(6) == y2o.round(6) && x2 > o.x && @x < x2o && forces.y < 0
		end
		
		if forces.y > 0
			ramps.each do |r|
				begin forces.y = 0; @bottom = r; break end if r.is_below(self)
			end
		end
		
		@speed.x += forces.x; @speed.y += forces.y
		
		x = @speed.x < 0 ? @x + @speed.x : @x
		y = @speed.y < 0 ? @y + @speed.y : @y
		w = @w + (@speed.x < 0 ? -@speed.x : @speed.x)
		h = @h + (@speed.y < 0 ? -@speed.y : @speed.y)
		move_bounds = Rectangle.new(x, y, w, h)
		coll_list = []
		obst.each do |o|
			coll_list.push(o) if move_bounds.intersects(Rectangle.new(o.x, o.y, o.w, o.h))
		end
		
		if coll_list.length > 0
			up = @speed.y < 0; rt = @speed.x > 0; dn = @speed.y > 0; lf = @speed.x < 0
			if @speed.x == 0 || @speed.y == 0
				# Ortogonal
				if rt; x_lim = find_right_limit(coll_list)
				elsif lf; x_lim = find_left_limit(coll_list)
				elsif dn; y_lim = find_down_limit(coll_list)
				elsif up; y_lim = find_up_limit(coll_list)
				end
				if rt && @x + @w + @speed.x > x_lim; @x = x_lim - @w; @speed.x = 0
				elsif lf && @x + @speed.x < x_lim; @x = x_lim; @speed.x = 0
				elsif dn && @y + @h + @speed.y > y_lim; @y = y_lim - @h; @speed.y = 0
				elsif up && @y + @speed.y < y_lim; @y = y_lim; @speed.y = 0
				end
			else
				# Diagonal
				x_aim = @x + @speed.x + (rt ? @w : 0); x_lim_def = x_aim
				y_aim = @y + @speed.y + (dn ? @h : 0); y_lim_def = y_aim
				coll_list.each do |c|
					if c.passable; x_lim = x_aim
					elsif rt; x_lim = c.x
					else; x_lim = c.x + c.w
					end
					if dn; y_lim = c.y
					elsif c.passable; y_lim = y_aim
					else; y_lim = c.y + c.h
					end
					
					if c.passable
						y_lim_def = y_lim if dn && @y + @h <= y_lim && y_lim < y_lim_def
					elsif rt && @x + @w > x_lim || lf && @x < x_lim
						# Can't limit by x, will limit by y
						y_lim_def = y_lim if dn && y_lim < y_lim_def || up && y_lim > y_lim_def
					elsif (dn && @y + @h > y_lim || up && @y < y_lim)
						# Can't limit by y, will limit by x 
						x_lim_def = x_lim if rt && x_lim < x_lim_def || lf && x_lim > x_lim_def
					else
						xTime = 1.0 * (x_lim - @x - (@speed.x < 0 ? 0 : @w)) / @speed.x
						yTime = 1.0 * (y_lim - @y - (@speed.y < 0 ? 0 : @h)) / @speed.y
						if xTime > yTime
							# Will limit by x
							x_lim_def = x_lim if rt && x_lim < x_lim_def || lf && x_lim > x_lim_def
						elsif dn && y_lim < y_lim_def || up && y_lim > y_lim_def
							y_lim_def = y_lim
						end
					end
				end
				if x_lim_def != x_aim
					@speed.x = 0
					if lf; @x = x_lim_def
					else; @x = x_lim_def - @w
					end
				end
				if y_lim_def != y_aim
					@speed.y = 0
					if up; @y = y_lim_def
					else; @y = y_lim_def - @h
					end
				end
			end
		end
		@x += @speed.x
		@y += @speed.y
		
		ramps.each do |r|
			if r.intersects(self)
				@y = r.get_y(self)
				@speed.y = 0
			end
		end
	end	
	def find_right_limit(coll_list)
		limit = @x + @w + @speed.x
		coll_list.each do |c|
			limit = c.x if !c.passable && c.x < limit
		end
		limit
	end
	def find_left_limit(coll_list)
		limit = @x + @speed.x
		coll_list.each do |c|
			limit = c.x + c.w if !c.passable && c.x + c.w > limit
		end
		limit
	end
	def find_down_limit(coll_list)
		limit = coll_list[0].y
		coll_list.each do |c|
			limit = c.y if c.y < limit
		end
		limit
	end
	def find_up_limit(coll_list)
		limit = @y + @speed.y
		coll_list.each do |c|
			limit = c.y + c.h if !c.passable && c.y + c.h > limit
		end
		limit
	end
end
