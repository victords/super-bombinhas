# Copyright 2019 Victor David Santos
#
# This file is part of Super Bombinhas.
#
# Super Bombinhas is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Super Bombinhas is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Super Bombinhas.  If not, see <https://www.gnu.org/licenses/>.

require 'minigl'
include MiniGL

############################### classes abstratas ##############################

class SBGameObject < GameObject
  def initialize(x, y, w, h, img, img_gap = Vector.new(0, 0), sprite_cols = nil, sprite_rows = nil)
    super(x, y, w, h, img, img_gap, sprite_cols, sprite_rows)
    @active_bounds = Rectangle.new(@x + @img_gap.x, @y + @img_gap.y, @img[0].width * 2, @img[0].height * 2)
  end

  def update_active_bounds(section)
    t = (@y + @img_gap.y).floor
    r = (@x + @img_gap.x + @img[0].width * 2).ceil
    b = (@y + @img_gap.y + @img[0].height * 2).ceil
    l = (@x + @img_gap.x).floor

    if t > section.size.y
      @dead = true
    elsif r < 0; @dead = true
    elsif b < C::TOP_MARGIN; @dead = true #para sumir por cima, a margem deve ser maior
    elsif l > section.size.x; @dead = true
    else
      if t < @active_bounds.y
        @active_bounds.h += @active_bounds.y - t
        @active_bounds.y = t
      end
      @active_bounds.w = r - @active_bounds.x if r > @active_bounds.x + @active_bounds.w
      @active_bounds.h = b - @active_bounds.y if b > @active_bounds.y + @active_bounds.h
      if l < @active_bounds.x
        @active_bounds.w += @active_bounds.x - l
        @active_bounds.x = l
      end
    end
  end

  def draw(map, section = nil, scale_x = 2, scale_y = 2, alpha = 0xff, color = 0xffffff, angle = nil, flip = nil, z_index = 0, round = false)
    super(map, scale_x, scale_y, alpha, color, angle, flip, z_index, round)
  end
end

class TwoStateObject < SBGameObject
  def initialize(x, y, w, h, img, img_gap, sprite_cols, sprite_rows, change_interval, anim_interval, change_anim_interval,
                 s1_indices, s2_indices, s1_s2_indices, s2_s1_indices, s2_first = false, change_interval_2 = nil, delay = 0)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows

    @timer = -delay
    @changing = false
    @change_interval = change_interval
    @change_interval_2 = change_interval_2 || change_interval
    @anim_interval = anim_interval
    @change_anim_interval = change_anim_interval
    @s1_indices = s1_indices
    @s2_indices = s2_indices
    @s1_s2_indices = s1_s2_indices
    @s2_s1_indices = s2_s1_indices
    @state2 = s2_first
    set_animation s2_indices[0] if s2_first
  end

  def update(section)
    @timer += 1
    if @state2 && @timer == @change_interval_2 || !@state2 && @timer == @change_interval
      @state2 = (not @state2)
      if @state2
        s1_to_s2 section
        set_animation @s1_s2_indices[0]
      else
        s2_to_s1 section
        set_animation @s2_s1_indices[0]
      end
      @changing = true
      @timer = 0
    end

    if @changing
      if @state2
        animate @s1_s2_indices, @change_anim_interval
        if @img_index == @s1_s2_indices[-1]
          @changing = false
        end
      else
        animate @s2_s1_indices, @change_anim_interval
        if @img_index == @s2_s1_indices[-1]
          @changing = false
        end
      end
    elsif @state2
      animate @s2_indices, @anim_interval if @anim_interval > 0
    else
      animate @s1_indices, @anim_interval if @anim_interval > 0
    end
  end
end

class SBEffect < Effect
  def draw(map, scale_x = nil, scale_y = nil)
    super(map, 2, 2)
  end
end

module Speech
  def init_speech(msg_id)
    @speaking = false
    @msg = SB.text(msg_id.to_sym).split('/')
    @page = 0
  end

  def update_speech(section)
    if SB.player.bomb.collide? self
      if not @facing_right and SB.player.bomb.bounds.x > @x + @w / 2
        @facing_right = true
      elsif @facing_right and SB.player.bomb.bounds.x < @x + @w / 2
        @facing_right = false
      end
      if SB.key_pressed? :up
        @speaking = !@speaking
        if @speaking
          @active = false
        else
          @page = 0
          set_animation(@indices[0])
        end
      elsif @speaking and SB.key_pressed? :down
        if @page < @msg.size - 1
          @page += 1
        else
          @page = 0
          @speaking = false
          set_animation(@indices[0])
        end
      end
      @active = !@speaking
    else
      @page = 0
      @active = false
      @speaking = false
      set_animation(@indices[0])
    end

    def change_speech(msg_id)
      @msg = SB.text(msg_id.to_sym).split('/')
      @page = 0
    end

    animate @indices, @interval if @speaking
    if @active
      section.active_object = self
    else
      section.active_object = nil
    end
  end

  def draw_speech
    return if !@speaking || SB.state == :paused
    G.window.draw_quad 5, 495, C::PANEL_COLOR,
                       795, 495, C::PANEL_COLOR,
                       5, 595, C::PANEL_COLOR,
                       795, 595, C::PANEL_COLOR, 1
    SB.text_helper.write_breaking @msg[@page], 10, 495, 780, :justified, 0, 255, 1
    if @msg.size > 1 && @page < @msg.size - 1
      G.window.draw_triangle 780, 585, C::ARROW_COLOR,
                             790, 585, C::ARROW_COLOR,
                             785, 590, C::ARROW_COLOR, 1
    end
  end
end

################################################################################

class SpecialBlock < Block
  attr_reader :info

  def initialize(x, y, w, h, passable = false, info = nil)
    super(x, y, w, h, passable)
    @info = info
  end
end

class Goal < SBGameObject
  def initialize(x, y, args, section)
    super x - 4, y - 118, 40, 150, :sprite_goal1, nil, 4, 1
  end

  def stop_time_immune?
    true
  end

  def update(section)
    animate [0, 1, 2, 3], 7
    section.finish if SB.player.bomb.collide? self
  end
end

class Bombie < GameObject
  include Speech

  def initialize(x, y, args, section)
    super x - 16, y, 64, 32, :sprite_Bombie, Vector.new(17, -2), 3, 1
    @balloon = Res.img :fx_Balloon1
    @facing_right = false
    @indices = [0, 1, 2]
    @interval = 8
    @active_bounds = Rectangle.new x - 16, y, 64, 32

    init_speech("msg#{args}")
  end

  def update(section)
    update_speech(section)
  end

  def draw(map, section)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    @balloon.draw @x - map.cam.x + 16, @y - map.cam.y - 32, 0, 2, 2 if @active
    draw_speech
  end
end

class Door < GameObject
  attr_reader :locked, :type

  def initialize(x, y, args, section, switch)
    args = (args || '').split(',')
    type = args[2] ? args[2].to_i : 0
    cols = 5
    rows = 1
    case type
    when 0, 3, 6 then x_g = -1;  y_g = -63
    when 5       then x_g = -17; y_g = -95; cols = rows = nil
    when 10..13  then x_g = -5;  y_g = -67
    when 14      then x_g = -11; y_g = -79
    else              x_g = -10; y_g = -89 # all boss doors
    end
    super x + 1, y + 63, 30, 1, "sprite_Door#{type}", Vector.new(x_g, y_g), cols, rows
    @entrance = args[0].to_i
    @locked = (switch[:state] != :taken and args[1] == '.')
    @type = type
    @open = false
    @active_bounds = Rectangle.new x, y, 32, 64
    @lock = Res.img(:sprite_Lock) if @locked
  end

  def update(section)
    collide = SB.player.bomb.collide? self
    if @locked and collide
      section.active_object = self
    elsif section.active_object == self
      section.active_object = nil
    end
    if collide && !@opening && SB.key_pressed?(:up)
      if @locked
        if SB.player.has_item?("Key#{@type}")
          SB.player.use_item(section, "Key#{@type}")
        end
      else
        set_animation 1
        section.start_warp(@entrance)
        @opening = true
      end
    end
    if @opening
      indices = @img.size > 1 ? [1, 2, 3, 4, 4, 4] : [0, 0, 0, 0, 0, 0]
      animate_once(indices, 5) do
        @opening = false
        set_animation(0)
      end
    end
  end

  def unlock(section)
    @locked = false
    @lock = nil
    section.active_object = nil
    SB.stage.set_switch self
    SB.play_sound(Res.sound(:unlock))
    set_animation(1)
    section.start_warp(@entrance)
    @opening = true
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    super(map, 2, 2)
    @lock.draw(@x + 18 - map.cam.x, @y - 38 - map.cam.y, 0, 2, 2) if @lock
  end
end

class GunPowder < SBGameObject
  def initialize(x, y, args, section, switch)
    return if switch && switch[:state] == :taken
    super x + 3, y + 19, 26, 13, :sprite_GunPowder, Vector.new(-2, -2)
    @switch = !switch.nil?
    @life = case args
            when '1' then 10
            when '2' then 5
            when '3' then 2
            else          10
            end
    @color = case args
             when '1' then 0x222222
             when '2' then 0x0033cc
             when '3' then 0xffff00
             else          0x222222
             end
    @counter = 0

    @active_bounds = Rectangle.new x + 1, y + 17, 30, 15
  end

  def update(section)
    b = SB.player.bomb
    if b.collide?(self) && !b.will_explode && !b.exploding
      b.set_exploding(@life)
      SB.stage.set_switch self if @switch
      @dead = true
    end
  end

  def draw(map, section)
    super(map, section, 2, 2, 255, @color)
  end
end

class Crack < SBGameObject
  def initialize(x, y, args, section, switch)
    super x, y, 32, 32, :sprite_Crack
    @broken = switch[:state] == :taken
    @type = section.tileset_num
    i = (@x / C::TILE_SIZE).floor
    j = (@y / C::TILE_SIZE).floor
    @tile = section.tiles[i][j]
    @tile.wall = (args || 13).to_i
  end

  def update(section)
    if @broken or SB.player.bomb.explode?(self) or section.explode?(self)
      @tile.broken = true
      @dead = true
      unless @broken
        section.add_effect(Effect.new(@x, @y, "fx_WallCrack#{@type}", 2, 2))
        SB.stage.set_switch self
      end
    end
  end

  def is_visible(map)
    true
  end
end

