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

  def draw(map, scale_x = 2, scale_y = 2, alpha = 0xff, color = 0xffffff, angle = nil, flip = nil, z_index = 0, round = false)
    super(map, scale_x, scale_y, alpha, color, angle, flip, z_index, round)
  end
end

class TwoStateObject < SBGameObject
  def initialize(x, y, w, h, img, img_gap, sprite_cols, sprite_rows,
    change_interval, anim_interval, change_anim_interval, s1_indices, s2_indices, s1_s2_indices, s2_s1_indices, s2_first = false)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows

    @timer = 0
    @changing = false
    @change_interval = change_interval
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
    if @timer == @change_interval
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
          set_animation @s1_s2_indices[-2]
          @changing = false
        end
      else
        animate @s2_s1_indices, @change_anim_interval
        if @img_index == @s2_s1_indices[-1]
          set_animation @s2_s1_indices[-2]
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
    super map, 2, 2
  end
end

module Speech
  def init_speech(msg_id)
    @speaking = false
    @msg = SB.text(msg_id.to_sym).split('/')
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
    section.active_object = self if @active
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

class Goal < SBGameObject
  def initialize(x, y, args, section)
    super x - 4, y - 118, 40, 150, :sprite_goal1, nil, 4, 1
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

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    @balloon.draw @x - map.cam.x + 16, @y - map.cam.y - 32, 0, 2, 2 if @active
    draw_speech
  end
end

class Door < GameObject
  attr_reader :locked, :type

  def initialize(x, y, args, section, switch)
    args = args.split(',')
    type = args[2]
    case type
    when nil then x_g = -10; y_g = -63
    else          x_g = -19; y_g = -89
    end
    super x + 10, y + 63, 12, 1, "sprite_Door#{type}", Vector.new(x_g, y_g), 5, 1
    @entrance = args[0].to_i
    @locked = (switch[:state] != :taken and args[1] == '.')
    @type = type.to_i if type
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
    if not @locked and not @opening and collide
      if SB.key_pressed? :up
        set_animation 1
        @opening = true
      end
    end
    if @opening
      animate [1, 2, 3, 4, 0], 5
      if @img_index == 0
        section.warp = @entrance
        @opening = false
      end
    end
  end

  def unlock(section)
    @locked = false
    @lock = nil
    section.active_object = nil
    SB.stage.set_switch self
  end

  def draw(map)
    super map, 2, 2
    @lock.draw(@x + 9 - map.cam.x, @y - 38 - map.cam.y, 0, 2, 2) if @lock
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
    if b.collide? self and not b.will_explode
      b.set_exploding(@life)
      SB.stage.set_switch self if @switch
      @dead = true
    end
  end

  def draw(map)
    super(map, 2, 2, 255, @color)
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
      section.add_effect(Effect.new(@x, @y, "fx_WallCrack#{@type}", 2, 2))
      SB.stage.set_switch self
      @dead = true
    end
  end
end

