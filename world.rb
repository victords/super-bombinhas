require 'minigl'
require_relative 'stage'
include MiniGL

class MapStage
  attr_reader :x, :y

  def initialize(world, num, x, y, img)
    @x = x
    @y = y
    @img = Res.img "icon_#{img}"
    @glows = img != :unknown
    @state = 0
    @alpha =
      if @glows
        0xff
      else
        0x7f
      end

    @world = world
    @num = num
  end

  def name
    SB.text("stage_#{@world}_#{@num}")
  end

  def update
    return unless @glows
    if @state == 0
      @alpha -= 2
      if @alpha == 0x7f
        @state = 1
      end
    else
      @alpha += 2
      if @alpha == 0xff
        @state = 0
      end
    end
  end

  def select(loaded_stage)
    SB.stage = Stage.new(@world, @num, @num == loaded_stage)
    SB.stage.start
    SB.state = :main
  end

  def open
    @img = Res.img :icon_current
    @glows = true
    @alpha = 0xff
  end

  def close
    @img = Res.img :icon_complete
  end

  def draw(alpha)
    a = ((alpha / 255.0) * (@alpha / 255.0) * 255).round
    @img.draw @x, @y, 0, 1, 1, (a << 24) | 0xffffff
  end
end

class World
  attr_reader :num, :stage_count

  def initialize(num = 1, stage_num = 1, loaded = false)
    @num = num
    @loaded_stage = loaded ? stage_num : nil

    @water = Sprite.new 0, 0, :ui_water, 2, 2
    @mark = GameObject.new 0, 0, 1, 1, :ui_mark
    @arrow = Res.img :ui_changeWorld
    @parchment = Res.img :ui_parchment
    @map = Res.img "bg_world#{num}"

    @stages = []
    File.open("#{Res.prefix}stage/#{@num}/world").each_with_index do |l, i|
      coords = l.split ','
      begin @mark.x = coords[0].to_i; @mark.y = coords[1].to_i; next end if i == 0
      state =
        if num < SB.player.last_world
          :complete
        elsif i < SB.player.last_stage
          :complete
        elsif i == SB.player.last_stage
          :current
        else
          :unknown
        end
      @stages << MapStage.new(@num, i, coords[0].to_i, coords[1].to_i, state)
    end
    @stage_count = @stages.count
    @enabled_stage_count = num < SB.player.last_world ? @stage_count : SB.player.last_stage
    @cur = num < SB.player.last_world ? @stage_count - 1 : stage_num - 1
    @bomb = Sprite.new @stages[@cur].x + 1, @stages[@cur].y - 15, "sprite_Bomba#{SB.player.bomb.type.to_s.capitalize}", 8, 2
    @trans_alpha = 0

    # @play_button = Button.new(420, 550, SB.font, SB.text(:play), :ui_button1, 0, 0, 0, 0, true, false, 0, 7) {
    #   @stages[@cur].select(@loaded_stage)
    # }
    # @back_button = Button.new(610, 550, SB.font, SB.text(:back), :ui_button1, 0, 0, 0, 0, true, false, 0, 7) {
    #   SB.menu.reset
    #   SB.state = :menu
    # }
  end

  def update
    @water.animate [0, 1, 2, 3], 6
    @bomb.animate [0, 1, 0, 2], 8

    if @next_world
      @trans_alpha -= 17
      @mark.move_free(@mark_aim, @mark_speed)
      if @trans_alpha == 0
        SB.world = World.new(@next_world)
      end
      return
    elsif @trans_alpha < 0xff
      @trans_alpha += 17
    end

    @stages.each { |i| i.update }
    # @play_button.update
    # @back_button.update

    if KB.key_pressed? Gosu::KbEscape or KB.key_pressed? Gosu::KbBackspace
      Menu.reset
      SB.state = :menu
    elsif KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
      @stages[@cur].select(@loaded_stage)
    elsif @cur > 0 and (KB.key_pressed? Gosu::KbLeft or KB.key_pressed? Gosu::KbDown)
      @cur -= 1
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    elsif @cur < @enabled_stage_count - 1 and (KB.key_pressed? Gosu::KbRight or KB.key_pressed? Gosu::KbUp)
      @cur += 1
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    elsif KB.key_pressed? Gosu::KbLeftShift and @num > 1
      change_world(@num - 1)
    elsif KB.key_pressed? Gosu::KbRightShift and @num < SB.player.last_world
      change_world(@num + 1)
    end
  end

  def set_loaded(stage_num)
    @loaded_stage = stage_num
    @bomb = Sprite.new @stages[@cur].x + 1, @stages[@cur].y - 15, "sprite_Bomba#{SB.save_data[3].capitalize}", 5, 2
  end

  def open_stage
    @stages[@cur].close
    if @cur < @stage_count - 1
      @cur += 1
      @stages[@cur].open
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    end
  end

  def change_world(num)
    @next_world = num
    f = File.open("#{Res.prefix}stage/#{@next_world}/world")
    coords = f.readline.split ','
    @mark_aim = Vector.new(coords[0].to_i, coords[1].to_i)
    @mark_speed = @mark_aim.distance(@mark.position) / 15
    f.close
  end

  def draw
    G.window.clear 0x6ab8ff
    y = 0
    while y < C::SCREEN_HEIGHT
      x = 0
      while x < C::SCREEN_WIDTH
        @water.x = x; @water.y = y
        @water.draw
        x += 40
      end
      y += 40
    end
    @map.draw 0, 0, 0, 1, 1, (@trans_alpha << 24) | 0xffffff
    @parchment.draw 0, 0, 0
    @mark.draw

    @stages.each { |s| s.draw @trans_alpha }
    # @play_button.draw
    # @back_button.draw
    @bomb.draw nil, 1, 1, @trans_alpha

    SB.big_text_helper.write_line SB.text("world_#{@num}"), 525, 10, :center, 0, @trans_alpha
    SB.text_helper.write_breaking "#{@num}-#{@cur+1}: #{@stages[@cur].name}", 525, 55, 550, :center, 0, @trans_alpha
    SB.text_helper.write_breaking(SB.text(:ch_st_instruct).gsub('\n', "\n"), 780, 545, 600, :right, 0, @trans_alpha)

    if @num > 1
      @arrow.draw 260, 10, 0, 1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:left_shift), 315, 13, 60, :right, 0, @trans_alpha
    end
    if @num < SB.player.last_world
      @arrow.draw 790, 10, 0, -1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:right_shift), 735, 13, 60, :left, 0, @trans_alpha
    end
    if @cur > 0
      @arrow.draw 260, 47, 0, 1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:left_arrow), 315, 50, 60, :right, 0, @trans_alpha
    end
    if @cur < @enabled_stage_count - 1
      @arrow.draw 790, 47, 0, -1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:right_arrow), 735, 50, 60, :left, 0, @trans_alpha
    end
  end
end