class Elevator < SBGameObject
  attr_reader :id

  def initialize(x, y, args, section)
    a = (args || '').split(':')
    type = a[0].to_i
    open = a[0] && a[0][-1] == '!'
    indices = nil
    interval = 0
    case type
    when 2 then w = 64; cols = 4; rows = 1; x_g = y_g = 0; interval = 8
    when 3 then w = 64; cols = rows = nil; x_g = 0; y_g = -3
    when 4 then w = 96; cols = rows = nil; x_g = 0; y_g = -3
    when 5 then w = 64; cols = rows = nil; x_g = y_g = 0
    when 6 then w = 224; cols = rows = nil; x_g = y_g = 0
    when 7 then w = 64; cols = rows = nil; x_g = y_g = 0
    when 8 then w = 64; cols = 2; rows = 3; x_g = y_g = 0; indices = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5]; interval = 5
    when 9..12 then w = 32; cols = rows = nil; x_g = y_g = 0
    when 13 then w = 96; cols = rows = nil; x_g = y_g = 0
    else type = 1; w = 96; cols = rows = nil; x_g = y_g = 0
    end
    super x, y, w, 1, "sprite_Elevator#{type}", Vector.new(x_g, y_g), cols, rows
    @passable = true

    @speed_m = (a[1] || 0).to_i
    @moving = false
    @points = []

    if a[2] && a[2].index(',')
      @stop_time = 30
      ps = a[2..-1] || []
    else
      @stop_time = a[2].to_i
      ps = a[3..-1] || []
    end

    ps.each do |p|
      coords = p.split ','
      p_x = coords[0].to_i * C::TILE_SIZE
      p_y = coords[1].to_i * C::TILE_SIZE
      @points << Vector.new(p_x, p_y)
    end
    if open
      (@points.length - 2).downto(0) do |i|
        @points << @points[i]
      end
    end
    @points << Vector.new(x, y)
    indices = *(0...@img.size) if indices.nil?
    @indices = indices
    @interval = interval
    @active = !a[1] || a[1][-1] != ")"
    @id = a[1].split('(')[1].to_i unless @active

    section.obstacles << self
  end

  def update(section)
    if @active
      cycle @points, @speed_m, section.passengers, section.passengers.map{|p| section.get_obstacles(p.x, p.y)}.flatten, section.ramps, @stop_time
    end
    animate @indices, @interval
  end

  def activate(section, arg = nil)
    @active = !@active
  end

  def is_visible(map)
    true
  end

  def self.parse_args(args)
    a = (args || '').split(':')
    type = a[0].to_i.to_s
    open = a[0] && a[0][-1] == '!' ? '!' : ''
    index = a[1] && a[1].index('(')
    speed = index ? a[1][0...index] : a[1].to_s
    id = index ? a[1].split('(')[1].to_i.to_s : ''
    index2 = a[2] && a[2].index(',')
    stop_time = index2 ? '' : a[2].to_s
    ps = index2 ? a[2..-1].join(':') : (a[3] ? a[3..-1].join(':') : '')

    [type, speed, stop_time, id, open, ps]
  end
end

class SaveBombie < SBGameObject
  def initialize(x, y, args, section, switch)
    super x - 16, y, 64, 32, :sprite_Bombie2, Vector.new(-16, -26), 2, 2
    @id = args.to_i
    @active_bounds = Rectangle.new x - 32, y - 26, 96, 58
    @saved = switch[:state] == :taken
    @indices = [1, 2, 3]
    set_animation 1 if @saved
  end

  def update(section)
    if !@saved && SB.player.bomb.collide?(self)
      SB.player.bomb.reset_hp
      section.save_check_point(@id, self)
      SB.play_sound(Res.sound(:checkPoint))
      StageMenu.play_get_item_effect(@x - section.map.cam.x + @w / 2, @y - section.map.cam.y + @h / 2, :health)
      @saved = true
    end

    if @saved
      animate @indices, 8
    end
  end
end

class Pin < TwoStateObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_Pin, Vector.new(0, 0), 5, 1,
      60, 0, 3, [0], [4], [1, 2, 3, 4], [3, 2, 1, 0], (not args.nil?)

    @obst = Block.new(x, y, 32, 32, true)
    section.obstacles << @obst if args
  end

  def s1_to_s2(section)
    section.obstacles << @obst
  end

  def s2_to_s1(section)
    section.obstacles.delete @obst
  end

  def is_visible(map)
    true
  end
end

class Spikes < TwoStateObject
  def initialize(x, y, args, section)
    args ||= '0'
    a = args.split(',')
    @dir = a[0].to_i
    x_g = y_g = 0
    case @dir
    when 0 then y_g = 1
    when 1 then x_g = -1
    when 2 then y_g = -1
    else        x_g = 1
    end
    super(x - 2, y - 2, 36, 36, :sprite_Spikes, Vector.new(x_g, y_g),
          5, 1, 150, 0, 2,
          [0], [4], [1, 2, 3, 4], [3, 2, 1, 0],
          !a[1].nil? && a[1] != '', nil, (a[2] || 0).to_i)
    @active_bounds = Rectangle.new x, y, 32, 32
    @obst = Block.new(x, y, 32, 32)
    @tint = !a[2].nil?
  end

  def s1_to_s2(section)
    if SB.player.bomb.collide? @obst
      SB.player.bomb.hit
    else
      section.obstacles << @obst
    end
    SB.play_sound(Res.sound(:spikes)) if section.map.cam.intersect?(@active_bounds)
  end

  def s2_to_s1(section)
    section.obstacles.delete @obst
    SB.play_sound(Res.sound(:spikes)) if section.map.cam.intersect?(@active_bounds)
  end

  def update(section)
    super section unless SB.stage.stopped == :all

    b = SB.player.bomb
    if @state2
      if (@dir == 0 && b.x + b.w > @x + 2 && @x + @w - 2 > b.x && b.y + b.h > @y && b.y + b.h <= @y + 2) ||
         (@dir == 1 && b.x >= @x + @w - 2 && b.x < @x + @w && b.y + b.h > @y + 2 && @y + @h - 2 > b.y) ||
         (@dir == 2 && b.x + b.w > @x + 2 && @x + @w - 2 > b.x && b.y >= @y + @h - 2 && b.y < @y + @h) ||
         (@dir == 3 && b.x + b.w > @x && b.x + b.w <= @x + 2 && b.y + b.h > @y + 2 && @y + @h - 2 > b.y)
        SB.player.bomb.hit
      end
    end
  end

  def is_visible(map)
    true
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    angle = case @dir
            when 0 then 0
            when 1 then 90
            when 2 then 180
            else        270
            end
    color = @tint ? 0xffff6600 : 0xffffffff
    @img[@img_index].draw_rot @x + @w/2 + @img_gap.x - map.cam.x, @y + @h/2 + @img_gap.y - map.cam.y, 0, angle, 0.5, 0.5, 2, 2, color
  end
end

class FixedSpikes < GameObject
  def initialize(x, y, args, section)
    a = args ? args.split(',') : [0, 1]
    @dir = a[0].to_i
    type = a[1] || 1
    x_g = y_g = 0
    case @dir
    when 0 then y_g = 1
    when 1 then x_g = -1
    when 2 then y_g = -1
    else        x_g = 1
    end
    super x - 2, y - 2, 36, 36, "sprite_fixedSpikes#{type}", Vector.new(x_g, y_g), 1, 1
    @active_bounds = Rectangle.new(x, y, 32, 32)
    section.obstacles << (@block = SpecialBlock.new(x, y, 32, 32, false, :fixedSpikes))
  end

  def update(section)
    b = SB.player.bomb
    if (@dir == 0 && b.x + b.w > @x + 2 && @x + @w - 2 > b.x && b.y + b.h > @y && b.y + b.h <= @y + 2) ||
       (@dir == 1 && b.x >= @x + @w - 2 && b.x < @x + @w && b.y + b.h > @y + 2 && @y + @h - 2 > b.y) ||
       (@dir == 2 && b.x + b.w > @x + 2 && @x + @w - 2 > b.x && b.y >= @y + @h - 2 && b.y < @y + @h) ||
       (@dir == 3 && b.x + b.w > @x && b.x + b.w <= @x + 2 && b.y + b.h > @y + 2 && @y + @h - 2 > b.y)
      SB.player.bomb.hit
    end
  end

  def remove_obstacle(section)
    section.obstacles.delete(@block)
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    angle = case @dir
            when 0 then 0
            when 1 then 90
            when 2 then 180
            else        270
            end
    @img[0].draw_rot @x + @w/2 + @img_gap.x - map.cam.x, @y + @h/2 + @img_gap.y - map.cam.y, 0, angle, 0.5, 0.5, 2, 2
  end
end

class MovingWall < GameObject
  attr_reader :id

  def initialize(x, y, args, section)
    super x + 2, y + C::TILE_SIZE, 28, 0, :sprite_MovingWall, Vector.new(0, 0), 1, 2
    args = (args || '').split ','
    @id = args[0].to_i
    @closed = args[1].nil?
    if @closed
      until section.obstacle_at?(@x, @y - 1) || @y <= 0
        @y -= C::TILE_SIZE
        @h += C::TILE_SIZE
      end
    else
      h = args[1].to_i
      h = 1 if h == 0
      @max_size = C::TILE_SIZE * h
    end
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.obstacles << self
  end

  def update(section)
    if @active
      @timer += 1
      if @timer % 20 == 0
        @y += @closed ? 16 : -16
        @h += @closed ? -16 : 16
        SB.play_sound(Res.sound(:wallOpen)) if section.map.cam.intersect?(@active_bounds)
        if @closed and @h == 0
          section.unset_fixed_camera if section.fixed_camera
          section.obstacles.delete(self)
          @dead = true
        elsif not @closed and @h == @max_size
          section.unset_fixed_camera if section.fixed_camera
          @active_bounds.y = @y
          @active_bounds.h = @h
          @active = false
        end
      end
      if @timer == 150
        section.unset_fixed_camera
      end
    end
  end

  def activate(section, animate = true)
    if animate || animate.nil?
      @active = true
      @timer = 0
      section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
    elsif @closed
      @dead = true
      section.obstacles.delete(self)
    else
      @y -= @max_size - @h
      @h = @max_size
      @active_bounds.y = @y
      @active_bounds.h = @h
    end
  end

  def is_visible(map)
    map.cam.intersect?(@active_bounds) || @active
  end

  def draw(map, section)
    if !@closed && SB.state == :editor
      y = @y - @max_size
      while y < @y
        index = y == @y - @max_size ? 0 : 1
        @img[index].draw @x - map.cam.x, y - map.cam.y, 0, 2, 2, 0x80ffffff
        y += 16
      end
    end
    @img[0].draw @x - map.cam.x, @y - map.cam.y, 0, 2, 2 if @h > 0
    y = 16
    while y < @h
      @img[1].draw @x - map.cam.x, @y + y - map.cam.y, 0, 2, 2
      y += 16
    end
  end
end

class Ball < GameObject
  def initialize(x, y, args, section, switch)
    if switch[:state] == :taken
      @dead = true
      return
    end
    super x, y, 32, 32, :sprite_Ball
    @start_x = x
    @rotation = 0
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.passengers << self
  end

  def update(section)
    return if @dead

    if @set
      @x += (0.1 * (@rec.x - @x)) if @x.round(2) != @rec.x
    else
      forces = Vector.new 0, 0
      if SB.player.bomb.collide? self
        if SB.player.bomb.x <= @x; forces.x = (SB.player.bomb.x + SB.player.bomb.w - @x) * 0.15
        else; forces.x = -(@x + @w - SB.player.bomb.x) * 0.15; end
      end
      if @bottom
        if @speed.x != 0
          forces.x -= 0.15 * @speed.x
        end

        unless SB.stage.stopped == :all
          SB.stage.switches.each do |s|
            if s[:type] == BallReceptor && bounds.intersect?(s[:obj].bounds)
              next if s[:obj].is_set
              s[:obj].set section
              s2 = SB.stage.find_switch self
              s2[:extra] = @rec = s[:obj]
              s2[:state] = :temp_taken
              @active_bounds.x = @rec.x
              @active_bounds.y = @rec.y - 31
              @set = true
              return
            end
          end
        end
      end
      move forces, section.get_obstacles(@x, @y), section.ramps

      @active_bounds = Rectangle.new @x, @y, @w, @h
      @rotation = 3 * (@x - @start_x)
    end
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    @img[0].draw_rot @x + (@w / 2) - map.cam.x, @y + (@h / 2) - map.cam.y, 0, @rotation, 0.5, 0.5, 2, 2
  end
end

class BallReceptor < SBGameObject
  attr_reader :id, :is_set

  def initialize(x, y, args, section, switch)
    super x, y + 31, 32, 1, :sprite_BallReceptor, Vector.new(0, -8), 1, 2
    @id = args.to_i
    @loaded_set = switch[:state] == :taken
    @active_bounds = Rectangle.new x, y + 23, 32, 13
  end

  def update(section)
    if @loaded_set && !@is_set
      section.activate_object(MovingWall, @id, false)
      @is_set = true
      @img_index = 1
      @will_set = false
    end
  end

  def set(section)
    SB.stage.set_switch self
    section.activate_object MovingWall, @id
    @is_set = true
    @img_index = 1
  end

  def is_visible(map)
    @loaded_set && !@is_set || map.cam.intersect?(@active_bounds)
  end

  def draw(map, section)
    Res.img(:sprite_Ball).draw(@x - map.cam.x, @y - 31 - map.cam.y, 0, 2, 2) if @loaded_set
    super(map)
  end