class Elevator < SBGameObject
  attr_reader :id

  def initialize(x, y, args, section)
    a = args.split(':')
    type = a[0].to_i
    open = a[0][-1] == '!'
    case type
    when 1 then w = 32; cols = rows = nil; x_g = y_g = 0
    when 2 then w = 64; cols = 4; rows = 1; x_g = y_g = 0
    when 3 then w = 64; cols = rows = nil; x_g = 0; y_g = -3
    when 4 then w = 64; cols = rows = nil; x_g = y_g = 0
    end
    super x, y, w, 1, "sprite_Elevator#{type}", Vector.new(x_g, y_g), cols, rows
    @passable = true

    @speed_m = a[1].to_i
    @moving = false
    @points = []
    min_x = x; min_y = y
    max_x = x; max_y = y

    if a[2].index(',')
      @stop_time = 30
      ps = a[2..-1]
    else
      @stop_time = a[2].to_i
      ps = a[3..-1]
    end

    ps.each do |p|
      coords = p.split ','
      p_x = coords[0].to_i * C::TILE_SIZE; p_y = coords[1].to_i * C::TILE_SIZE

      min_x = p_x if p_x < min_x
      min_y = p_y if p_y < min_y
      max_x = p_x if p_x > max_x
      max_y = p_y if p_y > max_y

      @points << Vector.new(p_x, p_y)
    end
    if open
      (@points.length - 2).downto(0) do |i|
        @points << @points[i]
      end
    end
    @points << Vector.new(x, y)
    @indices = *(0...@img.size)
    @active_bounds = Rectangle.new min_x, min_y, (max_x - min_x + w), (max_y - min_y + @img[0].height)
    @active = a[1][-1] != ")"
    @id = a[1].split('(')[1].to_i unless @active

    section.obstacles << self
  end

  def update(section)
    if @active
      b = SB.player.bomb
      cycle @points, @speed_m, section.passengers, section.get_obstacles(b.x, b.y), section.ramps, @stop_time
    end
    animate @indices, 8
  end

  def activate
    @active = !@active
  end

  def is_visible(map)
    true
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
    if not @saved and SB.player.bomb.collide? self
      section.save_check_point @id, self
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
      60, 0, 3, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4], (not args.nil?)

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
    if @dir % 2 == 0
      x += 2; w = 28; h = 34
      y -= 2 if @dir == 2
    else
      y += 2; w = 34; h = 28
      x -= 2 if @dir == 1
    end
    super x, y, w, h, "sprite_Spikes#{a[1]}", Vector.new(0, 0), 5, 1, 150, 0, 2, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4]
    @active_bounds = Rectangle.new x, y, 32, 32
    @obst = Block.new(x + 2, y + 2, 28, 28)
  end

  def s1_to_s2(section)
    if SB.player.bomb.collide? @obst
      SB.player.bomb.hit
    else
      section.obstacles << @obst
    end
  end

  def s2_to_s1(section)
    section.obstacles.delete @obst
  end

  def update(section)
    super section

    b = SB.player.bomb
    if @state2 and b.collide? self
      if (@dir == 0 and b.y + b.h <= @y + 2) or
         (@dir == 1 and b.x >= @x + @w - 2) or
         (@dir == 2 and b.y >= @y + @h - 2) or
         (@dir == 3 and b.x + b.w <= @x + 2)
        SB.player.bomb.hit
      end
    end
  end

  def is_visible(map)
    true
  end

  def draw(map)
    angle = case @dir
            when 0 then 0
            when 1 then 90
            when 2 then 180
            else        270
            end
    @img[@img_index].draw_rot @x + @w/2 - map.cam.x, @y + @h/2 - map.cam.y, 0, angle, 0.5, 0.5, 2, 2
  end
end

class FixedSpikes < GameObject
  def initialize(x, y, args, section)
    a = args ? args.split(',') : [0, 1]
    @dir = a[0].to_i
    type = a[1] || '1'
    if @dir % 2 == 0
      super x + 2, @dir == 2 ? y - 2 : y, 28, 34, "sprite_fixedSpikes#{type}", Vector.new(0, 0), 1, 1
    else
      super @dir == 1 ? x - 2 : x, y + 2, 34, 28, "sprite_fixedSpikes#{type}", Vector.new(0, 0), 1, 1
    end
    @active_bounds = Rectangle.new x - 2, y - 2, 36, 36
    section.obstacles << Block.new(x + 2, y + 2, 28, 28)
  end

  def update(section)
    b = SB.player.bomb
    if b.collide? self
      if (@dir == 0 and b.y + b.h <= @y + 2) or
         (@dir == 1 and b.x >= @x + @w - 2) or
         (@dir == 2 and b.y >= @y + @h - 2) or
         (@dir == 3 and b.x + b.w <= @x + 2)
        SB.player.bomb.hit
      end
    end
  end

  def draw(map)
    angle = case @dir
            when 0 then 0
            when 1 then 90
            when 2 then 180
            else        270
            end
    @img[0].draw_rot @x + @w/2 - map.cam.x, @y + @h/2 - map.cam.y, 0, angle, 0.5, 0.5, 2, 2
  end
end

