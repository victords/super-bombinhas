require 'minigl'
require_relative 'stage'
include MiniGL

class MapStage
  attr_reader :name, :x, :y

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
    @color = 0x00ffffff | (@alpha << 24)

    @name = SB.text("stage_#{world}_#{num}")
    @world = world
    @num = num
  end

  def update
    return unless @glows
    if @state == 0
      @alpha -= 2
      if @alpha == 0x7f
        @state = 1
      end
      @color = 0x00ffffff | (@alpha << 24)
    else
      @alpha += 2
      if @alpha == 0xff
        @state = 0
      end
      @color = 0x00ffffff | (@alpha << 24)
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

  def draw
    @img.draw @x, @y, 0, 1, 1, @color
  end
end

class World
  attr_reader :num, :stage_count

  def initialize(num = 1, stage_num = 1, loaded = false)
    @num = num
    @loaded_stage = loaded ? stage_num : nil
    @name = SB.text "world_#{@num}"

    @water = Sprite.new 0, 0, :ui_water, 2, 2
    @mark = Sprite.new 0, 0, :ui_mark
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
    @cur = num < SB.player.last_world ? @stage_count - 1 : stage_num - 1
    @bomb = Sprite.new @stages[@cur].x + 1, @stages[@cur].y - 15, "sprite_Bomba#{SB.player.bomb.type.to_s.capitalize}", 8, 2

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
    @stages.each { |i| i.update }
    # @play_button.update
    # @back_button.update

    if KB.key_pressed? Gosu::KbEscape or KB.key_pressed? Gosu::KbBackspace
      Menu.reset
      SB.state = :menu
    elsif KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
      @stages[@cur].select(@loaded_stage)
    elsif KB.key_pressed? Gosu::KbLeft or KB.key_pressed? Gosu::KbDown
      @cur -= 1
      @cur = @stages.size - 1 if @cur < 0
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    elsif KB.key_pressed? Gosu::KbRight or KB.key_pressed? Gosu::KbUp
      @cur += 1
      @cur = 0 if @cur >= @stages.size
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    elsif KB.key_pressed? Gosu::KbLeftShift and @num > 1
      SB.world = World.new @num - 1
    elsif KB.key_pressed? Gosu::KbRightShift and @num < SB.player.last_world
      SB.world = World.new @num + 1
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
    @map.draw 0, 0, 0
    @parchment.draw 0, 0, 0
    @mark.draw

    @stages.each { |s| s.draw }
    # @play_button.draw
    # @back_button.draw
    @bomb.draw

    SB.big_text_helper.write_line @name, 525, 10, :center
    SB.text_helper.write_breaking "#{SB.text(:stage)} #{@num}-#{@cur+1}: #{@stages[@cur].name}", 525, 45, 550, :center
    SB.text_helper.write_breaking(SB.text(:ch_st_instruct).gsub('\n', "\n"), 780, 545, 600, :right)

    if @num > 1
      @arrow.draw 260, 10, 0
      SB.small_text_helper.write_breaking 'left shift', 315, 13, 60, :right
    end
    if @num < SB.player.last_world
      @arrow.draw 790, 10, 0, -1
      SB.small_text_helper.write_breaking 'right shift', 735, 13, 60
    end
  end
end