end

class HideTile
  def initialize(i, j, group, tiles, num)
    @state = 0
    @alpha = 0xff
    @color = 0xffffffff

    @group = group
    @points = []
    check_tile i, j, tiles, 4

    @img = Res.imgs "sprite_ForeWall#{num}".to_sym, 5, 1
  end

  def check_tile(i, j, tiles, dir)
    return -1 if tiles[i].nil? or tiles[i][j].nil?
    return tiles[i][j].wall || -1 if tiles[i][j].hide.nil?
    return 0 if tiles[i][j].hide == @group

    tiles[i][j].hide = @group
    t = 0; r = 0; b = 0; l = 0
    t = check_tile i, j-1, tiles, 0 if dir != 2
    r = check_tile i+1, j, tiles, 1 if dir != 3
    b = check_tile i, j+1, tiles, 2 if dir != 0
    l = check_tile i-1, j, tiles, 3 if dir != 1
    if t < 0 and r >= 0 and b >= 0 and l >= 0; img = 1
    elsif t >= 0 and r < 0 and b >= 0 and l >= 0; img = 2
    elsif t >= 0 and r >= 0 and b < 0 and l >= 0; img = 3
    elsif t >= 0 and r >= 0 and b >= 0 and l < 0; img = 4
    else; img = 0; end

    @points << {x: i * C::TILE_SIZE, y: j * C::TILE_SIZE, img: img}
    0
  end

  def update(section)
    will_show = false
    @points.each do |p|
      rect = Rectangle.new p[:x], p[:y], C::TILE_SIZE, C::TILE_SIZE
      if SB.player.bomb.bounds.intersect? rect
        will_show = true
        break
      end
    end
    if will_show; show
    else; hide; end
  end

  def show
    if @state != 2
      @alpha -= 17
      if @alpha == 51
        @state = 2
      else
        @state = 1
      end
      @color = 0x00ffffff | (@alpha << 24)
    end
  end

  def hide
    if @state != 0
      @alpha += 17
      if @alpha == 0xff
        @state = 0
      else
        @state = 1
      end
      @color = 0x00ffffff | (@alpha << 24)
    end
  end

  def is_visible(map)
    true
  end

  def stop_time_immune?
    true
  end

  def draw(map)
    @points.each do |p|
      @img[p[:img]].draw p[:x] - map.cam.x, p[:y] - map.cam.y, 0, 2, 2, @color
    end
  end
end

class Projectile < GameObject
  attr_reader :owner, :type

  def initialize(x, y, type, angle, owner)
    sprite = "sprite_Projectile#{type}"
    case type
    when 1 then w = 20; h = 12; x_g = -2; y_g = -1; cols = 1; rows = 1; indices = [0]; @speed_m = 4.5
    when 2 then w = 8; h = 8; x_g = -2; y_g = -2; cols = 2; rows = 2; indices = [0, 1, 2, 3]; @speed_m = 2.5
    when 3 then w = 4; h = 40; x_g = 0; y_g = 0; cols = 1; rows = 1; indices = [0]; @speed_m = 10
    when 4 then w = 16; h = 22; x_g = -2; y_g = 0; cols = 1; rows = 1; indices = [0]; @speed_m = 5
    when 5 then w = 20; h = 20; x_g = -16; y_g = -4; cols = 1; rows = 2; indices = [0, 1]; @speed_m = 5
    when 6 then w = 10; h = 10; x_g = -2; y_g = 0; cols = 2; rows = 2; indices = [0, 1, 2, 3]; @speed_m = 4
    when 7 then w = 16; h = 16; x_g = -2; y_g = -2; cols = 1; rows = 1; indices = [0]; @speed_m = 5
    when 8 then w = 48; h = 40; x_g = -6; y_g = -4; cols = 1; rows = 3; indices = [0, 1, 2, 1]; @speed_m = 3.5
    when 9 then w = h = 8; x_g = y_g = -2; cols = rows = 2; indices = [0, 1, 2, 3]; @speed_m = angle == 0 ? 5 : -5; angle = nil; sprite = :sprite_Projectile2
    when 10 then w = 20; h = 20; x_g = -16; y_g = -4; cols = 1; rows = 2; indices = [0, 1]; @speed_m = 5.5
    when 11 then w = 10; h = 10; x_g = -10; y_g = 0; cols = rows = 1; indices = [0]; @speed_m = 5.5
    when 12 then w = h = 12; x_g = -31; y_g = 1; cols = rows = 1; indices = [0]; @speed_m = angle == 330 ? 6 : -6
    when 13 then w = h = 16; x_g = -6; y_g = -6; cols = rows = 2; indices = [0, 1, 2, 3]; @speed_m = 5
    end

    super x, y, w, h, sprite, Vector.new(x_g, y_g), cols, rows
    @active_bounds = Rectangle.new @x - 30, @y - 30, @w + 60, @h + 60
    @type = type
    @angle = angle
    @owner = owner
    @indices = indices
    @visible = true
    @timer = 0
    if @type == 9
      @impulse = Vector.new(@speed_m, -6)
      @gravity_scale = 0.5
    elsif @type == 12
      @impulse = Vector.new(@speed_m, -9)
      @gravity_scale = 0.75
    end
  end

  def update(section)
    if @type == 9 || @type == 12
      prev_g = G.gravity.y
      G.gravity.y *= @gravity_scale
      move(@impulse || Vector.new(0, 0), [], [])
      G.gravity.y = prev_g
      @impulse = nil
    else
      move_free(@angle, @speed_m)
    end

    if @type == 12
      if @angle >= 330 && @angle < 440
        @angle += 2
      elsif @angle <= 210 && @angle > 100
        @angle -= 2
      end
    end

    if @type != 13
      obst = section.get_obstacles(@x, @y)
      obst.each do |o|
        if !o.passable && o.bounds.intersect?(self)
          @dead = true
          break
        end
      end
      return if @dead
    end

    t = (@y + @img_gap.y).floor
    r = (@x + @img_gap.x + @img[0].width).ceil
    b = (@y + @img_gap.y + @img[0].height).ceil
    l = (@x + @img_gap.x).floor
    if t > section.size.y || r < 0 || b < C::TOP_MARGIN || l > section.size.x
      @dead = true
    end
    return if @dead

    if @visible
      @timer = 0 if @timer > 0
    else
      @timer += 1
      @dead = true if @timer > 180
    end

    unless @dead
      animate @indices, 5
      @active_bounds = Rectangle.new @x - 30, @y - 30, @w + 60, @h + 60
    end
  end

  def draw(map, section)
    if @type == 9
      super(map, 2, 2)
    else
      @img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h / 2 - map.cam.y, 0, @angle, 0.5, 0.5, 2, 2
    end
  end

  def is_visible(map)
    @visible = super(map)
    true
  end
end

class Poison < SBGameObject
  def initialize(x, y, args, section)
    super x, y + 31, 32, 1, :sprite_poison, Vector.new(0, -19), 3, 1
    @active_bounds = Rectangle.new(x, y - 19, 32, 28)
  end

  def update(section)
    animate [0, 1, 2], 8
    if SB.player.bomb.collide? self
      SB.player.bomb.hit
    end
  end
end

class Vortex < GameObject
  def initialize(x, y, args, section)
    super x - 11, y - 11, 54, 54, :sprite_vortex, Vector.new(-5, -5), 2, 2
    @active_bounds = Rectangle.new(@x, @y, @w, @h)
    @angle = 0
    a = (args || '').split(',')
    @entrance = a[0].to_i
    @stop_time_immune = !a[1].nil?
  end

  def update(section)
    animate [0, 1, 2, 3, 2, 1], 5
    @angle += 5
    @angle = 0 if @angle == 360

    return if section.fixed_camera

    b = SB.player.bomb
    if @transporting
      b.move_free @aim, 1.5 if @timer < 30
      @timer += 1
      if @timer == 30
        section.add_effect(Effect.new(@x - 3, @y - 3, :fx_transport, 2, 2, 7, [0, 1, 2, 3], 28))
        section.start_warp(@entrance)
        b.in_vortex = false
      elsif @timer == 60
        @transporting = false
      end
    elsif b.collide?(self)
      b.stop
      b.active = false
      SB.play_sound(Res.sound(:portal))
      @aim = Vector.new(@x + (@w - b.w) / 2, @y + (@h - b.h) / 2 + 3)
      @transporting = true
      @timer = 0
    end
  end

  def draw(map, section)
    color = @stop_time_immune ? 0xffffff33 : 0xffffffff
    @img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h/2 - map.cam.y, 0, @angle, 0.5, 0.5, 2, 2, color
  end

  def stop_time_immune?
    @stop_time_immune
  end
end

class AirMattress < GameObject
  def initialize(x, y, args, section)
    a = (args || '').split(',')
    super x, y + 16, (a[1] || 2).to_i * C::TILE_SIZE, 1, :sprite_airMattress, Vector.new(0, -2), 1, 3
    @active_bounds = Rectangle.new(@x, @y - 2, @w, 16)
    @timer = 0
    @points = [
      Vector.new(@x, @y),
      Vector.new(@x, @y + 16)
    ]
    @speed_m = 0.16
    case a[0]
    when '2' then @speed_d = 2; @color = 0xcccc00
    when '3' then @speed_d = 4; @color = 0xff3333
    else          @speed_d = 0.5; @color = 0x338000
    end
    @passable = true
    @state = :normal
    section.obstacles << self
  end

  def update(section)
    b = SB.player.bomb
    if @state == :normal
      if b.bottom == self
        @state = :down
        @timer = 0
        set_animation 0
      else
        x = @timer + 0.5
        @speed_m = -0.0001875 * x**2 + 0.015 * x
        cycle @points, @speed_m, [b]
        @timer += 1
        if @timer == 80
          @timer = 0
        end
      end
    elsif @state == :down
      animate [0, 1, 2], 8 if @img_index != 2
      if b.bottom == self
        move_carrying Vector.new(@x, @y + @speed_d), @speed_d, [b], section.get_obstacles(b.x, b.y), section.ramps
      else
        @state = :up
        set_animation 2
      end
    elsif @state == :up
      animate [2, 1, 0], 8 if @img_index != 0
      move_carrying Vector.new(@x, @y - 1), 0.5, [b], section.get_obstacles(b.x, b.y), section.ramps
      if SB.player.bomb.bottom == self
        @state = :down
      elsif @y.round == @points[0].y
        @y = @points[0].y
        @state = :normal
      end
    end
    @active_bounds = Rectangle.new(@x, @y - 2, @w, 16)
  end

  def draw(map, section)
    super(map, @w / C::TILE_SIZE, 2, 255, @color)
  end
end

class Branch < GameObject
  def initialize(x, y, args, section)
    a = (args || '').split(',')
    @scale = a[0].to_i
    @scale = 2 if @scale == 0
    @left = a[1].nil?
    super x, y, @scale * C::TILE_SIZE, 1, :sprite_branch, Vector.new(@left ? 0 : 4, 0)
    @passable = true
    @active_bounds = Rectangle.new(@x, @y, @w, @img[0].height)
    section.obstacles << self
  end

  def update(section); end

  def draw(map, section)
    super(map, @scale, 2, 255, 0xffffff, nil, @left ? nil : :horiz)
  end
end