class MovingWall < GameObject
  attr_reader :id

  def initialize(x, y, args, section)
    super x + 2, y + C::TILE_SIZE, 28, 0, :sprite_MovingWall, Vector.new(0, 0), 1, 2
    args = args.split ','
    @id = args[0].to_i
    @closed = args[1].nil?
    if @closed
      until section.obstacle_at? @x, @y - 1
        @y -= C::TILE_SIZE
        @h += C::TILE_SIZE
      end
    else
      @max_size = C::TILE_SIZE * args[1].to_i
    end
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.obstacles << self
  end

  def update(section)
    if @active
      @timer += 1
      if @timer == 30
        @y += @closed ? 16 : -16
        @h += @closed ? -16 : 16
        @active_bounds = Rectangle.new @x, @y, @w, @h
        @timer = 0
        if @closed and @h == 0
          @dead = true
        elsif not @closed and @h == @max_size
          @active = false
        end
      end
    end
  end

  def activate
    @active = true
    @timer = 0
  end

  def draw(map)
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
    super x, y, 32, 32, :sprite_Ball
    @set = switch[:state] == :taken
    @start_x = x
    @rotation = 0
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.passengers << self
  end

  def update(section)
    if @set
      if @rec.nil?
        @rec = section.get_next_ball_receptor
        @x = @active_bounds.x = @rec.x
        @y = @active_bounds.y = @rec.y - 31
      end
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

        SB.stage.switches.each do |s|
          if s[:type] == BallReceptor and bounds.intersect? s[:obj].bounds
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
      move forces, section.get_obstacles(@x, @y), section.ramps

      @active_bounds = Rectangle.new @x, @y, @w, @h
      @rotation = 3 * (@x - @start_x)
    end
  end

  def draw(map)
    @img[0].draw_rot @x + (@w / 2) - map.cam.x, @y + (@h / 2) - map.cam.y, 0, @rotation, 0.5, 0.5, 2, 2
  end
end

class BallReceptor < SBGameObject
  attr_reader :id, :is_set

  def initialize(x, y, args, section, switch)
    super x, y + 31, 32, 1, :sprite_BallReceptor, Vector.new(0, -8), 1, 2
    @id = args.to_i
    @will_set = switch[:state] == :taken
    @active_bounds = Rectangle.new x, y + 23, 32, 13
  end

  def update(section)
    if @will_set
      section.activate_object MovingWall, @id
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
    return tiles[i][j].wall if tiles[i][j].hide < 0
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

  def draw(map)
    @points.each do |p|
      @img[p[:img]].draw p[:x] - map.cam.x, p[:y] - map.cam.y, 0, 2, 2, @color
    end
  end
end

class Projectile < GameObject
  attr_reader :owner

  def initialize(x, y, type, angle, owner)
    case type
    when 1 then w = 20; h = 12; x_g = -2; y_g = -1; cols = 1; rows = 1; indices = [0]; @speed_m = 4.5
    when 2 then w = 8; h = 8; x_g = -2; y_g = -2; cols = 2; rows = 2; indices = [0, 1, 2, 3]; @speed_m = 2.5
    when 3 then w = 4; h = 40; x_g = 0; y_g = 0; cols = 1; rows = 1; indices = [0]; @speed_m = 6
    when 4 then w = 16; h = 22; x_g = -2; y_g = 0; cols = 1; rows = 1; indices = [0]; @speed_m = 5
    when 5 then w = 20; h = 20; x_g = -16; y_g = -4; cols = 1; rows = 2; indices = [0, 1]; @speed_m = 5
    when 6 then w = 10; h = 10; x_g = -2; y_g = 0; cols = 2; rows = 2; indices = [0, 1, 2, 3]; @speed_m = 4
    when 7 then w = 16; h = 16; x_g = -2; y_g = -2; cols = 1; rows = 1; indices = [0]; @speed_m = 5
    end

    super x, y, w, h, "sprite_Projectile#{type}", Vector.new(x_g, y_g), cols, rows
    @active_bounds = Rectangle.new @x - 30, @y - 30, @w + 60, @h + 60
    @angle = angle
    @owner = owner
    @indices = indices
    @visible = true
    @timer = 0
  end

  def update(section)
    move_free(@angle, @speed_m)

    obst = section.get_obstacles(@x, @y)
    obst.each do |o|
      if o.bounds.intersect?(self)
        @dead = true
        break
      end
    end
    return if @dead

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

  def draw(map)
    @img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h / 2 - map.cam.y, 0, @angle, 0.5, 0.5, 2, 2
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
    @entrance = args.to_i
  end

  def update(section)
    animate [0, 1, 2, 3, 2, 1], 5
    @angle += 5
    @angle = 0 if @angle == 360

    b = SB.player.bomb
    if @transporting
      b.move_free @aim, 1.5
      @timer += 1
      if @timer == 32
        section.add_effect(Effect.new(@x - 3, @y - 3, :fx_transport, 2, 2, 7, [0, 1, 2, 3], 28))
      elsif @timer == 60
        section.warp = @entrance
        @transporting = false
        b.active = true
      end
    else
      if b.collide? self
        b.active = false
        @aim = Vector.new(@x + (@w - b.w) / 2, @y + (@h - b.h) / 2 + 3)
        @transporting = true
        @timer = 0
      end
    end
  end

  def draw(map)
    @img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h/2 - map.cam.y, 0, @angle, 0.5, 0.5, 2, 2
  end
