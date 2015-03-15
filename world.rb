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
    SB.state = :main
  end

  def draw
    @img.draw @x, @y, 0, 1, 1, @color
  end
end

class World
  attr_reader :num

  def initialize(num = 1, stage_num = 1, loaded = false)
    @num = num
    @loaded_stage = loaded ? stage_num : nil
    @name = SB.text "world_#{@num}"

    @water = Sprite.new 0, 0, :ui_water, 2, 2
    @parchment = Res.img :ui_parchment
    @mark = Res.img :ui_mark
    @map = Res.img :ui_world1

    @stages = []
    @cur = stage_num - 1
    File.open("#{Res.prefix}stage/#{@num}/world").each_with_index do |l, i|
      coords = l.split ','
      state = if i < @cur; :complete; else; i == @cur ? :current : :unknown; end
      @stages << MapStage.new(@num, i+1, coords[0].to_i, coords[1].to_i, state)
    end
    @bomb = Sprite.new @stages[@cur].x + 1, @stages[@cur].y - 15, "sprite_Bomba#{loaded ? SB.save_data[2].capitalize : 'Azul'}", 5, 2

    @font = TextHelper.new SB.font, 5

    @play_button = Button.new(420, 550, SB.font, SB.text(:play), :ui_button1, 0, 0, 0, 0, true, false, 0, 7) {
      @stages[@cur].select(@loaded_stage)
    }
    @back_button = Button.new(610, 550, SB.font, SB.text(:back), :ui_button1, 0, 0, 0, 0, true, false, 0, 7) {
      SB.menu.reset
      SB.state = :menu
    }
  end

  def update
    @water.animate [0, 1, 2, 3], 6
    @bomb.animate [0, 1, 0, 2], 8
    @stages.each { |i| i.update }
    @play_button.update
    @back_button.update

    if KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbA
      @stages[@cur].select(@loaded_stage)
    elsif KB.key_pressed? Gosu::KbLeft or KB.key_pressed? Gosu::KbDown
      @cur -= 1
      @cur = @stages.size - 1 if @cur < 0
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    elsif KB.key_pressed? Gosu::KbRight or KB.key_pressed? Gosu::KbUp
      @cur += 1
      @cur = 0 if @cur >= @stages.size
      @bomb.x = @stages[@cur].x + 1; @bomb.y = @stages[@cur].y - 15
    end
  end

  def set_loaded(stage_num)
    @loaded_stage = stage_num
    @bomb = Sprite.new @stages[@cur].x + 1, @stages[@cur].y - 15, "sprite_Bomba#{SB.save_data[2].capitalize}", 5, 2
  end

  def draw
    G.window.draw_quad 0, 0, 0xff6ab8ff,
                       800, 0, 0xff6ab8ff,
                       800, 600, 0xff6ab8ff,
                       0, 600, 0xff6ab8ff, 0
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
    @parchment.draw 0, 0, 0
    @mark.draw 190, 510, 0

    @map.draw 250, 100, 0
    @stages.each { |s| s.draw }
    @play_button.draw
    @back_button.draw
    @bomb.draw

    SB.font.draw_rel SB.text(:choose_stage), 525, 20, 0, 0.5, 0, 2, 2, 0xff000000
    @font.write_breaking "#{@name}\n*** #{SB.text(:stage)} #{@num}-#{@cur+1} ***\n#{@stages[@cur].name}", 125, 100, 200, :center, 0xff3d361f
  end
end