class Water
  attr_reader :x, :y, :w, :h, :bounds

  def initialize(x, y, args, section)
    a = (args || '').split ','
    @x = x
    @y = y + 8
    @w = C::TILE_SIZE * (a[0] || 1).to_i
    @h = C::TILE_SIZE * (a[1] || 1).to_i - 8
    @bounds = Rectangle.new(@x, @y, @w, @h)
    section.add_interacting_element(self)
  end

  def update(section)
    b = SB.player.bomb
    if b.collide?(self)
      b.stored_forces.y -= 1
      unless @touched
        b.stop
        SB.player.die
        section.add_effect(Effect.new(b.x + b.w / 2 - 32, @y - 19, :fx_water, 1, 4, 8))
        @touched = true
      end
    end
  end

  def dead?
    false
  end

  def is_visible(map)
    map.cam.intersect? @bounds
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    return unless SB.state == :editor

    img = Res.img('editor_el_41-Water')
    x = @x / C::TILE_SIZE
    y = (@y - 8) / C::TILE_SIZE
    w = @w / C::TILE_SIZE
    h = (@h + 8) / C::TILE_SIZE
    map.foreach do |i, j, xx, yy|
      if i >= x && i < x + w && j >= y && j < y + h
        img.draw(xx, yy, 0, 2, 2)
      end
    end
  end
end

class ForceField < GameObject
  def initialize(x, y, args, section, switch)
    return if switch[:state] == :taken
    super x, y, 32, 32, :sprite_ForceField, Vector.new(-14, -14), 3, 1
    @life_time = (args || 20).to_i * 60
    @active_bounds = Rectangle.new(x - 14, y - 14, 60, 60)
    @alpha = 255
  end

  def update(section)
    animate [0, 1, 2, 1], 10
    b = SB.player.bomb
    if @taken
      @x = b.x + b.w / 2 - 16; @y = b.y + b.h / 2 - 16
      @timer += 1
      @dead = true if @timer == @life_time
      if @timer >= @life_time - 120
        if @timer % 5 == 0
          @alpha = @alpha == 0 ? 255 : 0
        end
      end
    elsif b.collide? self
      b.set_invulnerable @life_time
      SB.stage.set_switch self
      @taken = true
      @timer = 0
    end
  end

  def is_visible(map)
    @taken || @active_bounds && map.cam.intersect?(@active_bounds)
  end

  def draw(map, section)
    super(map, 2, 2, @alpha)
  end
end

class Stalactite < SBGameObject
  RANGE = 288

  attr_reader :id, :dying

  def initialize(x, y, args, section)
    args = (args || '').split(',')
    super x + 11, y - 16, 10, 48, "sprite_stalactite#{args[0]}", Vector.new(-9, 0), 3, 2
    @active_bounds = Rectangle.new(x + 2, y, 28, 48)
    @normal = args[1].nil?
    @id = args[2].to_i
    section.active_object = self unless @normal
  end

  def update(section)
    if @dying
      animate [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 5], 5
      @timer += 1
      @dead = true if @timer == 60
    elsif @moving
      move Vector.new(0, 0), section.get_obstacles(@x, @y), section.ramps
      SB.player.bomb.hit if SB.player.bomb.collide?(self)
      if @bottom
        @dying = true
        @moving = false
        @timer = 0
      end
    elsif @will_move
      if @timer % 4 == 0
        if @x % 2 == 0; @x += 1
        else; @x -= 1; end
      end
      @timer += 1
      @moving = true if @timer == 30
    else
      b = SB.player.bomb
      if (@normal && b.x + b.w > @x - 80 && b.x < @x + 90 && b.y > @y && b.y < @y + RANGE) ||
         (!@normal && b.x + b.w > @x && b.x < @x + @w && b.y + b.h > @y - C::TILE_SIZE && b.y + b.h < @y)
        @will_move = true
        @timer = 0
      end
    end
  end

  def activate(section, arg = nil)
    @will_move = true
    @timer = 0
  end

  def is_visible(map)
    @will_move || @moving || map.cam.intersect?(@active_bounds)
  end
end

class Board < GameObject
  def initialize(x, y, facing_right, section, switch)
    super x, y, 50, 4, :sprite_board, Vector.new(0, -1)
    @facing_right = facing_right
    @passable = true
    @active_bounds = Rectangle.new(x, y - 1, 50, 5)
    section.obstacles << self
    @switch = switch
  end

  def update(section)
    b = SB.player.bomb
    if b.collide? self and b.y + b.h <= @y + @h
      b.y = @y - b.h
    elsif b.bottom == self
      section.active_object = self
    elsif section.active_object == self
      section.active_object = nil
    end
  end

  def take(section)
    SB.player.add_item @switch
    @switch[:state] = :temp_taken
    section.obstacles.delete self
    section.active_object = nil
    @dead = true
  end

  def draw(map, section)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? nil : :horiz)
  end
end

class Rock < SBGameObject
  def initialize(x, y, args, section)
    case args
    when '2' then
      objs = [[4, 54, 186, 42], [56, 26, 108, 28], [164, 46, 20, 8], ['l', 60, 0, 56, 26], ['r', 116, 0, 46, 26]]
      w = 192; h = 96; x -= 80; y -= 64
    else
      objs = [['l', 0, 0, 26, 96], [26, 0, 32, 96], [58, 27, 31, 69], ['r', 89, 27, 18, 35], [89, 62, 30, 34]]
      w = 120; h = 96; x -= 44; y -= 64
    end
    unless SB.state == :editor
      objs.each do |o|
        if o[0].is_a? String
          section.ramps << Ramp.new(x + o[1], y + o[2], o[3], o[4], o[0] == 'l')
        else
          section.obstacles << Block.new(x + o[0], y + o[1], o[2], o[3])
        end
      end
    end
    super x, y, w, h, "sprite_rock#{args || 1}", Vector.new(0, 0)
  end

  def update(section); end
end

class Monep < GameObject
  include Speech

  def initialize(x, y, args, section, switch)
    super x, y, 62, 224, :sprite_monep, Vector.new(0, 0), 3, 2
    @active_bounds = Rectangle.new(x, y, 62, 224)
    @blocking = switch[:state] != :taken
    @state = :normal
    @balloon = Res.img :fx_Balloon3
    init_speech(:msg_monep)
  end

  def update(section)
    if @blocking
      b = SB.player.bomb
      if b.collide? self
        section.active_object = self
        if @state == :normal
          section.set_fixed_camera(@x + @w / 2, @y + 50)
          set_animation 3
          @state = :speaking
          @timer = 0
        elsif @state == :speaking
          @timer += 1
          if @timer == 600 or SB.key_pressed?(:confirm)
            section.unset_fixed_camera
            set_animation 0
            @state = :waiting
          end
        elsif b.x > @x + @w / 2 - b.w / 2
          b.x = @x + @w / 2 - b.w / 2
        end
      elsif section.active_object == self
        section.active_object = nil
        @state = :waiting
      end
    end
    if @state == :speaking; animate [3, 4, 5, 4, 5, 3, 5], 10
    else; animate [0, 1, 0, 2], 10; end
    @speaking = @state == :speaking
  end

  def activate(section, arg = nil)
    @blocking = false
    @state = :normal
    section.active_object = nil
    SB.stage.set_switch(self)
  end

  def draw(map, section)
    super(map, 2, 2)
    @balloon.draw @x - map.cam.x, @y + 30 - map.cam.y, 0, 2, 2 if @state == :waiting and SB.player.bomb.collide?(self)
    draw_speech
  end
end

class StalactiteGenerator < SBGameObject
  def initialize(x, y, args, section)
    super x, y + 10, 96, 22, :sprite_graphic11, Vector.new(0, -26)
    @active = true
    @limit = (args.to_i - 1) * C::TILE_SIZE
    @timer = 0
    @s_x = []
    @s_y = @y - 10 + C::TILE_SIZE
    @amount = 2
  end

  def update(section)
    if @active and SB.player.bomb.collide?(self)
      if @timer == 0
        @amount.times do
          @s_x << @x + 96 + rand(@limit)
        end
        section.set_fixed_camera(@s_x.sum / @s_x.size, @s_y)
      end
      @timer += 1
      if @timer == 60
        @s_x.each do |s_x|
          section.add(Stalactite.new(s_x, @s_y, ',$', section))
          section.add_effect(Effect.new(s_x - 16, @s_y - 32, :fx_spawn, 2, 2, 6))
        end
      elsif @timer == 120
        section.unset_fixed_camera
        @s_x = []
        @active = false
      end
    elsif not @active
      @timer += 1
      if @timer == 180
        @active = true
        @timer = 0
      end
    end
  end

  def activate(section, arg = nil)
    @amount = 1
  end

  def id; 0; end

  def is_visible(map)
    true
  end
end

class TwinWalls < GameObject
  attr_reader :id

  def initialize(x, y, args, section)
    super x + 2, y + C::TILE_SIZE, 28, 0, :sprite_MovingWall, Vector.new(0, 0), 1, 2
    args = (args || '').split ','
    @id = (args[0] || 1).to_i
    @closed = args[1] == '.'
    if @id != 0
      section.add(@twin = TwinWalls.new(C::TILE_SIZE * args[2].to_i, C::TILE_SIZE * args[3].to_i, "0,#{@closed ? '!' : '.'}", section))
    end

    if @closed
      until @y <= 0 || section.obstacle_at?(@x, @y - 1)
        @y -= C::TILE_SIZE
        @h += C::TILE_SIZE
      end
      @max_size = @h
    else
      @max_size = 0
      y = @y
      until y <= 0 || section.obstacle_at?(@x, y - 1)
        y -= C::TILE_SIZE
        @max_size += C::TILE_SIZE
      end
    end
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.obstacles << self
  end

  def update(section)
    if @active
      @timer += 1
      if @timer % 20 == 0
        @y += @closed ? 16 : -16
        @h += @closed ? -16 : 16
        @active_bounds = Rectangle.new @x, @y, @w, @h
        SB.play_sound(Res.sound(:wallOpen)) if section.map.cam.intersect?(@active_bounds)
        if @closed && @h == 0 || !@closed && @h == @max_size
          @closed = !@closed
          @active = false
          section.unset_fixed_camera
        end
      end
      if @timer == 150
        section.unset_fixed_camera
      end
    end
  end

  def activate(section, arg = nil)
    unless @active
      @active = true
      @timer = 0
      @twin.activate(section) if @twin
      section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
    end
  end

  def is_visible(map)
    map.cam.intersect?(@active_bounds) || @active
  end

  def draw(map, section)
    if !@closed && SB.state == :editor
      y = @y - @max_size
      while y < @y
        index = y == @y - @max_size ? 0 : 1
        @img[index].draw @x - map.cam.x, y - map.cam.y, 0, 2, 2, 0x80ffffff
        y += 16
      end
    end
    @img[0].draw @x - map.cam.x, @y - map.cam.y, 0, 2, 2 if @h > 0
    y = 16
    while y < @h
      @img[1].draw @x - map.cam.x, @y + y - map.cam.y, 0, 2, 2
      y += 16
    end
  end
end

# named 'AButton' to not conflict with MiniGL's Button
class AButton < SBGameObject
  def initialize(x, y, args, section)
    super x, y + 18, 32, 16, :sprite_Button, Vector.new(0, 0), 1, 3
    args = (args || '').split ','
    @id = args[0].to_i
    @type =
      case args[1]
      when '2' then Elevator
      when '3' then Box
      when '4' then Gate
      else          TwinWalls
      end
    @state = 0
  end

  def update(section)
    b = SB.player.bomb
    if @state == 1
      animate([1, 2], 5) unless @img_index == 2
      if @img_index == 2 && !b.collide?(self)
        @state = 2
      end
    elsif @state == 2
      animate([1, 0], 5)
      if @img_index == 0 && !b.collide?(self)
        @state = 0
      end
    elsif @state == 0 && b.collide?(self)
      if @type
        section.activate_object(@type, @id)
      end
      @state = 1
      set_animation 1
    end
  end
end