end

class AirMattress < GameObject
  def initialize(x, y, args, section)
    super x + 2, y + 16, 60, 1, :sprite_airMattress, Vector.new(-2, -2), 1, 3
    @active_bounds = Rectangle.new(x, y + 15, 64, 32)
    @color = (args || 'ffffff').to_i(16)
    @timer = 0
    @points = [
      Vector.new(@x, @y),
      Vector.new(@x, @y + 16)
    ]
    @speed_m = 0.16
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
        move_carrying Vector.new(@x, @y + 1), 0.3, [b], section.get_obstacles(b.x, b.y), section.ramps
      else
        @state = :up
        set_animation 2
      end
    elsif @state == :up
      animate [2, 1, 0], 8 if @img_index != 0
      move_carrying Vector.new(@x, @y - 1), 0.3, [b], section.get_obstacles(b.x, b.y), section.ramps
      if SB.player.bomb.bottom == self
        @state = :down
      elsif @y.round == @points[0].y
        @y = @points[0].y
        @state = :normal
      end
    end
  end

  def draw(map)
    super map, 2, 2, 255, @color
  end
end

class Branch < GameObject
  def initialize(x, y, args, section)
    a = args ? args.split(',') : []
    @scale = a[0] ? a[0].to_i : 2
    super x, y, @scale * C::TILE_SIZE, 1, :sprite_branch, Vector.new(0, 0)
    @passable = true
    @active_bounds = Rectangle.new(@x, @y, @w, @img[0].height)
    @left = a[1].nil?
    section.obstacles << self
  end

  def update(section); end

  def draw(map)
    super(map, @scale, 2, 255, 0xffffff, nil, @left ? nil : :horiz)
  end
end

class Water
  attr_reader :x, :y, :w, :h, :bounds

  def initialize(x, y, args, section)
    a = args.split ':'
    @x = x
    @y = y + 5
    @w = C::TILE_SIZE * a[0].to_i
    @h = C::TILE_SIZE * a[1].to_i - 5
    @bounds = Rectangle.new(@x, @y, @w, @h)
    section.add_interacting_element(self)
  end

  def update(section)
    b = SB.player.bomb
    if b.collide? self
      b.stored_forces.y -= 1
      unless SB.player.dead?
        SB.player.die
        section.add_effect(Effect.new(b.x + b.w / 2 - 32, @y - 19, :fx_water, 1, 4, 8))
      end
    end
  end

  def dead?
    false
  end

  def is_visible(map)
    map.cam.intersect? @bounds
  end

  def draw(map); end
end

class ForceField < GameObject
  def initialize(x, y, args, section, switch)
    return if switch[:state] == :taken
    super x, y, 32, 32, :sprite_ForceField, Vector.new(-14, -14), 3, 1
    @active_bounds = Rectangle.new(x - 14, y - 14, 60, 60)
    @alpha = 255
  end

  def update(section)
    animate [0, 1, 2, 1], 10
    b = SB.player.bomb
    if @taken
      @x = b.x + b.w / 2 - 16; @y = b.y + b.h / 2 - 16
      @timer += 1
      @dead = true if @timer == 1200
      if @timer >= 1080
        if @timer % 5 == 0
          @alpha = @alpha == 0 ? 255 : 0
        end
      end
    elsif b.collide? self
      b.set_invulnerable 1200
      SB.stage.set_switch self
      @taken = true
      @timer = 0
    end
  end

  def draw(map)
    super map, 2, 2, @alpha
  end
end

class Stalactite < SBGameObject
  def initialize(x, y, args, section)
    super x + 11, y - 16, 10, 48, :sprite_stalactite, Vector.new(-9, 0), 3, 2
    @active_bounds = Rectangle.new(x + 2, y, 28, 48)
    @normal = args.nil?
  end

  def update(section)
    if @dying
      animate [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 5], 5
      @timer += 1
      @dead = true if @timer == 60
    elsif @moving
      move Vector.new(0, 0), section.get_obstacles(@x, @y), section.ramps
      SB.player.bomb.hit if SB.player.bomb.collide?(self)
      obj = section.active_object
      if obj.is_a? Sahiss and obj.bounds.intersect?(self)
        obj.hit(section)
      end
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
      if (@normal && b.x + b.w > @x - 80 && b.x < @x + 90 && b.y > @y && b.y < @y + 256) ||
         (!@normal && b.x + b.w > @x && b.x < @x + @w && b.y + b.h > @y - C::TILE_SIZE && b.y + b.h < @y)
        @will_move = true
        @timer = 0
      end
    end
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

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? nil : :horiz)
  end
