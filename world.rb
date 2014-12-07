require 'minigl'
require_relative 'stage'

class MapStage
  attr_reader :name, :x, :y

  def initialize world, num, x, y, img, glows = true
    @x = x
    @y = y
    @img = Res.img "icon_#{img}"
    @state = 0
    @alpha =
      if glows
        0xff
      else
        0x7f
      end
    @color = 0x00ffffff | (@alpha << 24)
    @glows = glows

    @name = G.text("stage_#{world}_#{num}")
    @world = world
    @num = num
  end

  def update
    return unless @glows
    if @state == 0
      @alpha -= 1
      if @alpha == 51
        @state = 1
      end
      @color = 0x00ffffff | (@alpha << 24)
    else
      @alpha += 1
      if @alpha == 0xff
        @state = 0
      end
      @color = 0x00ffffff | (@alpha << 24)
    end
  end

  def select
    G.stage = Stage.new @world, @num
    G.state = :main
  end

  def draw
    @img.draw @x, @y, 0, 1, 1, @color
  end
end

class World
  def initialize
    @num = 1
    @name = G.text "world_#{@num}"

    @water = Sprite.new 0, 0, :other_water, 2, 2
    @parchment = Res.img :other_parchment
    @mark = Res.img :other_mark
    @map = Res.img :other_world1

    @stages = []
    File.open("data/stage/#{@num}/world").each_with_index do |l, i|
      coords = l.split ','
      @stages << MapStage.new(@num, i+1, coords[0].to_i, coords[1].to_i, :unknown, false)
    end
    @cur = 0
    @bomb = Sprite.new @stages[@cur].x + 1, @stages[@cur].y - 15, :sprite_BombaAzul, 5, 2

    @font = TextHelper.new G.font, 5
  end

  def update
    @water.animate [0, 1, 2, 3], 6
    @bomb.animate [0, 1, 0, 2], 8
    @stages.each { |i| i.update }

    if KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbA
      @stages[@cur].select
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
    @bomb.draw

    G.font.draw_rel 'Choose your destiny!', 525, 20, 0, 0.5, 0, 2, 2, 0xff000000
    @font.write_breaking "#{@name}\n*** Stage #{@num}-#{@cur+1} ***\n#{@stages[@cur].name}", 125, 100, 200, :center, 0xff3d361f
  end
end