class Lift < SBGameObject
  def initialize(x, y, args, section)
    args = (args || '').split(',')
    type = args[0].to_i
    indices = nil
    interval = 0
    case type
    when 2 then w = 64; cols = 4; rows = 1; x_g = y_g = 0; interval = 8
    when 3 then w = 64; cols = rows = nil; x_g = 0; y_g = -3
    when 4 then w = 96; cols = rows = nil; x_g = 0; y_g = -3
    when 5 then w = 64; cols = rows = nil; x_g = y_g = 0
    when 6 then w = 224; cols = rows = nil; x_g = y_g = 0
    when 7 then w = 64; cols = rows = nil; x_g = y_g = 0
    when 8 then w = 64; cols = 2; rows = 3; x_g = y_g = 0; indices = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5]; interval = 5
    when 9..12 then w = 32; cols = rows = nil; x_g = y_g = 0
    when 13 then w = 96; cols = rows = nil; x_g = y_g = 0
    else type = 1; w = 96; cols = rows = nil; x_g = y_g = 0
    end
    super x, section.size.y, w, 1, "sprite_Elevator#{type}", Vector.new(x_g, y_g), cols, rows
    @start = Vector.new(x, @y)
    @x_force = args[1].to_f
    @y_force = args[2] && !args[2].empty? ? -args[2].to_f : -8
    @gravity_scale = args[3] && !args[3].empty? ? args[3].to_f : 0.3
    @delay = args[4].to_i
    @wait_time = args[5] && !args[5].empty? ? args[5].to_i : 60
    @timer = @wait_time - 1
    @passable = true
    @active_bounds = Rectangle.new(x, @y - 5 * C::TILE_SIZE, 64, 5 * C::TILE_SIZE)
    indices = *(0...@img.size) if indices.nil?
    @indices = indices
    @interval = interval
  end

  def update(section)
    animate(@indices, @interval)
    b = SB.player.bomb
    if @launched
      prev_g = G.gravity.y
      G.gravity.y *= @gravity_scale
      move_carrying(Vector.new(0, @force), nil, section.passengers, section.get_obstacles(b.x, b.y), section.ramps, true)
      G.gravity.y = prev_g
      @force += 1 if @force < 0
      @force = 0 if @force > 0
      if @y > section.size.y + C::TILE_SIZE
        @x = @start.x; @y = @start.y
        @speed.x = @speed.y = @timer = 0
        section.obstacles.delete(self)
        @launched = false
      end
    elsif @delay > 0
      @delay -= 1
    else
      @timer += 1
      if @timer >= @wait_time
        prev_g = G.gravity.y
        G.gravity.y *= @gravity_scale
        move_carrying(Vector.new(@x_force, @y_force), nil, section.passengers, section.get_obstacles(b.x, b.y), section.ramps, true)
        G.gravity.y = prev_g
        @force = @y_force * 0.25
        section.obstacles << self
        @launched = true
      end
    end
  end

  def is_visible(map)
    true
  end
end

class Crusher < SBGameObject
  def initialize(x, y, args, section)
    case args
    when '2' then w = 96; y_g = -4
    else          w = 32; y_g = 0
    end
    super x, y, w, 16, "sprite_Crusher#{args}", Vector.new(0, y_g), 4, 1
    @bottom = Block.new(x, y + 144, w, 16, false)
    @state = 0
    @timer = 0
    @active_bounds = Rectangle.new(x, y, w, 160)
    section.obstacles << self << @bottom
  end

  def update(section)
    @timer += 1
    if @state % 2 == 0
      if @timer == 60
        grow 14
        set_animation @state == 0 ? 1 : 2
        @timer = 0
        @state += 1
      end
    else
      animate(@state == 1 ? [1, 2, 3] : [2, 1, 0], 6)
      if @timer == 6
        grow 22
      elsif @timer == 12
        grow 28
        @timer = 0
        @state = @state == 1 ? 2 : 0
      end
    end
  end

  def grow(amount)
    amount = -amount if @state > 1
    @h += amount
    @bottom.instance_eval { @y -= amount; @h += amount }
    b = SB.player.bomb
    if b.bounds.intersect?(@active_bounds)
      if @y + @h > b.y
        if @y + @h + b.h > @bottom.y
          b.hit(999, true)
        else
          b.y = @y + @h
        end
      elsif @bottom.y < b.y + b.h
        if @bottom.y - b.h < @y + @h
          b.hit(999, true)
        else
          b.y = @bottom.y - b.h
        end
      end
    end
  end
end

class Boulder < GameObject
  def initialize(x, y, args, section)
    super x + 20, y + 5, 56, 86, :sprite_Boulder, Vector.new(-20, -5)
    @box = Rectangle.new(x + 5, y + 20, 86, 56)
    @state = :waiting
    @start_x = @x
    @facing_right = args.nil?
    @max_speed.x = 5
  end

  def update(section)
    b = SB.player.bomb
    if @state == :waiting
      if b.y > @y && (@facing_right && b.x > @x + 100 && b.x < @x + 120 || !@facing_right && b.x + b.w < @x - 44 && b.x + b.w > @x - 64)
        @state = :falling
      end
    else
      move(Vector.new(@facing_right ? 0.03 : -0.03, 0), section.get_obstacles(@x - 15, @y, 86, 86), section.ramps)
      if @x + @img_gap.x > section.size.x or @y + @img_gap.y > section.size.y
        @dead = true
        return
      end

      @stored_forces.x = @facing_right ? 3 : -3 if @bottom && @speed.x == 0
      @box.x = @x - 15; @box.y = @y + 15
      if b.collide?(self) or b.bounds.intersect?(@box)
        b.hit
      end
    end
  end

  def draw(map, section)
    super(map, 2, 2, 255, 0xffffff, @x - @start_x)
  end

  def is_visible(map)
    true
  end
end

class HeatBomb < SBGameObject
  class ProjectileHitBox
    def initialize(x, y, w, h)
      @x = x; @y = y; @w = w; @h = h
    end

    def bounds
      Rectangle.new(@x, @y, @w, @h)
    end
  end

  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_HeatBomb, Vector.new(0, 0), 3, 2
    @state = 0
    @passable = false
    section.obstacles << self
    @proj_hit_box = ProjectileHitBox.new(x - 10, y - 10, 52, 52)
    @radius = (args || 60).to_i
  end

  def update(section)
    return if section.fixed_camera

    if @state == 0
      animate [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1], 5
      if SB.player.bomb.explode?(self) || section.explode?(self) || section.projectile_hit?(@proj_hit_box)
        @state = 1
        @timer = 0
        set_animation 2
      end
    elsif @state == 1
      animate [2, 0], @timer < 60 ? 6 : 3
      if section.map.cam.intersect?(@active_bounds) && (@timer >= 60 && @timer % 6 == 0 || @timer % 12 == 0)
        SB.play_sound(Res.sound(:beep))
      end
      @timer += 1
      if @timer == 120
        @state = 2
        @timer = 0
        section.add_effect(Explosion.new(@x + @w / 2, @y + @h / 2, @radius, self))
        set_animation 3
        section.obstacles.delete(self)
      end
    else
      animate [3, 4, 5], 7
      @timer += 1
      if @timer == 21
        @dead = true
      end
    end
  end

  def is_visible(map)
    true
  end
end

class FragileFloor < SBGameObject
  def initialize(x, y, args, section)
    type = args == '2' ? 2 : 1
    super x, y, 32, 32, "sprite_fragileFloor#{type}", Vector.new(0, 0), 4, 1
    @life = 10

    section.obstacles << self
  end

  def update(section)
    if @falling
      if @img_index < 3
        animate([0, 1, 2, 3], 7)
      else
        unless @removed
          section.obstacles.delete(self)
          @removed = true
        end
        move(Vector.new(0, 0), section.obstacles, section.ramps)
      end
      @dead = true if @bottom || @y > section.size.y
    else
      b = SB.player.bomb
      if b.bottom == self
        @life -= 1
        if @life == 0
          @falling = true
        end
      end
    end
  end
end

class Box < SBGameObject
  MOVE_SPEED = 2.5

  attr_reader :id

  def initialize(x, y, args, section)
    super(x + 2, y, 28, 32, :sprite_box, Vector.new(-2, 0))
    section.obstacles << self
    @max_speed.x = MOVE_SPEED
    @id = args.to_i
    @start_x = @x
    @start_y = @y
  end

  def update(section)
    b = SB.player.bomb
    obst = section.get_obstacles(@x, @y)
    if b.left == self && SB.key_down?(:left)
      move_carrying(Vector.new(-MOVE_SPEED, 0), nil, section.obstacles, obst, section.ramps)
      b.instance_exec { @left = nil }
      b.move(Vector.new(-MOVE_SPEED, 0), section.get_obstacles(b.x, b.y), section.ramps)
    elsif b.right == self && SB.key_down?(:right)
      move_carrying(Vector.new(MOVE_SPEED, 0), nil, section.obstacles, obst, section.ramps)
      b.instance_exec { @right = nil }
      b.move(Vector.new(MOVE_SPEED, 0), section.get_obstacles(b.x, b.y), section.ramps)
    else
      move(Vector.new(@bottom ? -@speed.x : 0, 0), obst, section.ramps)
    end
  end

  def activate(section, arg = nil)
    section.add_effect(Effect.new(@x - 16, @y - 16, :fx_spawn, 2, 2, 6))
    section.add_effect(Effect.new(@start_x - 16, @start_y - 16, :fx_spawn, 2, 2, 6))
    @x = @start_x
    @y = @start_y
  end

  def remove_obstacle(section)
    section.obstacles.delete(self)
  end

  def is_visible(map)
    true
  end

  def stop_time_immune?
    true
  end
end