end

class Rock < SBGameObject
  def initialize(x, y, args, section)
    case args
    when '1' then
      objs = [['l', 0, 0, 26, 96], [26, 0, 32, 96], [58, 27, 31, 69], ['r', 89, 27, 18, 35], [89, 62, 30, 34]]
      w = 120; h = 96; x -= 44; y -= 64
    when '2' then
      objs = [[4, 54, 186, 42], [56, 26, 108, 28], [164, 46, 20, 8], ['l', 60, 0, 56, 26], ['r', 116, 0, 46, 26]]
      w = 192; h = 96; x -= 80; y -= 64
    else
      objs = []; w = h = 0
    end
    objs.each do |o|
      if o[0].is_a? String
        section.ramps << Ramp.new(x + o[1], y + o[2], o[3], o[4], o[0] == 'l')
      else
        section.obstacles << Block.new(x + o[0], y + o[1], o[2], o[3])
      end
    end
    super x, y, w, h, "sprite_rock#{args}", Vector.new(0, 0)
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
    @page = 0
  end

  def update(section)
    if @blocking
      b = SB.player.bomb
      if b.collide? self
        if @state == :normal
          section.set_fixed_camera(@x + @w / 2 - C::SCREEN_WIDTH / 2, @y + 50 - C::SCREEN_HEIGHT / 2)
          section.active_object = self
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
      else
        if section.active_object == self
          section.active_object = nil
          @state = :waiting
        end
      end
    end
    if @state == :speaking; animate [3, 4, 5, 4, 5, 3, 5], 10
    else; animate [0, 1, 0, 2], 10; end
    @speaking = @state == :speaking
  end

  def activate(section)
    @blocking = false
    @state = :normal
    section.active_object = nil
    SB.stage.set_switch(self)
  end

  def draw(map)
    super map, 2, 2
    @balloon.draw @x - map.cam.x, @y + 30 - map.cam.y, 0, 2, 2 if @state == :waiting and SB.player.bomb.collide?(self)
    draw_speech
  end
end

class StalactiteGenerator < SBGameObject
  def initialize(x, y, args, section)
    super x, y, 96, 32, :sprite_graphic11, Vector.new(0, -16)
    @active = true
    @limit = args.to_i * C::TILE_SIZE
  end

  def update(section)
    if @active and SB.player.bomb.collide?(self)
      section.add(Stalactite.new(@x + 96 + rand(@limit), @y + C::TILE_SIZE, '!', section))
      @active = false
      @timer = 0
    elsif not @active
      @timer += 1
      if @timer == 60
        @active = true
      end
    end
  end
end

class TwinWalls < GameObject
  attr_reader :id

  def initialize(x, y, args, section)
    super x + 2, y + C::TILE_SIZE, 28, 0, :sprite_MovingWall, Vector.new(0, 0), 1, 2
    args = args.split ','
    @id = args[0].to_i
    @closed = args[1] == '.'
    if @id != 0
      section.add(@twin = TwinWalls.new(C::TILE_SIZE * args[2].to_i, C::TILE_SIZE * args[3].to_i, "0,#{@closed ? '!' : '.'}", section))
    end

    if @closed
      until section.obstacle_at? @x, @y - 1
        @y -= C::TILE_SIZE
        @h += C::TILE_SIZE
      end
      @max_size = @h
    else
      @max_size = 0
      y = @y
      until section.obstacle_at? @x, y - 1
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
      if @timer == 30
        @y += @closed ? 16 : -16
        @h += @closed ? -16 : 16
        @active_bounds = Rectangle.new @x, @y, @w, @h
        @timer = 0
        if @closed && @h == 0 || !@closed && @h == @max_size
          @closed = !@closed
          @active = false
        end
      end
    end
  end

  def activate
    unless @active
      @active = true
      @timer = 0
      @twin.activate if @twin
    end
  end

  def draw(map)
    @img[0].draw @x - map.cam.x, @y - map.cam.y, 0 if @h > 0
    y = 16
    while y < @h
      @img[1].draw @x - map.cam.x, @y + y - map.cam.y, 0
      y += 16
    end
  end
end

