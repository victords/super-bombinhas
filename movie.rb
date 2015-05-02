require_relative 'global'

class MovieElement < GameObject
  attr_reader :finished

  def initialize(x, y, img, sprite_cols, sprite_rows, actions)
    super x.to_i, y.to_i, 0, 0, img, nil, sprite_cols.to_i, sprite_rows.to_i
    @actions = []
    actions.each do |a|
      d = a.split
      pos = d[1][0] == ':' ? nil : d[1].split(',')
      @actions << {
        delay: d[0].to_i,
        x: pos ? pos[0].to_i : nil,
        y: pos ? pos[1].to_i : nil,
        text: pos ? nil : eval(d[1]),
        indices: eval(d[2]),
        last_index: d[3].to_i,
        interval: d[4].to_i,
        duration: d[5].to_i
      }
    end
    @action_index = 0
    @timer = 0
  end

  def update
    return if @finished
    animate @cur_action[:indices], @cur_action[:interval] if @cur_action
    move_free @aim, @speed_m if @aim
    @timer += 16.666667
    if @cur_action && @timer >= @cur_action[:duration]
      set_animation @cur_action[:last_index]
      @cur_action = @aim = nil
      @action_index += 1
      @timer = 0
      @finished = @action_index == @actions.length
    elsif !@cur_action && @timer >= @actions[@action_index][:delay]
      a = @actions[@action_index]
      if a[:x]
        @aim = Vector.new(a[:x], a[:y])
        @speed_m = Math.sqrt((a[:x] - @x)**2 + (a[:y] - @y)**2) * 16.666667 / a[:duration]
      end
      set_animation a[:indices][0]
      @cur_action = a
      @timer = 0
    end
    # puts "#{@x},#{@y}"
  end

  def draw(x_off, y_off)
    @img[@img_index].draw @x - x_off, @y - y_off, 0
    if @cur_action && @cur_action[:text]
      G.window.draw_quad 5, 495, C::PANEL_COLOR,
                         795, 495, C::PANEL_COLOR,
                         5, 595, C::PANEL_COLOR,
                         795, 595, C::PANEL_COLOR, 0
      SB.text_helper.write_breaking SB.text(@cur_action[:text]).gsub("\\n", "\n"), 10, 500, 790, :justified
    end
  end
end

class MovieScene
  def initialize(file_name)
    @bg = Res.img "movie_#{file_name.split('/')[-1]}"
    f = File.open(file_name)
    es = f.read.split "\n\n"
    f.close

    cam = es[0].split("\n")
    cam_pos = cam[0].split(',')
    @cam_x = cam_pos[0].to_i
    @cam_y = cam_pos[1].to_i
    @cam_moves = []
    cam[1..-1].each do |c|
      d = c.split
      pos = d[1].split(',')
      @cam_moves << {
        delay: d[0].to_i,
        x: pos[0].to_i,
        y: pos[1].to_i,
        duration: d[2].to_i
      }
    end
    @cam_index = 0
    @timer = 0

    @elements = []
    es[1..-1].each do |e|
      lines = e.split("\n")
      d = lines[0].split(',')
      @elements << MovieElement.new(d[3], d[4], d[0], d[1], d[2], lines[1..-1])
    end
  end

  def update
    if @finished and @elements_finished
      @timer += 1
      return :finish if @timer == C::MOVIE_DELAY
    else
      unless @finished
        if @speed_x
          @cam_x += @speed_x
          @cam_y += @speed_y
        end
        @timer += 16.666667
        if @cur_action && @timer >= @cur_action[:duration]
          @cur_action = @speed_x = nil
          @cam_index += 1
          @timer = 0
          @finished = @cam_index == @cam_moves.length
        elsif !@cur_action && @timer >= @cam_moves[@cam_index][:delay]
          a = @cam_moves[@cam_index]
          if a[:x]
            @speed_x = (a[:x] - @cam_x) * 16.666667 / a[:duration]
            @speed_y = (a[:y] - @cam_y) * 16.666667 / a[:duration]
          end
          @cur_action = a
          @timer = 0
        end
      end
      @elements_finished = true
      @elements.each_with_index { |e|
        e.update
        @elements_finished = false unless e.finished
      }
    end
  end

  def draw
    @bg.draw -@cam_x, -@cam_y, 0
    @elements.each { |e| e.draw(@cam_x, @cam_y) }
  end
end

class Movie
  def initialize(id)
    @id = id
    files = Dir["#{Res.prefix}movie/#{id}-*"]
    @scenes = []
    files.each do |f|
      @scenes << MovieScene.new(f)
    end
    @scene = 0
    @alpha = 0
    SB.play_song Res.song("m#{id}")
  end

  def update
    if @changing
      @alpha += @changing == 0 ? 17 : -17
      if @alpha == 255
        @changing = 1
        @scene += 1
        if @scene == @scenes.length
          if @id == 's'; SB.open_special_world
          elsif @id == 0; SB.start_new_game
          else; SB.next_world; end
        end
      elsif @alpha == 0
        @changing = nil
      end
    else
      status = @scenes[@scene].update
      @changing = 0 if status == :finish
    end
  end

  def draw
    @scenes[@scene].draw
    if @changing
      c = @alpha << 24
      G.window.draw_quad 0, 0, c,
                         C::SCREEN_WIDTH, 0, c,
                         0, C::SCREEN_HEIGHT, c,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, c, 0
    end
  end
end