class MountainBombie < SBGameObject
  include Speech

  def initialize(x, y, args, section, switch)
    super(x - 20, y, 72, 32, :sprite_Bombie3, Vector.new(12, -6), 4, 2)
    init_speech(switch[:state] == :taken ? :msg_mnt_bomb2 : :msg_mnt_bomb)
    @indices = [0, 1, 2]
    @interval = 8
    @balloon = Res.img :fx_Balloon1
  end

  def update(section)
    update_speech(section)
    @img_gap.x = @facing_right ? 16 : 12
  end

  def activate
    change_speech(:msg_mnt_bomb2)
    SB.stage.set_switch(self)
    SB.stage.switches.each do |s|
      if s[:obj].is_a? WindMachine
        s[:obj].activate
      end
    end
    @indices = [3, 4, 5]
    set_animation 3
  end

  def draw(map, section)
    super(map, section, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    @balloon.draw @x - map.cam.x + 16, @y - map.cam.y - 32, 0, 2, 2 if @active
    draw_speech
  end
end

class WindMachine < SBGameObject
  FORCE = 0.05

  def initialize(x, y, args, section, switch)
    super(x - 304, y - 32, 640, 64, :sprite_windMachine, Vector.new(0, -16), 1, 10)
    args = (args || '').split(',')
    @range = args[0].to_i * C::TILE_SIZE
    @range = 78 * C::TILE_SIZE if @range == 0
    @active = switch[:state] == :taken || !args[1].nil?
    @timer = 0
    @rnd = Random.new
  end

  def update(section)
    if @active
      if @timer < 60
        animate([1, 0], 8)
        @timer += 1
        return
      end

      animate([2, 3, 4, 5, 6, 7, 8, 9], 5)
      section.add_effect(Effect.new(@x - 10 + @rnd.rand(@w + 20), @y - 120 - @rnd.rand(@range), :fx_wind, 8, 1, 7))
      b = SB.player.bomb
      if b.x + b.w > @x - 20 && @x + @w + 20 > b.x && b.y + b.h > @y - @range && b.y + b.h <= @y
        d_y = @y - b.y - b.h
        b.speed.y -= G.gravity.y + [FORCE * (1 - d_y/@range), 0.0101].max
      end
    end
  end

  def activate
    SB.stage.set_switch(self)
    set_animation(1)
    @active = true
    @timer = 0
  end

  def is_visible(map)
    @active || map.cam.intersect?(@active_bounds)
  end
end

class Masstalactite < SBGameObject
  def initialize(x, y, args, section)
    super x + 1, y - 8, 30, 96, :sprite_masstalactite, Vector.new(-69, 0), 2, 3
  end

  def update(section)
    b = SB.player.bomb
    if @dying
      animate [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 5], 5
      @timer += 1
      @dead = true if @timer == 60
      b.hit if b.bounds.intersect?(@impact_area) && @timer <= 30
    elsif @moving
      move Vector.new(0, 0), section.get_obstacles(@x, @y, @w, @h), section.ramps
      b.hit if b.collide?(self)
      if @bottom
        @dying = true
        @moving = false
        @timer = 0
        @impact_area = Rectangle.new(@x - 60, @y + @h - 4, 150, 4)
      end
    elsif @will_move
      if @timer % 4 == 0
        if @timer % 8 == 0; @x += 2
        else; @x -= 2; end
      end
      @timer += 1
      @moving = true if @timer == 12
    else
      if b.x + b.w > @x - 90 && b.x < @x + @w + 90 && b.y > @y && b.y < @y + 320
        @will_move = true
        @timer = 0
      end
    end
  end
end

class SideSpring < SBGameObject
  FORCE = 5

  def initialize(x, y, args, section)
    super(x, y, 32, 32, :sprite_Spring, Vector.new(-2, -16), 3, 2)
    @to_left = args.nil?
  end

  def update(section)
    b = SB.player.bomb
    if b.collide?(self)
      unless @active
        factor = @to_left && b.speed.x > 0 ? b.speed.x : !@to_left && b.speed.x < 0 ? -b.speed.x : 1
        b.stored_forces.x += (@to_left ? -1 : 1) * FORCE * (factor < 1 ? 1 : factor > 2.5 ? 2.5 : factor)
        @active = true
      end
    elsif @active
      @active = false
    end
  end

  def draw(map, section)
    super(map, section, 2, 2, 255, 0xffffff, @to_left ? -90 : 90)
  end
end

class IcyFloor
  attr_reader :bounds

  def initialize(x, y, args, section)
    @bounds = Rectangle.new(x, y + C::TILE_SIZE - 1, C::TILE_SIZE, 1)
  end

  def update(section)
    b = SB.player.bomb
    b.slipping = true if b.collide?(self)
  end

  def is_visible(map)
    map.cam.intersect?(@bounds)
  end

  def dead?
    false
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    Res.img('editor_el_75-IcyFloor').draw(@bounds.x - map.cam.x, @bounds.y - 15 - map.cam.y, 0, 2, 2) if SB.state == :editor
  end
end

class Puzzle < SBGameObject
  def initialize(x, y, args, section)
    super(x - 24, y - 46, 80, 78, :sprite_puzzle)
    @pieces = [nil, nil, nil, nil]
    @id = args.to_i

    switches = SB.stage.find_switches(PuzzlePiece)
    switches.each do |s|
      if s[:state] == :used
        num = s[:args].to_i
        @pieces[num - 1] = Res.img("sprite_puzzlePiece#{num}")
      end
    end
    @will_set = @pieces.all?
  end

  def update(section)
    if @will_set
      section.activate_object(MovingWall, @id, false)
      @will_set = false
    end

    if SB.player.bomb.collide?(self)
      section.active_object = self
    elsif section.active_object == self
      section.active_object = nil
    end
  end

  def add_piece(section, number)
    @pieces[number - 1] = Res.img("sprite_puzzlePiece#{number}")
    if @pieces.all?
      section.activate_object(MovingWall, @id)
      section.active_object = nil
    end
  end

  def draw(map, section)
    super(map)
    @pieces.each_with_index do |p, i|
      next unless p
      x_off = i == 1 ? -10 : i == 3 ? -2 : 0
      y_off = i == 2 ? -2 : i == 3 ? -10 : 0
      p.draw(@x + 8 + (i % 2) * 32 + x_off - map.cam.x, @y + 4 + (i / 2) * 32 + y_off - map.cam.y, 0, 2, 2)
    end
  end
end

class PoisonGas < SBGameObject
  def initialize(x, y, args, section)
    super(x - 18, y - 18, 68, 68, :sprite_poisonGas, Vector.new(-2, -2), 3, 1)
    @lifetime = args if args.is_a?(Integer)
  end

  def update(section)
    animate([0, 1, 2], 7)
    SB.player.bomb.poisoned = true if SB.player.bomb.collide?(self)
    if @lifetime
      @lifetime -= 1
      @dead = true if @lifetime == 0
    end
  end

  def is_visible(map)
    @lifetime || map.cam.intersect?(@active_bounds)
  end
end

class Cannon < SBGameObject
  ROT_SPEED = 6

  def initialize(x, y, args, section)
    super(x, y, 32, 32, :sprite_Cannon)
    @angles = (args || '').split(',').map(&:to_i)
    @angles << 0 if @angles.empty?
    @a_index = 0
    @angle = @angles[0]
    @timer = 0

    @base = Res.img(:sprite_cannonBase)
    @base_angle = if section.obstacle_at?(x, y + C::TILE_SIZE)
                    0
                  elsif section.obstacle_at?(x - C::TILE_SIZE, y)
                    90
                  elsif section.obstacle_at?(x, y - C::TILE_SIZE)
                    180
                  else
                    270
                  end
  end

  def update(section)
    if @rotating
      next_angle = @angles[@a_index]
      if @angle < next_angle && @angle + ROT_SPEED >= next_angle ||
         @angle < next_angle + 360 && @angle + ROT_SPEED >= next_angle + 360
        @angle = next_angle
        @rotating = false
      else
        @angle = (@angle + ROT_SPEED) % 360
      end
    else
      section.add(Projectile.new(@x + @w / 2 - 8, @y + @h / 2 - 8, 7, @angle - 90, self)) if @timer == 0
      @timer += 1
      if @timer == 90
        @a_index += 1
        @a_index = 0 if @a_index >= @angles.length
        @rotating = true unless @angle == @angles[@a_index]
        @timer = 0
      end
    end
  end

  def draw(map, section)
    super(map, section, 2, 2, 255, 0xffffff, @angle)
    @base.draw_rot(@x + @w / 2 - map.cam.x, @y + @h / 2 - map.cam.y, 0, @base_angle, 0.5, -0.33333, 2, 2)
  end
end

class MBlock < Block
  attr_writer :x, :y
end

class FallingWall < GameObject
  DEGREE = Math::PI / 180
  RADIUS = C::TILE_SIZE * Math.sqrt(2) / 2

  def initialize(x, y, args, section)
    a = (args || '').split(',')
    type = a[0] == '2' ? 2 : 1
    size = a[1].to_i
    size = 4 if size == 0
    super(x, y - (size - 1) * C::TILE_SIZE, C::TILE_SIZE, size * C::TILE_SIZE, "sprite_fallingWall#{type}", Vector.new(0, 0), 4, 2)
    @active_bounds = Rectangle.new(@x, @y, @w, @h)
    @blocks = []
    (0...size).each do |i|
      @blocks << MBlock.new(x, y - i * C::TILE_SIZE, C::TILE_SIZE, C::TILE_SIZE, true)
    end
    section.obstacles << self
    @angle = Math::PI / 2
    @img_index = @timer = 0
  end

  def update(section)
    p = SB.player.bomb
    if @crashing
      @timer += 1
      if @timer == 6
        if @img_index < 3
          @img_index += 1
        else
          @dead = true
        end
        @timer = 0
      end
    elsif @falling
      @angle += DEGREE * @angle**3.5 * 0.1
      @angle = Math::PI if @angle > Math::PI
      c_angle = @angle - Math::PI / 4
      c_a = Math.cos(@angle); s_a = Math.sin(@angle)
      c_c = Math.cos(c_angle); s_c = Math.sin(c_angle)
      @blocks.each_with_index do |b, i|
        p.hit if p.collide?(b)
        b.x = @x + (c_a * i - 0.5) * C::TILE_SIZE + c_c * RADIUS
        b.y = @y + (@blocks.size - s_a * i - 0.5) * C::TILE_SIZE - s_c * RADIUS
      end
      if @angle == Math::PI
        @blocks.each { |b| section.obstacles.delete(b) }
        @crashing = true
      end
    elsif p.y > @y && p.y < @y + @h && p.x > @x - @blocks.length * C::TILE_SIZE && p.x < @x
      section.obstacles.delete(self)
      @blocks.each do |b|
        section.obstacles << b
      end
      @falling = true
    end
  end

  def draw(map, section)
    img_angle = -((@angle * 180 / Math::PI) - 90)
    x_off = C::TILE_SIZE / 2 - map.cam.x
    y_off = C::TILE_SIZE / 2 - map.cam.y
    @blocks.each_with_index do |b, i|
      @img[i == @blocks.size - 1 ? @img_index : @img_index + 4].draw_rot(b.x + x_off, b.y + y_off, 0, img_angle, 0.5, 0.5, 2, 2)
      # G.window.draw_quad(b.x - map.cam.x, b.y - map.cam.y, 0xff000000,
      #                    b.x + b.w - map.cam.x, b.y - map.cam.y, 0xff000000,
      #                    b.x - map.cam.x, b.y + b.h - map.cam.y, 0xff000000,
      #                    b.x + b.w - map.cam.x, b.y + b.h - map.cam.y, 0xff000000, 0)
    end
  end
end

class Bell < SBGameObject
  def initialize(x, y, args, section)
    super x, y, 32, 56, :sprite_bell, Vector.new(-16, 0), 1, 5
    @img_index = 2
  end

  def update(section)
    if @active
      animate(@timer >= 180 ? [1, 2, 3, 2] : [1, 0, 1, 2, 3, 4, 3, 2], 10)
      @timer += 1
      if @timer == 180
        set_animation 1
      elsif @timer == 360
        @active = false
        set_animation 2
      end
    elsif SB.player.bomb.collide?(self)
      SB.stage.stop_time(360, false)
      SB.play_sound(Res.sound(:bell))
      @active = true
      set_animation 1
      @timer = 0
    end
  end
end

class ThornyPlant < TwoStateObject
  def initialize(x, y, args, section)
    a = (args || '').split(',')
    @tiles_x = (a[0] || 1).to_i
    @tiles_y = a[1] && !a[1].empty? ? a[1].to_i : 1
    super(x, y, @tiles_x * C::TILE_SIZE, @tiles_y * C::TILE_SIZE, :sprite_thornyPlant, Vector.new(0, 0), 3, 1,
          105, 0, 5, [0], [2], [1, 2], [1, 0], !a[2].nil?, 45, a[2] ? 30 : 0)
  end

  def update(section)
    super(section)
    SB.player.bomb.hit if @state2 && SB.player.bomb.collide?(self)
  end

  def s1_to_s2(section); end
  def s2_to_s1(section); end

  def is_visible(map)
    true
  end

  def draw(map, section)
    (0...@tiles_x).each do |i|
      (0...@tiles_y.to_i).each do |j|
        @img[@img_index].draw(@x + i * C::TILE_SIZE - map.cam.x, @y + j * C::TILE_SIZE - map.cam.y, 0, 2, 2)
      end
    end
  end
end

class Nest < SBGameObject
  MIN_INTERVAL = 180
  MAX_INTERVAL = 300

  def initialize(x, y, args, section)
    super(x - 18, y, 68, 32, :sprite_Nest, Vector.new(-14, -14))
    section.obstacles << self
    @timer = 0
    @next_spawn = rand(MIN_INTERVAL..MAX_INTERVAL)
  end

  def update(section)
    if SB.player.bomb.explode?(self) || section.explode?(self)
      unless @dead
        section.obstacles.delete(self)
        section.add_effect(Effect.new(@x + 18, @y, :fx_WallCrack3, 2, 2, 10))
        section.add_effect(Effect.new(@x, @y + 12, :fx_WallCrack3, 2, 2, 10))
        section.add_effect(Effect.new(@x + 36, @y + 12, :fx_WallCrack3, 2, 2, 10))
        @dead = true
      end
    else
      @timer += 1
      if @timer >= @next_spawn
        unless section.element_at(Zingz, @x + @w / 2, @y)
          section.add(Zingz.new(@x + @w / 2 - 25, @y - 15, nil, section))
          section.add_effect(Effect.new(@x + @w / 2 - 32, @y - 32, :fx_spawn, 2, 2, 6))
        end
        @timer = 0
        @next_spawn = rand(MIN_INTERVAL..MAX_INTERVAL)
      end
    end
  end
end

class StickyFloor
  attr_reader :bounds

  def initialize(x, y, args, section)
    @bounds = Rectangle.new(x, y + C::TILE_SIZE - 1, C::TILE_SIZE, 1)
  end

  def update(section)
    b = SB.player.bomb
    b.sticking = true if b.collide?(self)
  end

  def is_visible(map)
    map.cam.intersect?(@bounds)
  end

  def dead?
    false
  end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    Res.img('editor_el_107-StickyFloor').draw(@bounds.x - map.cam.x, @bounds.y - 15 - map.cam.y, 0, 2, 2) if SB.state == :editor
  end
end

class Aldan < SBGameObject
  include Speech

  def initialize(x, y, args, section)
    if SB.player.has_bomb?(:branca)
      @dead = true
    else
      t_s = C::TILE_SIZE
      super(x - 5 * t_s, y - 9 * t_s, 6 * t_s, 10 * t_s, :sprite_BombaBranca, Vector.new(0, 9 * t_s - 24), 6, 2)
      @blocking = true
      @timer = 0
      init_speech(:msg_aldan)
    end
  end

  def update(section)
    return if @dead

    if @speaking
      @timer += 1
      if @timer == 600 or SB.key_pressed?(:confirm)
        section.unset_fixed_camera
        @speaking = @blocking = false
      end
    else
      animate([0, 1], 8)
      if @blocking && SB.player.bomb.collide?(self)
        section.set_fixed_camera(@x + 5 * C::TILE_SIZE, @y + 9 * C::TILE_SIZE)
        @speaking = true
      end
    end
  end

  def draw(map, section)
    return if @dead

    super(map, section, 2, 2, 255, 0xffffff, nil, :horiz)
    draw_speech
  end
end

class ToxicDrop < SBGameObject
  def initialize(x, y, args, section)
    super(x, y - 4, 32, 16, :sprite_toxicDrop, Vector.new(0, 0), 2, 2)
    @fall_time = (args || 90).to_i
    @fall_time = 30 if @fall_time < 30
    @timer = 0
    @drops = []
  end

  def update(section)
    b = SB.player.bomb

    @drops.reverse_each do |drop|
      b.paralyze(30) if drop.bounds.intersect?(b.bounds)
      drop.move(Vector.new(0, 0), section.get_obstacles(drop.x, drop.y), section.ramps)
      @drops.delete(drop) if drop.bottom
    end

    b.paralyze(60) if b.collide?(self)

    @timer += 1
    if @timer == @fall_time + 15
      set_animation(0)
      @timer = 15
    elsif @timer == @fall_time
      drop = GameObject.new(@x + 14, @y + @h, 6, 10, :sprite_toxicDrop, Vector.new(-14, -@h), 2, 2)
      drop.instance_exec { @img_index = 3 }
      @drops << drop
    elsif @timer == @fall_time - 30
      set_animation(1)
    end

    animate([1, 2, 1], 15) if @timer >= @fall_time - 30
  end

  def draw(map, section)
    super
    @drops.each do |drop|
      drop.draw(map, 2, 2)
    end
  end
end

class SpikeBall < SBGameObject
  def initialize(x, y, args, section)
    super(x + 1, y + 1, 30, 30, :sprite_SpikeBall, Vector.new(-6, -6), 2, 1)
    @angle = 0
    case args
    when '2' then @h_speed = 4; @v_speed = -10; @g_scale = 0.7; @color = 0xffff80
    when '3' then @h_speed = 5; @v_speed = -18; @g_scale = 1.1; @color = 0xff4444
    else          @h_speed = 3; @v_speed = -10; @g_scale = 0.5; @color = 0x9999ff
    end
  end

  def update(section)
    # stop when section.set_fixed_camera is called
    return if SB.stage.stopped

    @angle += 1.5

    forces = Vector.new(0, 0)
    if @bottom
      forces.y = @v_speed
      forces.x = -@h_speed if @speed.x == 0
    elsif @left
      @speed.x = 0
      forces.x = @h_speed
    elsif @right
      @speed.x = 0
      forces.x = -@h_speed
    end
    prev_g = G.gravity.y
    G.gravity.y *= @g_scale
    move(forces, section.get_obstacles(@x, @y), section.ramps)
    G.gravity.y = prev_g

    update_active_bounds(section)

    if SB.player.bomb.collide?(self)
      SB.player.bomb.hit
    end
  end

  def draw(map, section)
    @img_index = 0
    super(map, section, 2, 2, 255, @color, @angle)
    @img_index = 1
    super(map, section, 2, 2, 255, 0xffffff, @angle)
  end
end

class SeekBomb < SBGameObject
  RANGE = 100
  SPEED = 3

  def initialize(x, y, args, section)
    super(x + 3, y + 3, 26, 26, :sprite_SeekBomb, Vector.new(-4, -4), 5, 1)
  end

  def update(section)
    b = SB.player.bomb
    b_c = Vector.new(b.x + b.w / 2, b.y + b.h / 2)
    c = Vector.new(@x + @w / 2, @y + @h / 2)
    distance = Math.sqrt((b_c.x - c.x)**2 + (b_c.y - c.y)**2)

    if b.collide?(self)
      b.hit
    end

    if @seeking
      speed = Vector.new((b_c.x - c.x).to_f * SPEED / distance, (b_c.y - c.y).to_f * SPEED / distance)
      move(speed, section.get_obstacles(@x, @y), section.ramps, true)
      animate([1, 0, 0, 0, 0, 0, 0, 0, 0, 0], 6)
      @timer += 1
      if @timer == 120
        @seeking = false
        @exploding = true
        @timer = 0
      end
    elsif @exploding
      @timer += 1
      if @timer == 60
        @dead = true
      elsif @timer == 30
        section.add_effect(Explosion.new(c.x, c.y, 90, self))
        set_animation(2)
      end
      if @timer >= 30
        animate([2, 3, 4], 10)
      else
        animate([0, 1], 3)
      end
    elsif distance <= RANGE
      @seeking = true
      set_animation(1)
      @timer = 0
    end
  end

  def is_visible(map)
    @seeking || @exploding || map.cam.intersect?(@active_bounds)
  end
end

class Gate < SBGameObject
  HEIGHT = 5 * C::TILE_SIZE - 10

  attr_reader :id

  def initialize(x, y, args, section, switch)
    a = (args || '').split(',')
    @id = a[0].to_i
    @close_time = (a[1] || 180).to_i
    @close_time = 1 if @close_time == 0
    @normal = a[2].nil?
    @first = a[3].nil?
    @opened = switch[:state] == :taken
    super(x + 6, y, 20, (@normal || !@first) && !@opened ? 14 + HEIGHT : 14, :sprite_gate, Vector.new(0, 0), 2, 1)
  end

  def update(section)
    unless @inited
      section.obstacles << self
      @inited = true
    end

    # stop unless when section.set_fixed_camera is called by self
    return if SB.stage.stopped && section.active_object != self || @opened

    b = SB.player.bomb

    if @active
      if @normal
        @timer += 1
        if @timer == 60 + @close_time
          @h = 14 + HEIGHT
          @active = false
          if @timer <= 90
            section.unset_fixed_camera
            section.active_object = nil
          end
        elsif @timer > 60
          @h = 14 + ((@timer - 60).to_f / @close_time) * HEIGHT
          if @timer == 90
            section.unset_fixed_camera
            section.active_object = nil
          end
        else
          @h = 14 + ((60 - @timer).to_f / 60) * HEIGHT
        end
        if b.bounds.intersect?(@active_bounds) && @y + @h > b.y
          if b.bottom
            b.hit(999, true)
          else
            b.y = @y + @h
          end
        end
      else
        if @timer < 0
          @timer += 1
          @h = 14 + ((60 + @timer).to_f / 60) * HEIGHT
          if @timer == 0
            @h = 14 + HEIGHT
            @active = false
            section.unset_fixed_camera
            section.active_object = nil
          end
        else
          @timer += 1
          if @timer <= 60
            @h = 14 + ((60 - @timer).to_f / 60) * HEIGHT
          elsif @timer == 90
            @active = false
            @opened = true
            section.unset_fixed_camera
            section.active_object = nil
          end
        end
      end
    end

    unless @normal
      collide = b.bounds.intersect?(@active_bounds)
      if @prev_collide && !collide && b.x > @x
        @active = true
        @timer = -60
        section.active_object = self
        section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
      end
      @prev_collide = collide
    end
  end

  def activate(section, arg = nil)
    return if @active
    @active = true
    @timer = 0
    section.active_object = self
    section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
    SB.play_sound(Res.sound(:gate))
    SB.stage.set_switch(self) unless @normal
  end

  def draw(map, section)
    super(map)
    sub_h = ((@h - 14).to_f / HEIGHT * (@img[1].height - 7)).round
    if sub_h > 0
      sub_y = @img[1].height - sub_h
      @img[1].subimage(0, sub_y, 10, sub_h).draw(@x - map.cam.x, @y + 14 - map.cam.y, 0, 2, 2)
    end
  end

  def is_visible(map)
    @active || map.cam.intersect?(@active_bounds)
  end

  def stop_time_immune?
    true
  end
end

class BattleArena
  def initialize(x, y, args, section, switch)
    @x = x
    @y = y

    if switch[:state] == :taken
      @dead = true
      return
    end

    args = (args || '').split(':')
    @gate_ids = args[0..1].map(&:to_i)
    @enemies = []
    return if args.size < 3
    args[2..-1].each do |a|
      next if a.nil? || a.empty?
      p = a.split(',').map(&:to_i)
      next if p[0].nil? || p[0] == 0
      @enemies << Section::ELEMENT_TYPES[p[0]].new((p[1] || 0) * C::TILE_SIZE, (p[2] || 0) * C::TILE_SIZE, nil, section)
    end
  end

  def update(section)
    return if @dead

    if @timer.nil?
      @enemies.each { |e| section.add(e) }
      @timer = 0
    end

    if @enemies.empty?
      if @timer == 0
        section.activate_object(Gate, @gate_ids[0])
        SB.stage.set_switch(self)
      end
      @timer += 1
      if @timer == 91
        section.activate_object(Gate, @gate_ids[1])
        @dead = true
      end
    else
      @enemies.reverse_each do |e|
        @enemies.delete(e) if e.dead?
      end
    end
  end

  def is_visible(map)
    true
  end

  def dead?; @dead; end

  def stop_time_immune?
    true
  end

  def draw(map, section)
    Res.img('editor_el_124-BattleArena').draw(@x - map.cam.x, @y - map.cam.y, 0, 2, 2) if SB.state == :editor
  end

  def self.parse_args(args)
    args = (args || '').split(':')
    result = [args[0].to_s, args[1].to_s]
    return result if args.size < 3
    args[2..-1].each do |a|
      p = a.split(',')
      result << p[0]
      result << (p[1] && p[2] ? "#{p[1]},#{p[2]}" : '')
    end
    result
  end
end

class SpecPlatform < SBGameObject
  def initialize(x, y, args, section)
    unless SB.player.specs.size == C::TOTAL_SPECS
      @dead = true
      return
    end
    super(x, y + 32, 64, 1, :sprite_specPlatform, Vector.new(0, -32))
    @passable = true
    @alpha = 255
    section.obstacles << self
  end

  def update(section)
    if @alpha > 125
      @alpha -= 5
      if @alpha == 125
        @alpha = -125
      end
    elsif @alpha < 0
      @alpha -= 5
      if @alpha == -255
        @alpha = 255
      end
    end
  end

  def draw(map, section)
    super(map, section, 2, 2, @alpha.abs)
  end
end

class SpecGate < SBGameObject
  class WarpEffect < Effect
    def draw(map = nil, scale_x = 1, scale_y = 1, alpha = 0xff, color = 0xffffff, angle = nil, z_index = 0)
      super(map, 4, 4)
    end
  end

  def initialize(x, y, args, section)
    super x - 96, y - 124, 224, 156, :sprite_SpecGate, Vector.new(0, 0), 2, 4
    @bg = Res.img(:sprite_specGateBg)
    @portal = Res.imgs(:sprite_graphic2, 2, 2)
    @open = @angle = @portal_index = @timer = @timer2 = 0
  end

  def update(section)
    b = SB.player.bomb
    if @open == 0
      if b.x + b.w > @x - 96 && @x + @w + 96 > b.x && b.y + b.h == @y + @h
        @open = 1
        section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
      end
    else
      @angle += 5
      @angle = 0 if @angle == 360

      @timer += 1
      if @timer == 7
        @portal_index = (@portal_index + 1) % 4
        @timer = 0
      end

      if @open == 1
        @timer2 += 1
        SB.play_sound(Res.sound(:wallOpen)) if @timer2 % 30 == 0 && @timer2 < 240
        animate_once([0, 1, 2, 3, 4, 5, 6, 7], 30) do
          @open = 2
          @timer2 = 0
          section.unset_fixed_camera
        end
      elsif @open == 2
        if b.collide?(self)
          b.stop
          b.active = false
          @aim = Vector.new(@x + (@w - b.w) / 2, @y + (@h - b.h) / 2 + 12)
          @open = 3
          @timer2 = 0
        end
      else
        b.move_free(@aim, 4) if @timer2 < 30
        @timer2 += 1
        if @timer2 == 30
          section.add_effect(WarpEffect.new(@x + @w / 2 - 60, @y + @h / 2 - 48, :fx_transport, 2, 2, 7, [0, 1, 2, 3], 28))
          SB.open_special_world
        end
      end
    end
  end

  def draw(map, section)
    @bg.draw(@x - map.cam.x, @y - map.cam.y, 0, 2, 2)
    @portal[@portal_index].draw_rot(@x + @w / 2 - map.cam.x, @y + @h / 2 + 12 - map.cam.y, 0, @angle, 0.5, 0.5, 4, 4)
    super(map, section)
  end

  def stop_time_immune?
    true
  end
end

class Fog
  attr_reader :x, :y, :w, :h

  def initialize(i, j, tiles)
    @x = i * C::TILE_SIZE
    @y = j * C::TILE_SIZE
    @w = C::TILE_SIZE
    @h = C::TILE_SIZE
    @img = Res.imgs(:sprite_fog, 4, 4)
    @active_bounds = Rectangle.new(@x, @y, @w, @h)
    up = j > 0 && tiles[i][j - 1].hide && tiles[i][j - 1].hide >= 99
    rt = tiles[i + 1] && tiles[i + 1][j].hide && tiles[i + 1][j].hide >= 99
    dn = tiles[i][j + 1] && tiles[i][j + 1].hide && tiles[i][j + 1].hide >= 99
    lf = i > 0 && tiles[i - 1][j].hide && tiles[i - 1][j].hide >= 99
    dr = rt && dn && tiles[i + 1][j + 1].hide && tiles[i + 1][j + 1].hide >= 99
    @img_index = if up
                   if rt
                     if dn
                       if lf
                         10
                       else
                         12
                       end
                     elsif lf
                       13
                     else
                       4
                     end
                   elsif dn
                     if lf
                       14
                     else
                       3
                     end
                   elsif lf
                     5
                   else
                     6
                   end
                 elsif rt
                   if dn
                     if lf
                       15
                     else
                       0
                     end
                   elsif lf
                     7
                   else
                     8
                   end
                 elsif dn
                   if lf
                     1
                   else
                     2
                   end
                 elsif lf
                   9
                 end
    @draw_fill = rt && dn && dr
    @alpha = 255
    @timer = 0
    tiles[i][j].hide = 100
  end

  def update(section)
    @timer += 1
    if @timer == 240
      @timer = 0
    end
    @alpha = (255 - (@timer < 120 ? @timer : 240 - @timer) * 0.6).round
  end

  def is_visible(map); true; end

  def draw(map)
    return unless map.cam.intersect?(@active_bounds)
    color = (@alpha << 24) | 0xffffff
    @img[@img_index].draw(@x - map.cam.x, @y - map.cam.y, 0, 2, 2, color)
    @img[11].draw(@x + 16 - map.cam.x, @y + 16 - map.cam.y, 0, 2, 2, color) if @draw_fill
  end
end

class Explosion < Effect
  attr_reader :c_x, :c_y, :radius, :owner

  def initialize(x, y, radius, owner)
    super x - radius - 10, y - radius - 10, :fx_Explosion, 2, 2, 5, [0, 1, 2, 3], 60, :explode, '.wav', SB.sound_volume * 0.1
    size = 2 * radius + 20
    @active_bounds = Rectangle.new(@x, @y, size, size)
    @scale = size / 90.0
    @c_x = x
    @c_y = y
    @radius = radius
    @owner = owner
  end

  def draw(map, scale_x, scale_y)
    super(map, @scale, @scale)
  end
end

class Ice < SBEffect
  def initialize(x, y)
    @w = @h = 30
    super x - @w/2, y - @h/2, :fx_ice, 2, 2, 5, nil, 120
  end

  def update
    super
    bounds = Rectangle.new(@x, @y, @w, @h)
    if bounds.intersect?(SB.player.bomb.bounds)
      SB.player.bomb.hit
    end
  end

  def move(x, y)
    @x = x - @w / 2
    @y = y - @h / 2
  end
end

class Fire < SBEffect
  def initialize(x, y, lifetime = 120)
    @w = 28; @h = 32
    super x - @w/2, y - @h, :fx_fire, 3, 1, 5, nil, lifetime
  end

  def update
    super
    bounds = Rectangle.new(@x, @y, @w, @h)
    if bounds.intersect?(SB.player.bomb.bounds)
      SB.player.bomb.hit
    end
  end
end

class Lightning < SBGameObject
  def initialize(x, y, section)
    tile_count = 0
    tile_count += 1 until section.obstacle_at?(x, y + tile_count * C::TILE_SIZE)
    y -= C::TILE_SIZE if tile_count.odd?
    @size = (tile_count + 1) / 2
    super(x - 10, y, 20, @size * 2 * C::TILE_SIZE, :fx_lightning, Vector.new(-6, 0), 3, 2)
    @active_bounds = Rectangle.new(@x - C::TILE_SIZE, @y, @w + 2 * C::TILE_SIZE, @h)
    @lifetime = 150
  end

  def update(section)
    animate(@lifetime > 90 ? [0, 1, 2] : [3, 4, 5], @lifetime > 90 ? 20 : 6)
    @lifetime -= 1
    @dead = true if @lifetime == 0
    if @lifetime <= 90 && bounds.intersect?(SB.player.bomb.bounds)
      SB.player.bomb.hit
    end
  end

  def draw(map, section)
    (0...@size).each do |i|
      @img[@img_index].draw(@x + @img_gap.x - map.cam.x, @y + i * 2 * C::TILE_SIZE - map.cam.y, 0, 2, 2)
      section.add_light_tiles([
        [0, 2 * i, 0], [0, 2 * i + 1, 0],
        [-1, 2 * i, 127], [-1, 2 * i + 1, 127],
        [1, 2 * i, 127], [1, 2 * i + 1, 127],
      ], @x, @y, @w, C::TILE_SIZE)
    end
  end
end

class Graphic < Sprite
  def initialize(x, y, args, section)
    type = args.to_i
    type = 1 if type == 0
    cols = 1; rows = 1
    img_index = nil
    @flip = nil
    case type
    when 1 then @w = 32; @h = 64
    when 2 then x += 16; y += 16; @w = 64; @h = 64; cols = 2; rows = 2; @indices = [0, 1, 2, 3]; @interval = 7; @rot = -5
    when 3..5 then x -= 16; @w = 64; @h = 32
    when 6 then x -= 134; y -= 208; @w = 300; @h = 240
    when 7..8 then @w = 128; @h = 64
    when 9 then x -= 16; @w = 160; @h = 64
    when 10 then x -= 236; y -= 416; @w = 600; @h = 480
    when 12
      x += 2; @w = 126; @h = 128; cols = 5; rows = 1
      if SB.player.has_bomb?(:vermelha)
        img_index = 4
      else
        @indices = [0, SB.lang == :portuguese ? 1 : SB.lang == :english ? 2 : 3]; @interval = 60
      end
    when 13..18 then x -= 64; y -= 88; @w = 160; @h = 120; cols = 1; rows = 3; img_index = SB.lang == :portuguese ? 1 : SB.lang == :english ? 0 : 2
    when 19..20 then x -= 64; y -= 88; @w = 160; @h = 120
    when 21..23 then x -= 14; @w = 60; @h = 32
    when 24 then x -= 64; y -= 88; @w = 160; @h = 120; cols = 1; rows = 2; img_index = SB.lang == :english ? 0 : 1
    when 25 then x -= 4; y -= 4; @w = 40; @h = 68
    when 26..27
      x += 2; @w = 126; @h = 128; cols = 5; rows = 1
      if SB.player.has_bomb?(type == 26 ? :amarela : :verde)
        img_index = 4
      else
        @indices = [0, SB.lang == :portuguese ? 1 : SB.lang == :english ? 2 : 3]; @interval = 60
      end
    when 28 then x -= 12; @w = 56; @h = 36
    when 29..32 then x -= 12; @w = 56; @h = 32
    when 33 then x -= 88; y -= 96; @w = 208; @h = 128
    when 34 then x -= 32; @w = 96; @h = 32
    when 35 then x -= 96; y -= 96; @w = @h = 224; cols = 3; rows = 1; @indices = [0, 1, 2]; @interval = 7; @move = 0
    end
    super x, y, "sprite_graphic#{type}", cols, rows
    @img_index = img_index if img_index
    @active_bounds = Rectangle.new(@x, @y, @w, @h)
    @angle = 0 if @rot
    @timer = 0 if @move
  end

  def update(section)
    animate @indices, @interval if @indices
    @angle += @rot if @rot
    if @move
      @timer += 1
      if @timer == 10
        case @move
        when 0 then @y -= 3
        when 1..2 then @y -= 2
        when 3..4 then @y -= 1
        when 5..6 then @y += 1
        when 7..8 then @y += 2
        when 9..10 then @y += 3
        when 11..12 then @y += 2
        when 13..14 then @y += 1
        when 15..16 then @y -= 1
        when 17..18 then @y -= 2
        when 19 then @y -= 3
        end
        @move += 1
        @move = 0 if @move == 20
        @timer = 0
      end
    end
  end

  def draw(map, section)
    @rot ?
      (@img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h/2 - map.cam.y, -1, @angle, 0.5, 0.5, 2, 2) :
      super(map, 2, 2, 255, 0xffffff, nil, @flip, -1)
  end

  def is_visible(map)
    map.cam.intersect? @active_bounds
  end

  def dead?
    false
  end

  def stop_time_immune?
    false
  end
end