class WallButton < SBGameObject
  def initialize(x, y, args, section)
    super x, y + 16, 32, 16, :sprite_WallButton, Vector.new(0, 0), 1, 3
    args = args.split ','
    @id = args[0].to_i
    @type =
      case args[1]
      when '1' then TwinWalls
      when '2' then Elevator
      else          nil
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
      else
        section.activate_object(TwinWalls, @id)
        section.activate_object(Elevator, @id)
      end
      @state = 1
      set_animation 1
    end
  end
end

class Lift < SBGameObject
  def initialize(x, y, args, section)
    super x, section.size.y, 64, 1, :sprite_Elevator2, Vector.new(0, 0), 4, 1
    @start = Vector.new(x, @y)
    args = args.split(',')
    @max_force = -(args[0].to_f)
    @x_force = args[1].to_f
    @passable = true
    @active_bounds = Rectangle.new(x, @y - 5 * C::TILE_SIZE, 64, 5 * C::TILE_SIZE)
    section.obstacles << self
  end

  def update(section)
    b = SB.player.bomb
    prev_max_speed = b.max_speed.x
    b.max_speed.x = @max_speed.x
    if @launched
      move_carrying(Vector.new(0, @force), nil, section.passengers, section.get_obstacles(b.x, b.y), section.ramps)
      @force += 1 if @force < 0
      @force = 0 if @force > 0
      if @y > section.size.y + C::TILE_SIZE
        @x = @start.x; @y = @start.y
        @speed.x = @speed.y = 0
        @launched = false
      end
    else
      move_carrying(Vector.new(@x_force, @max_force), nil, section.passengers, section.get_obstacles(b.x, b.y), section.ramps)
      @launched = true
      @force = @max_force * 0.25
    end
    b.max_speed.x = prev_max_speed

    # atualizando active_bounds
    t = (@y + @img_gap.y).floor
    r = (@x + @img_gap.x + @img[0].width).ceil
    b = (@y + @img_gap.y + @img[0].height).ceil
    l = (@x + @img_gap.x).floor
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

class Crusher < SBGameObject
  def initialize(x, y, args, section)
    super x, y, 32, 16, :sprite_Crusher, Vector.new(0, 0), 4, 1
    @bottom = Block.new(x, y + 144, 32, 16, false)
    @state = 0
    @timer = 0
    @active_bounds = Rectangle.new(x, y, 32, 160)
    section.obstacles << self << @bottom
  end

  def update(section)
    @timer += 1
    if @state % 2 == 0
      if @timer == 180
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
    b = SB.player.bomb
    if b.bottom == @bottom and @state == 2
      b.hit
    end
  end

  def grow(amount)
    amount = -amount if @state > 1
    @h += amount
    @bottom.instance_eval { @y -= amount; @h += amount }
    if SB.player.bomb.bottom == @bottom
      SB.player.bomb.y -= amount
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
  end

  def update(section)
    b = SB.player.bomb
    if @state == :waiting
      if b.x > @x + 100 && b.y > @y
        @state = :falling
      end
    else
      move(Vector.new(0, 0), section.get_obstacles(@x - 15, @y, 86, 86), section.ramps)
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

  def draw(map)
    super map, 2, 2, 255, 0xffffff, @x - @start_x
  end

  def is_visible(map)
    true
  end
end

class HeatBomb < SBGameObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_HeatBomb, Vector.new(0, 0), 4, 2
    @state = 0
    @passable = false
    section.obstacles << self
  end

  def update(section)
    if @state == 0
      animate [0, 1, 2, 1], 7
      if SB.player.bomb.explode?(self) or section.explode?(self)
        @state = 1
        @timer = 0
        set_animation 3
      end
    elsif @state == 1
      animate [3, 0], 3
      @timer += 1
      if @timer == 120
        @state = 2
        @timer = 0
        section.add_effect(Explosion.new(@x + @w / 2, @y + @h / 2, 48))
        set_animation 4
      end
    else
      animate [4, 5, 6, 7], 5
      @timer += 1
      if @timer == 20
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
    super x, y, 32, 32, "sprite_fragileFloor#{args}", Vector.new(0, 0), 4, 1
    @life = 60
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
  MOVE_SPEED = 2

  def initialize(x, y, args, section)
    super(x, y, 32, 32, :sprite_box, Vector.new(0, 0))
    section.obstacles << self
    @max_speed.x = 2
  end

  def update(section)
    b = SB.player.bomb
    obst = section.get_obstacles(@x, @y)
    if b.left == self && SB.key_down?(:left)
      move(Vector.new(-MOVE_SPEED, 0), obst, section.ramps)
      b.move(Vector.new(-MOVE_SPEED, 0), section.get_obstacles(b.x, b.y), section.ramps)
    elsif b.right == self && SB.key_down?(:right)
      move(Vector.new(MOVE_SPEED, 0), obst, section.ramps)
      b.move(Vector.new(MOVE_SPEED, 0), section.get_obstacles(b.x, b.y), section.ramps)
    else
      move(Vector.new(@bottom ? -@speed.x : 0, 0), obst, section.ramps)
    end
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

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    @balloon.draw @x - map.cam.x + 16, @y - map.cam.y - 32, 0, 2, 2 if @active
    draw_speech
  end
end

class WindMachine < SBGameObject
  FORCE = 30
  RANGE = 80 * C::TILE_SIZE

  def initialize(x, y, args, section, switch)
    super(x + 2, y + 12, 60, 20, :sprite_windMachine, Vector.new(-2, -4), 2, 3)
    @active = switch[:state] == :taken
    @rnd = Random.new
  end

  def update(section)
    if @active
      @timer += 1
      if @timer >= 30
        animate([2, 3, 4, 5], 5)

        section.add_effect(Effect.new(@x - 20 + @rnd.rand(@w + 40), @y - 120 - @rnd.rand(200), :fx_wind, 8, 1, 7)) if @timer % 10 == 0
      end

      b = SB.player.bomb
      if b.x + b.w > @x - 20 && @x + @w + 20 > b.x && b.y + b.h > @y - RANGE && b.y + b.h <= @y
        b.stored_forces.y -= FORCE * (1 - (@y - b.y - b.h) / RANGE)
      end
    end
  end

  def activate
    SB.stage.set_switch(self)
    @active = true
    @img_index = 1
    @timer = 0
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
      @moving = true if @timer == 30
    else
      if b.x + b.w > @x - 120 && b.x < @x + @w + 120 && b.y > @y && b.y < @y + 320
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

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, @to_left ? -90 : 90)
  end
end

class IcyFloor < SBGameObject
  def initialize(x, y, args, section)
    super(x, y + C::TILE_SIZE - 1, 32, 1, :fx_ice)
  end

  def update(section)
    b = SB.player.bomb
    b.slipping = true if b.collide?(self)
  end

  def draw(map); end
end

class Puzzle < SBGameObject
  def initialize(x, y, args, section, switch)
    super(x - 24, y - 46, 80, 78, :sprite_puzzle)
    @pieces = [nil, nil, nil, nil]
    @id = args.to_i
    @will_set = switch[:state] == :taken
  end

  def update(section)
    if @will_set
      seciton.activate_object(MovingWall, @id)
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
      SB.stage.set_switch(self)
      section.activate_object(MovingWall, @id)
      section.active_object = nil
    end
  end

  def draw(map)
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
  @@instance_counter = 0

  def initialize(x, y, args, section)
    @@player = false
    @@timer = 0
    super(x - 12, y - 12, 56, 56, :sprite_poisonGas, Vector.new(-2, -2), 3, 1)
    @index = (@@instance_counter += 1)
  end

  def update(section)
    animate([0, 1, 2], 7)

    @@player = true if SB.player.bomb.collide?(self)
    if @index == @@instance_counter
      if @@player
        @@timer += 1
        if @@timer == 180
          SB.player.bomb.hit
          @@timer = 0
        end
      else
        @@timer = 0
      end
    end
  end

  def draw(map)
    super(map)
    if @index == @@instance_counter
      SB.text_helper.write_line(((180 - @@timer).to_f / 60).ceil.to_s, 400, 250, :center, 0xffffff, 255, :border, 0, 1, 255, 1) if @@player && !SB.player.dead?
      @@player = false
    end
  end
end

class Cannon < SBGameObject
  ROT_SPEED = 3

  def initialize(x, y, args, section)
    super(x, y, 32, 32, :sprite_Cannon)
    @angles = args.split(',').map(&:to_i)
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
      @angle = (@angle + ROT_SPEED) % 360
      @rotating = false if @angle == @angles[@a_index]
    else
      section.add(Projectile.new(@x + @w / 2 - 8, @y + @h / 2 - 8, 7, @angle - 90, self)) if @timer == 0
      @timer += 1
      if @timer == 150
        @a_index += 1
        @a_index = 0 if @a_index >= @angles.length
        @rotating = true
        @timer = 0
      end
    end
  end

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, @angle)
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
    super(x, y + C::TILE_SIZE, 0, 0, :sprite_fallingWall, Vector.new(0, 0), 4, 2)
    size = args.to_i
    @active_bounds = Rectangle.new(x, y - (size - 1) * C::TILE_SIZE, C::TILE_SIZE, size * C::TILE_SIZE)
    @blocks = []
    (0...size).each do |i|
      b = MBlock.new(x, y - i * C::TILE_SIZE, C::TILE_SIZE, C::TILE_SIZE)
      section.obstacles << b; @blocks << b
    end
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
        b.x = @x + c_a * i * C::TILE_SIZE + c_c * RADIUS - C::TILE_SIZE / 2
        b.y = @y - s_a * i * C::TILE_SIZE - s_c * RADIUS - C::TILE_SIZE / 2
        p.hit if p.collide?(b)
      end
      @crashing = true if @angle == Math::PI
    elsif p.y > @y - @blocks.length * C::TILE_SIZE && p.y + p.h <= @y && p.x > @x - @blocks.length * C::TILE_SIZE && p.x < @x
      @blocks.each { |b| section.obstacles.delete(b) }
      @falling = true
    end
  end

  def draw(map)
    img_angle = -((@angle * 180 / Math::PI) - 90)
    x_off = C::TILE_SIZE / 2 - map.cam.x
    y_off = C::TILE_SIZE / 2 - map.cam.y
    @blocks.each_with_index do |b, i|
      @img[i == @blocks.size - 1 ? @img_index : @img_index + 4].draw_rot(b.x + x_off, b.y + y_off, 0, img_angle, 0.5, 0.5, 2, 2)
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
      @active = true
      set_animation 1
      @timer = 0
    end
  end
end

class Explosion < Effect
  attr_reader :c_x, :c_y, :radius

  def initialize(x, y, radius)
    super x - radius - 10, y - radius - 10, :fx_Explosion, 2, 2, 5, [0, 1, 2, 3], 60
    size = 2 * radius + 20
    @active_bounds = Rectangle.new(@x, @y, size, size)
    @scale = size / 180.0
    @radius = radius
    @c_x = x; @c_y = y
  end

  def draw(map)
    super map, @scale, @scale
  end
end

class Ice < SBEffect
  def initialize(x, y)
    @w = @h = 30
    super x - @w/2, y - @h/2, :fx_ice, 2, 2, 5, nil, 180
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
  def initialize(x, y)
    @w = 28; @h = 32
    super x - @w/2, y - @h, :fx_fire, 3, 1, 5, nil, 180
  end

  def update
    super
    bounds = Rectangle.new(@x, @y, @w, @h)
    if bounds.intersect?(SB.player.bomb.bounds)
      SB.player.bomb.hit
    end
  end
end

class SpecGate < SBGameObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_SpecGate
    @active_bounds = Rectangle.new(x, y, 32, 32)
  end

  def update(section)
    if SB.player.bomb.collide? self
      SB.prepare_special_world
    end
  end
end

class Graphic < Sprite
  def initialize(x, y, args, section)
    type = args.to_i
    cols = 1; rows = 1
    img_index = nil
    case type
    when 1 then @w = 32; @h = 64
    when 2 then x += 16; y += 16; @w = 64; @h = 64; cols = 2; rows = 2; @indices = [0, 1, 2, 3]; @interval = 7; @rot = -5
    when 3..5 then x -= 16; @w = 64; @h = 32
    when 6 then x -= 134; y -= 208; @w = 300; @h = 240
    when 7..9 then @w = 128; @h = 64
    when 10 then x -= 236; y -= 416; @w = 600; @h = 480
    when 12 then x += 2; @w = 126; @h = 128; cols = 2; rows = 2; @indices = [0, SB.lang == :portuguese ? 1 : SB.lang == :english ? 2 : 3]; @interval = 60
    when 13..15 then x -= 64; y -= 88; @w = 160; @h = 120; cols = 1; rows = 3; img_index = SB.lang == :portuguese ? 1 : SB.lang == :english ? 0 : 2
    end
    super x, y, "sprite_graphic#{type}", cols, rows
    @img_index = img_index if img_index
    @active_bounds = Rectangle.new(x, y, @w, @h)
    @angle = 0 if @rot
  end

  def update(section)
    animate @indices, @interval if @indices
    @angle += @rot if @rot
  end

  def draw(map)
    @rot ?
      (@img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h/2 - map.cam.y, -1, @angle, 0.5, 0.5, 2, 2) :
      super(map, 2, 2, 255, 0xffffff, nil, nil, -1)
  end

  def is_visible(map)
    map.cam.intersect? @active_bounds
  end

  def dead?
    false
  end
end
