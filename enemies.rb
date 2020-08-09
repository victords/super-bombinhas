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
Vector = MiniGL::Vector

############################### classes abstratas ##############################

class Enemy < GameObject
  attr_reader :dying

  def initialize(x, y, w, h, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1)
    super x, y, w, h, "sprite_#{self.class}", img_gap, sprite_cols, sprite_rows

    @indices = indices
    @interval = interval
    @score = score
    @hp = hp
    @control_timer = 0

    @active_bounds = Rectangle.new x + img_gap.x, y + img_gap.y, @img[0].width * 2, @img[0].height * 2
  end

  def set_active_bounds(section)
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

  def update(section, tolerance = nil)
    if @dying
      @control_timer += 1
      @dead = true if @control_timer == 150
      return if @img_index == @indices[-1]
      animate @indices, @interval
      return
    end

    unless SB.player.dead?
      b = SB.player.bomb
      if b.over?(self, tolerance)
        hit_by_bomb(section)
      else
        if b.collide?(self)
          b.hit
        end
        unless @invulnerable
          if b.explode?(self) or section.explode?(self)
            hit_by_explosion(section)
          else
            proj = section.projectile_hit?(self)
            hit_by_projectile(section) if proj && proj != 8
          end
        end
      end
    end

    return if @dying

    if @invulnerable
      @control_timer += 1
      return_vulnerable if @control_timer == C::INVULNERABLE_TIME
    end

    yield if block_given?

    set_active_bounds section
    animate @indices, @interval
  end

  def hit_by_bomb(section)
    SB.player.bomb.bounce(!@invulnerable)
    hit(section, SB.player.bomb.power) unless @invulnerable
  end

  def hit_by_explosion(section)
    @hp = 1
    hit(section)
  end

  def hit_by_projectile(section)
    hit(section)
  end

  def hit(section, amount = 1)
    @hp -= amount
    if @hp == 0
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      @dying = true
      @indices = [@img.size - 1]
      set_animation @img.size - 1
    else
      get_invulnerable
    end
  end

  def get_invulnerable
    @invulnerable = true
  end

  def return_vulnerable
    @invulnerable = false
    @control_timer = 0
  end

  def draw(map = nil, scale_x = 2, scale_y = 2, alpha = 0xff, color = 0xffffff, angle = nil, flip = nil, z_index = 0, round = false)
    return if @invulnerable && (@control_timer / 3) % 2 == 0
    super(map, scale_x, scale_y, alpha, color, angle, flip, z_index, round)
  end
end

class FloorEnemy < Enemy
  def initialize(x, y, args, w, h, img_gap, sprite_cols, sprite_rows, indices, interval, score, speed, hp = 1)
    super x, y, w, h, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp

    @dont_fall = args.nil?
    @speed_m = speed
    @forces = Vector.new -@speed_m, 0
    @facing_right = false
    @turning = false
  end

  def update(section, tolerance = nil, &block)
    if @invulnerable
      super section
    elsif @turning
      if block_given?
        super(section, tolerance, &block)
      else
        set_direction
        super(section, tolerance)
      end
    else
      super section do
        move(@forces, section.get_obstacles(@x, @y, @w, @h), @dont_fall ? [] : section.ramps)
        @forces.x = 0
        if @left
          prepare_turn :right
        elsif @right
          prepare_turn :left
        elsif @dont_fall
          if @facing_right
            prepare_turn :left unless section.obstacle_at?(@x + @w, @y + @h)
          elsif not section.obstacle_at?(@x - 1, @y + @h)
            prepare_turn :right
          end
        elsif @facing_right
          @forces.x = @speed_m if @speed.x == 0
          prepare_turn :left if @speed.x < 0
        else
          @forces.x = -@speed_m if @speed.x == 0
          prepare_turn :right if @speed.x > 0
        end
      end
    end
  end

  def prepare_turn(dir)
    @turning = true
    @speed.x = 0
    @next_dir = dir
  end

  def set_direction
    @turning = false
    if @next_dir == :left
      @forces.x = -@speed_m
      @facing_right = false
    else
      @forces.x = @speed_m
      @facing_right = true
    end
  end

  def draw(map, color = 0xffffff)
    super(map, 2, 2, 255, color, nil, @facing_right ? :horiz : nil)
  end
end

module Boss
  def init
    @activation_x = @x + @w / 2 - C::SCREEN_WIDTH / 2
    @timer = 0
    @state = :waiting
    @speech = "#{self.class.to_s.downcase}_speech".to_sym
    @death_speech = "#{self.class.to_s.downcase}_death".to_sym
  end

  def update_boss(section, do_super_update = true, &block)
    if @state == :waiting
      if SB.player.bomb.x >= @activation_x
        section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
        @state = :speaking
      end
    elsif @state == :speaking
      @timer += 1
      if @timer >= 300 or SB.key_pressed?(:confirm)
        section.unset_fixed_camera
        @state = :acting
        @timer = 119
        SB.play_song(Res.song(:boss))
      end
    else
      if @dying
        @timer += 1
        if @timer >= 300 or SB.key_pressed?(:confirm)
          section.unset_fixed_camera
          section.finish
          @dead = true
        end
        return
      end
      if do_super_update
        super_update(section, &block)
      elsif block_given?
        yield
      end
      if @dying
        set_animation 0
        section.set_fixed_camera(@x + @w / 2, @y + @h / 2)
        @timer = 0
      end
    end
  end

  def draw_boss
    if @state == :speaking or (@dying and not @dead)
      G.window.draw_quad 5, 495, C::PANEL_COLOR,
                         795, 495, C::PANEL_COLOR,
                         5, 595, C::PANEL_COLOR,
                         795, 595, C::PANEL_COLOR, 1
      SB.text_helper.write_breaking SB.text(@state == :speaking ? @speech : @death_speech), 10, 500, 780, :justified, 0, 255, 1
    end
  end
end

################################################################################

class Wheeliam < FloorEnemy
  def initialize(x, y, args, section)
    super x, y, args, 32, 32, Vector.new(-4, -2), 3, 1, [0, 1], 8, 100, 1.6
    @max_speed.y = 10
  end
end

class Sprinny < Enemy
  def initialize(x, y, args, section)
    super x + 3, y, 26, 32, Vector.new(-2, -5), 3, 1, [0, 1], 7, 250

    @leaps = 1000
    @max_leaps = args.to_i
    @facing_right = true
    @indices = [0]
    @idle_timer = 0
  end

  def update(section)
    super(section, 24) do
      forces = Vector.new 0, 0
      if @bottom
        @speed.x = 0
        @indices = [0, 1]
        @idle_timer += 1
        if @idle_timer > 30
          @leaps += 1
          if @leaps > @max_leaps
            @leaps = 1
            @facing_right = !@facing_right
          end
          if @facing_right; forces.x = 3
          else; forces.x = -3; end
          forces.y = -8.5
          @idle_timer = 0
          @indices = [0]
        end
      end
      prev_g = G.gravity.y
      G.gravity.y *= 0.75
      move forces, section.get_obstacles(@x, @y), section.ramps
      G.gravity.y = prev_g
    end
  end

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end

class Fureel < FloorEnemy
  def initialize(x, y, args, section)
    super x - 4, y - 7, args, 40, 39, Vector.new(-10, 0), 3, 1, [0, 1], 8, 300, 2.3, 2
  end

  def get_invulnerable
    @invulnerable = true
    @indices = [2]
    set_animation 2
  end

  def return_vulnerable
    @invulnerable = false
    @timer = 0
    @indices = [0, 1]
    set_animation 0
  end
end

class Yaw < Enemy
  TRACK_POINTS_DISTANCE = 10.66

  def initialize(x, y, args, section)
    super x, y, 32, 32, Vector.new(-4, -4), 3, 2, [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 3, 4, 5], 6, 500
    @points = [
      Vector.new(x + 64, y),
      Vector.new(x + 96, y + 32),
      Vector.new(x + 96, y + 96),
      Vector.new(x + 64, y + 128),
      Vector.new(x, y + 128),
      Vector.new(x - 32, y + 96),
      Vector.new(x - 32, y + 32),
      Vector.new(x, y)
    ]

    @track = []
    @points.each_with_index do |p, i|
      n_p = i == @points.size - 1 ? @points[0] : @points[i + 1]
      d_x = n_p.x - p.x; d_y = n_p.y - p.y
      d = Math.sqrt(d_x**2 + d_y**2)
      amount = (d / TRACK_POINTS_DISTANCE).to_i
      ratio = TRACK_POINTS_DISTANCE / d
      (0...amount).each do |j|
        @track << [p.x + j * ratio * d_x - 1 + @w / 2, p.y + j * ratio * d_y - 1 + @h / 2,
                   p.x + j * ratio * d_x + 1 + @w / 2, p.y + j * ratio * d_y - 1 + @h / 2,
                   p.x + j * ratio * d_x - 1 + @w / 2, p.y + j * ratio * d_y + 1 + @h / 2,
                   p.x + j * ratio * d_x + 1 + @w / 2, p.y + j * ratio * d_y + 1 + @h / 2]
      end
    end

    @active_bounds = Rectangle.new(x - 32, y, 160, 160)
  end

  def update(section)
    super section do
      cycle @points, 3
    end
  end

  def hit_by_bomb(section)
    SB.player.bomb.hit
  end

  def draw(map)
    @track.each do |t|
      G.window.draw_quad(t[0] - map.cam.x, t[1] - map.cam.y, 0xffffffff,
                         t[2] - map.cam.x, t[3] - map.cam.y, 0xffffffff,
                         t[4] - map.cam.x, t[5] - map.cam.y, 0xffffffff,
                         t[6] - map.cam.x, t[7] - map.cam.y, 0xffffffff, 0)
    end
    super(map)
  end
end

class Ekips < GameObject
  def initialize(x, y, args, section)
    super x + 5, y - 10, 22, 25, :sprite_Ekips, Vector.new(-37, -8), 2, 3

    @act_timer = 0
    @active_bounds = Rectangle.new x - 32, y - 18, 96, 50
    @attack_bounds = Rectangle.new x - 26, y + 10, 84, 12
    @score = 200
  end

  def update(section)
    b = SB.player.bomb
    if b.explode?(self) || section.projectile_hit?(self) && !@attacking
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      @dead = true
      return
    end

    if b.over? self
      if @attacking
        b.bounce
        SB.player.stage_score += @score
        section.add_score_effect(@x + @w / 2, @y, @score)
        @dead = true
        return
      else
        b.hit
      end
    elsif @attacking and b.bounds.intersect? @attack_bounds
      b.hit
    elsif b.collide? self
      b.hit
    end

    @act_timer += 1
    if @preparing and @act_timer >= 60
      animate [2, 3, 4, 5], 5
      if @img_index == 5
        @attacking = true
        @preparing = false
        set_animation 5
        @act_timer = 0
      end
    elsif @attacking and @act_timer >= 150
      animate [4, 3, 2, 1, 0], 5
      if @img_index == 0
        @attacking = false
        set_animation 0
        @act_timer = 0
      end
    elsif @act_timer >= 150
      @preparing = true
      set_animation 1
      @act_timer = 0
    end
  end

  def draw(map)
    super(map, 2, 2)
  end
end

class Faller < GameObject
  def initialize(x, y, args, section)
    super x, y, 32, 12, :sprite_Faller, Vector.new(-1, 0), 4, 1
    @range = args.to_i
    @start = Vector.new x, y
    @up = Vector.new x, y - @range * 32
    @active_bounds = Rectangle.new x, @up.y, 32, (@range + 1) * 32
    @passable = true
    section.obstacles << self

    @bottom = Block.new x, y + 20, 32, 12, false
    @bottom_img = Res.img :sprite_Faller2
    section.obstacles << @bottom

    @indices = [0, 1, 2, 3, 2, 1]
    @interval = 8
    @step = 0
    @act_timer = 0
    @score = 300
  end

  def update(section)
    b = SB.player.bomb
    if b.explode? self
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      section.obstacles.delete self
      section.obstacles.delete @bottom
      @dead = true
      return
    elsif b.bottom == @bottom
      b.hit
    elsif b.bounds.intersect?(Rectangle.new(@x, @y + 12, @w, 2))
      b.hit
    end

    animate @indices, @interval

    if @step == 0 or @step == 2 # parado
      @act_timer += 1
      if @act_timer >= 90
        @step += 1
        @act_timer = 0
      end
    elsif @step == 1 # subindo
      move_carrying @up, 1, [b], section.get_obstacles(b.x, b.y), section.ramps
      @step += 1 if @speed.y == 0
    else # descendo
      diff = ((@start.y - @y) / 5).ceil
      move_carrying @start, diff, [b], section.get_obstacles(b.x, b.y), section.ramps
      @step = 0 if @speed.y == 0
    end
  end

  def draw(map)
    @img[@img_index].draw @x - map.cam.x, @y - map.cam.y, 0, 2, 2
    @bottom_img.draw @x - map.cam.x, @start.y + 15 - map.cam.y, 0, 2, 2
  end
end

class Turner < Enemy
  def initialize(x, y, args, section)
    super x + 2, y - 7, 60, 39, Vector.new(-2, -25), 3, 2, [0, 1, 2, 1], 8, 300
    @harmful = true
    @passable = true
    @speed_m = 1.5

    @aim1 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim1.x - 3, @aim1.y and
      not section.obstacle_at? @aim1.x - 3, @aim1.y + 8 and
      section.obstacle_at? @aim1.x - 3, @y + @h
      @aim1.x -= C::TILE_SIZE
    end

    @aim2 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim2.x + 63, @aim2.y and
      not section.obstacle_at? @aim2.x + 63, @aim2.y + 8 and
      section.obstacle_at? @aim2.x + 63, @y + @h
      @aim2.x += C::TILE_SIZE
    end

    @obst = section.obstacles
  end

  def update(section)
    @harm_bounds = Rectangle.new @x, @y - 23, 60, 62
    super section do
      if @harmful
        SB.player.bomb.hit if SB.player.bomb.bounds.intersect? @harm_bounds
        move_free @aim1, @speed_m
        if @speed.x == 0 and @speed.y == 0
          @harmful = false
          @indices = [3, 4, 5, 4]
          set_animation 3
          @obst << self
        end
      else
        b = SB.player.bomb
        move_carrying @aim2, @speed_m, [b], section.get_obstacles(b.x, b.y), section.ramps
        if @speed.x == 0 and @speed.y == 0
          @harmful = true
          @indices = [0, 1, 2, 1]
          set_animation 0
          @obst.delete self
        end
      end
    end
  end

  def hit_by_bomb(section); end

  def hit_by_explosion
    SB.player.stage_score += @score
    @obst.delete self unless @harmful
    @dead = true
  end
end

class Chamal < Enemy
  include Boss
  alias :super_update :update

  X_OFFSET = 224
  WALK_AMOUNT = 96

  def initialize(x, y, args, section)
    super x - 25, y - 74, 82, 106, Vector.new(-16, -8), 3, 1, [0, 1, 0, 2], 7, 1000, 3
    @left_limit = @x - X_OFFSET
    @right_limit = @x + X_OFFSET
    @spawn_points = [
      Vector.new(@x + @w / 2 - 40, @y - 400),
      Vector.new(@x + @w / 2 + 80, @y - 400),
      Vector.new(@x + @w / 2 + 200, @y - 400)
    ]
    @spawns = []
    @turn = 2
    @speed_m = 3
    @facing_right = false
    init
  end

  def update(section)
    update_boss(section) do
      if @moving
        move_free @aim, @speed_m
        if @speed.x == 0 and @speed.y == 0
          @moving = false
          @timer = 0
        end
      else
        @timer += 1
        if @timer == 120
          if @facing_right
            if @x >= @right_limit
              x = @x - WALK_AMOUNT
              @facing_right = false
            else
              x = @x + WALK_AMOUNT
            end
          elsif @x <= @left_limit
            x = @x + WALK_AMOUNT
            @facing_right = true
          else
            x = @x - WALK_AMOUNT
          end
          @aim = Vector.new x, @y
          @moving = true
          if @spawns.size == 0
            @turn += 1
            if @turn == 3
              @spawn_points.each do |p|
                @spawns << Wheeliam.new(p.x, p.y, '!', section)
                section.add(@spawns[-1])
              end
              @respawned = true
            end
          end
        end
      end
      if @spawns.all?(&:dead?) && @respawned && @gun_powder.nil?
        @spawns = []
        @respawned = false
        @gun_powder = GunPowder.new(@x, @y + 74, nil, section, nil)
        section.add(@gun_powder)
        section.add_effect(Effect.new(@x - 14, @y + 10, :fx_arrow, 3, 1, 8, [0, 1, 2, 1], 300))
        @turn = 0
      end
      @gun_powder = nil if @gun_powder && @gun_powder.dead?
    end
  end

  def hit_by_bomb(section)
    SB.player.bomb.bounce(false)
  end

  def hit_by_explosion(section)
    hit(section)
    @speed_m = 4 if @hp == 1
    @moving = false
    @timer = -C::INVULNERABLE_TIME
  end

  def get_invulnerable
    super
    @indices = [0]
    set_animation 0
  end

  def return_vulnerable
    super
    @indices = [0, 1, 0, 2]
    set_animation 0
  end

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    draw_boss
  end
end

class Electong < Enemy
  def initialize(x, y, args, section)
    super x - 12, y - 11, 56, 43, Vector.new(-4, -91), 4, 2, [0, 1, 2, 1], 7, 300, 1
    @timer = 0
    @tongue_y = @y
  end

  def hit_by_bomb(section)
    SB.player.bomb.hit
  end

  def update(section)
    super(section) do
      b = SB.player.bomb
      if @will_attack
        @tongue_y -= 91 / 14.0
        if @img_index == 5
          @indices = [5, 6, 7, 6]
          @attacking = true
          @will_attack = false
          @tongue_y = @y - 91
        end
      elsif @attacking
        @timer += 1
        if @timer == 60
          @indices = [4, 3, 0]
          set_animation 4
          @attacking = false
        end
      elsif @timer > 0
        @tongue_y += 91 / 14.0
        if @img_index == 0
          @indices = [0, 1, 2, 1]
          @timer = -60
          @tongue_y = @y
        end
      else
        @timer += 1 if @timer < 0
        if @timer == 0 and b.x + b.w > @x - 40 and b.x < @x + @w + 40
          @indices = [3, 4, 5]
          set_animation 3
          @will_attack = true
        end
      end
      if b.bounds.intersect? Rectangle.new(@x + 22, @tongue_y, 12, @y + @h - @tongue_y)
        b.hit
      end
    end
  end
end

class Chrazer < Enemy
  def initialize(x, y, args, section)
    super x + 1, y - 11, 30, 43, Vector.new(-21, -20), 2, 2, [0, 1, 0, 2], 7, 600, 2
    @facing_right = false
  end

  def update(section)
    super(section) do
      forces = Vector.new(0, 0)
      unless @invulnerable
        d = SB.player.bomb.x - @x
        d = 150 if d > 150
        d = -150 if d < -150
        if @bottom
          forces.x = d * 0.01666667
          forces.y = -12.5
          if d > 0 and not @facing_right
            @facing_right = true
          elsif d < 0 and @facing_right
            @facing_right = false
          end
          @speed.x = 0
        else
          forces.x = d * 0.001
        end
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
    end
  end

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end

class Robort < FloorEnemy
  def initialize(x, y, args, section)
    super x - 12, y - 31, args, 56, 63, Vector.new(-14, -9), 3, 2, [0, 1, 2, 1], 6, 450, 2.2, 3
  end

  def update(section)
    super(section) do
      @timer += 1
      if @timer == 90
        @indices = [0, 1, 2, 1]
        @interval = 7
        set_direction
      end
    end
  end

  def prepare_turn(dir)
    @indices = [3, 4, 5, 4]
    @interval = 4
    @timer = 0
    super(dir)
  end

  def hit_by_bomb(section)
    if @turning
      SB.player.bomb.hit
    else
      super(section)
    end
  end
end

class Shep < FloorEnemy
  def initialize(x, y, args, section)
    super x, y, args, 42, 32, Vector.new(-5, -2), 3, 2, [0, 1, 0, 2], 7, 160, 2
  end

  def update(section)
    super(section) do
      @timer += 1
      if @timer == 35
        section.add(Projectile.new(@facing_right ? @x + @w - 4 : @x - 4, @y + 10, 2, @facing_right ? 0 : 180, self))
        @indices = [0, 1, 0, 2]
        set_animation(@indices[0])
        set_direction
      end
    end
  end

  def prepare_turn(dir)
    @timer = 0
    @indices = [0, 3, 4, 5, 5]
    set_animation @indices[0]
    super(dir)
  end
end

class Flep < Enemy
  def initialize(x, y, args, section)
    super x, y, 64, 20, Vector.new(0, 0), 1, 3, [0, 1, 2], 6, 250, 2
    @movement = C::TILE_SIZE * args.to_i
    @aim = Vector.new(@x - @movement, @y)
    @facing_right = false
  end

  def update(section)
    if @invulnerable
      super(section)
    else
      super(section) do
        move_free @aim, 2.5
        if @speed.x == 0 and @speed.y == 0
          @aim = Vector.new(@x + (@facing_right ? -@movement : @movement), @y)
          @facing_right = !@facing_right
        end
      end
    end
  end

  def draw(map)
    super map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil
  end
end

class Jellep < Enemy
  def initialize(x, y, args, section)
    super x, section.size.y - 1, 32, 110, Vector.new(-5, 0), 3, 1, [0, 1, 0, 2], 5, 500
    @max_y = y
    @state = 0
    @timer = 0
    @active_bounds.y = y
    @water = true
  end

  def update(section)
    super(section) do
      if @state == 0
        @timer += 1
        if @timer == 60
          @stored_forces.y = -14
          @state = 1
          @timer = 0
        end
      else
        force = @y - @max_y <= 100 ? 0 : -G.gravity.y
        move Vector.new(0, force), [], []
        if @state == 1 and @speed.y >= 0
          @state = 2
        elsif @state == 2 and @y >= section.size.y
          @speed.y = 0
          @y = section.size.y - 1
          @state = 0
        end
        @prev_water = @water
        @water = section.element_at(Water, @x, @y)
        if @water && !@prev_water || @prev_water && !@water
          section.add_effect(Effect.new(@x - 16, (@water || @prev_water).y - 19, :fx_water, 1, 4, 8, nil, nil, :splash))
        end
      end
    end
  end

  def hit_by_bomb(section)
    b = SB.player.bomb
    if b.power > 1
      b.bounce
      hit(section)
    else
      b.hit
    end
  end

  def draw(map)
    super map, 2, 2, 255, 0xffffff, nil, @state == 2 ? :vert : nil
  end
end

class Snep < Enemy
  def initialize(x, y, args, section)
    super x, y - 24, 32, 56, Vector.new(0, 4), 5, 2, [0, 1, 0, 2], 12, 250
    @facing_right = args.nil?
  end

  def update(section)
    super(section) do
      b = SB.player.bomb
      if b.y + b.h > @y && b.y + b.h <= @y + @h &&
         (@facing_right && b.x > @x && b.x < @x + @w + 16 || !@facing_right && b.x < @x && b.x + b.w > @x - 16)
        if @attacking
          @hurting = true if @img_index == 8
          b.hit if @hurting
        else
          @attacking = true
          @indices = [6, 7, 8, 7, 6, 0]
          @interval = 4
          set_animation 6
        end
      end

      if @attacking && @img_index == 0
        @attacking = @hurting = false
        @indices = [0, 1, 0, 2]
        @interval = 12
        set_animation 0
      end
    end
  end

  def hit_by_bomb(section)
    SB.player.bomb.hit
    @attacking = true
    @indices = [3, 4, 5, 4, 3, 0]
    @interval = 4
    set_animation 3
  end

  def hit(section)
    super
    if @dying
      @indices = [9]
      set_animation 9
    end
  end

  def draw(map)
    super map, 2, 2, 255, 0xffffff, nil, @facing_right ? nil : :horiz
  end
end

class Vamep < Enemy
  def initialize(x, y, args, section)
    super x, y, 29, 22, Vector.new(-24, -18), 2, 2, [0, 1, 2, 3, 2, 1], 6, 250
    @angle = 0
    if args
      args = args.split ','
      @radius = args[0].to_i * C::TILE_SIZE
      @speed = (args[1] || '3').to_f
    else
      @radius = C::TILE_SIZE
      @speed = 3
    end
    @start_x = x
    @start_y = y
  end

  def update(section)
    super(section) do
      radians = @angle * Math::PI / 180
      @x = @start_x + Math.cos(radians) * @radius
      @y = @start_y + Math.sin(radians) * @radius
      @angle += @speed
      @angle %= 360 if @angle >= 360
    end
  end
end

class Armep < FloorEnemy
  def initialize(x, y, args, section)
    super(x, y + 12, args, 41, 20, Vector.new(-21, -3), 1, 4, [0, 1, 0, 2], 8, 350, 1.3)
  end

  def hit_by_bomb(section)
    b = SB.player.bomb
    if b.power > 1
      b.bounce
      hit(section)
    else
      b.hit
    end
  end

  def hit_by_projectile(section); end
end

class Owlep < Enemy
  def initialize(x, y, args, section)
    y -= 50 if args.nil?
    super x - 3, y - 32, 38, 55, Vector.new(-3, 0), 4, 1, [0, 0, 1, 0, 0, 0, 2], 60, 250, 2
  end

  def update(section)
    super(section) do
      b = SB.player.bomb
      if !@attacking && b.x + b.w > @x && b.x < @x + @w && b.y > @y + @h && b.y < @y + C::SCREEN_HEIGHT
        section.add(Projectile.new(@x + 10, @y + 10, 3, 90, self))
        section.add(Projectile.new(@x + 20, @y + 10, 3, 90, self))
        @indices = [0]
        set_animation 0
        @attacking = true
        @timer = 0
      elsif @attacking
        @timer += 1
        if @timer == 60
          @indices = [0, 0, 1, 0, 0, 0, 2]
          set_animation 0
          @attacking = false
        end
      end
    end
  end
end

class Zep < Enemy
  def initialize(x, y, args, section)
    super x, y - 18, 60, 50, Vector.new(-38, -30), 3, 2, [0, 1, 2, 3, 4], 5, 500, 3
    @passable = true

    @aim1 = Vector.new(@x, @y)
    while !section.obstacle_at?(@aim1.x - 3, @y) &&
      !section.obstacle_at?(@aim1.x - 3, @y + 18) &&
      !section.obstacle_at?(@aim1.x - 3, @y + 17 + C::TILE_SIZE) &&
      section.obstacle_at?(@aim1.x - 3, @y + @h)
      @aim1.x -= C::TILE_SIZE
    end

    @aim2 = Vector.new(@x, @y)
    while !section.obstacle_at?(@aim2.x + 65, @y) &&
      !section.obstacle_at?(@aim2.x + 65, @y + 18) &&
      !section.obstacle_at?(@aim2.x + 65, @y + 17 + C::TILE_SIZE) &&
      section.obstacle_at?(@aim2.x + 65, @y + @h)
      @aim2.x += C::TILE_SIZE
    end
    @aim2.x += 4

    @aim = @aim1
    section.obstacles << self
  end

  def update(section)
    super section do
      b = SB.player.bomb
      move_carrying @aim, 4, [b], section.get_obstacles(b.x, b.y), section.ramps
      if @speed.x == 0 and @speed.y == 0
        @aim = @aim == @aim1 ? @aim2 : @aim1
        @img_gap.x = @aim == @aim2 ? -16 : -24
      end
    end
  end

  def hit_by_bomb(section); end

  def hit(section)
    super
    if @dying
      section.obstacles.delete self
      @indices = [5]
      set_animation 5
    end
  end

  def draw(map)
    super map, 2, 2, 255, 0xffffff, nil, @aim == @aim1 ? nil : :horiz
  end
end

class Butterflep < Enemy
  def initialize(x, y, args, section)
    super(x - 12, y - 12, 56, 54, Vector.new(-4, -4), 2, 2, [0, 1, 2, 1], 10, 300)
    @speed_m = 5
    ps = args.split(':')
    @points = []
    ps.each do |p|
      pp = p.split(',')
      @points << Vector.new(pp[0].to_i * C::TILE_SIZE - 12, pp[1].to_i * C::TILE_SIZE - 12)
    end
    @points << Vector.new(@x, @y)
    @timer = 0
  end

  def update(section)
    super(section) do
      if @moving
        cycle(@points, @speed_m)
        if @speed.x == 0 and @speed.y == 0
          @moving = false
          @timer = 0
        end
      else
        @timer += 1
        @moving = true if @timer == 60
      end
    end
  end

  def hit_by_bomb(section)
    b = SB.player.bomb
    if b.power > 1
      b.bounce
      hit(section)
    else
      b.hit
    end
  end
end

class Sahiss < FloorEnemy
  include Boss
  alias :super_update :update

  def initialize(x, y, args, section)
    super x - 54, y - 148, args, 148, 180, Vector.new(-139, -3), 2, 3, [0, 1, 0, 2], 7, 2000, 3, 4
    @time = 180 + rand(240)
    section.active_object = self
    init
  end

  def update(section)
    update_boss(section, false) do
      if @attacking
        move_free @aim, 6
        b = SB.player.bomb
        if b.over? self
          b.bounce(false)
        elsif b.collide? self
          b.hit
        elsif @img_index == 5
          r = Rectangle.new(@x + 170, @y, 1, 120)
          b.hit if b.bounds.intersect? r
        end
        if @speed.x == 0
          if @img_index == 5
            set_bounds 3
            @img_index = 4
          end
          @timer += 1
          if @timer == 5
            set_bounds 4
            @img_index = 0
          elsif @timer == 60
            @img_index = 0
            @stored_forces.x = -3
            @attacking = false
            @timer = 0
            @time = 180 + rand(240)
          end
        elsif @img_index == 4
          @timer += 1
          if @timer == 5
            set_bounds 2
            @img_index = 5
            @timer = 0
          end
        end
      end
    end
    if @state == :acting and not @attacking and not @dying
      prev = @facing_right
      super_update(section) unless @timer >= @time
      if @dead
        section.finish
      elsif @aim
        @timer += 1
        if @timer == @time
          if @facing_right
            @timer = @time - 1
          else
            set_animation(1)
          end
        elsif @timer == @time + 60
          set_bounds 1
          @attacking = true
          @img_index = 4
          @timer = 0
        end
      elsif @facing_right and not prev
        @aim = Vector.new(@x, @y)
      end
    end
  end

  def set_bounds(step)
    @x += case step; when 1 then -55; when 2 then -74; else 0; end
    @y += case step; when 1 then 16; when 2 then 60; when 3 then -60; else -16; end
    @aim.y += case step; when 1 then 16; when 2 then 60; when 3 then -60; else -16; end
    @w = case step; when 1 then 137; when 2 then 170; when 3 then 137; else 148; end
    @h = case step; when 1 then 164; when 2 then 70; when 3 then 164; else 180; end
    @img_gap.x = case step; when 1 then -84; when 2 then -10; when 3 then -84; else -139; end
    @img_gap.y = case step; when 1 then -19; when 2 then -64; when 3 then -19; else -3; end
  end

  def hit_by_bomb(section)
    SB.player.bomb.bounce(false)
  end

  def hit_by_projectile(section); end

  def hit(section)
    unless @invulnerable
      super
      SB.play_sound(Res.sound(:stomp))
      if @img_index == 5
        set_bounds 3; set_bounds 4
      elsif @img_index == 4
        set_bounds 4
      end
      @indices = [3]
      set_animation 3
      @attacking = false
      @timer = 0
      @time = 180 + rand(240)
    end
  end

  def return_vulnerable
    super
    @indices = [0, 1, 0, 2]
    set_animation 0
  end

  def draw(map)
    super(map)
    draw_boss
  end
end

class Forsby < Enemy
  def initialize(x, y, args, section)
    super x - 8, y - 22, 48, 54, Vector.new(-11, -6), 2, 3, [0, 1, 0, 2], 15, 250, 2
    @facing_right = !args.nil?
    @state = @timer = 0
  end

  def update(section)
    super(section) do
      @timer += 1
      if @state == 0 && @timer > 120
        @indices = [3]
        set_animation 3
        @state = 1
      elsif @state == 1 && @timer > 180
        @indices = [4]
        set_animation 4
        section.add(Projectile.new(@facing_right ? @x + @w - 16 : @x - 5, @y + 14, 5, @facing_right ? 0 : 180, self))
        @state = 2
      elsif @state == 2 && @timer > 210
        @indices = [0, 1, 0, 2]
        set_animation 0
        @state = @timer = 0
      end
    end
    if @dying
      @indices = [5]
      set_animation 5
    end
  end

  def draw(map)
    super map, 2, 2, 255, 0xffffff, nil, @facing_right ? nil : :horiz
  end
end

class Stilty < FloorEnemy
  def initialize(x, y, args, section)
    super(x + 6, y - 26, args, 20, 58, Vector.new(-6, -42), 5, 2, [0, 1, 0, 2], 7, 350, 2, 2)
  end

  def update(section)
    if @rising
      animate @indices, @interval
      if @img_index == 6
        @y -= 40; @h += 40
        @img_gap.y = -2
        @speed_m = 3
        if @speed.x < 0
          @speed.x = -3
        elsif @speed.x > 0
          @speed.x = 3
        end
        @indices = [6, 7, 6, 8]
        set_animation 6
        @rising = false
      end
    else
      super(section, 20)
    end
  end

  def hit(section, amount = 1)
    super
    @indices = (@hp == 0 ? [9] : [3])
    set_animation(@hp == 0 ? 9 : 3)
  end

  def return_vulnerable
    super
    @rising = true
    @indices = [0, 4, 0, 4, 5, 4, 5, 6]
    set_animation 0
  end
end

class Mantul < FloorEnemy
  def initialize(x, y, args, section)
    super(x - 10, y - 24, args, 52, 56, Vector.new(-6, -8), 2, 2, [0, 1, 0, 2], 7, 350, 1.5, 2)
    @timer = 0
  end

  def update(section)
    super(section)
    return if @dying or @invulnerable
    @timer += 1
    if @timer == 180
      section.add(Projectile.new(@x + 48, @y + 30, 2, 0, self))
      section.add(Projectile.new(@x - 4, @y + 30, 2, 180, self))
      section.add(Projectile.new(@x + 10, @y, 2, 240, self))
      section.add(Projectile.new(@x + 34, @y, 2, 300, self))
      @timer = 0
    end
  end
end

class Lambul < FloorEnemy
  def initialize(x, y, args, section)
    super(x - 4, y - 38, args, 30, 70, Vector.new(-50, -10), 4, 2, [0, 1, 0, 2], 7, 500, 2)
  end

  def update(section)
    b = SB.player.bomb
    if @attacking
      @timer += 1
      if @timer == 80
        @attacking = false
        set_animation 0
      elsif @timer >= 60
        animate [6, 5, 4, 3], 5
      elsif @timer >= 20
        r = Rectangle.new(@facing_right ? @x : @x - 48, @y + 35, 88, 10)
        b.hit if b.bounds.intersect?(r)
      else
        animate [3, 4, 5, 6], 5
      end
    elsif !SB.player.dead? && b.y + b.h == @y + @h && (b.x + b.w/2 - @x - @w/2).abs <= 65 && (b.x < @x && !@facing_right || b.x > @x && @facing_right)
      @attacking = true
      @timer = 0
      set_animation 3
    else
      super
    end
  end

  def hit_by_bomb(section)
    hit(section) if SB.player.bomb.power > 1
  end
end

class Icel < Enemy
  def initialize(x, y, args, section)
    super x - 4, y + 2, 40, 28, Vector.new(-4, -4), 2, 3, [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5], 7, 450
    @radius = (args || 2).to_i * C::TILE_SIZE
    @timer = @angle = 0
    @state = 3
    @center = Vector.new(@x + @w/2, @y + @h/2)
  end

  def update(section)
    super(section) do
      @timer += 1
      if @timer == 120
        @eff1 = section.add_effect(Ice.new(@center.x + @radius, @center.y))
        @eff2 = section.add_effect(Ice.new(@center.x - @radius, @center.y))
      elsif @timer == 240
        @eff1 = @eff2 = nil
        @timer = @angle = 0
      elsif @timer > 120
        @angle += Math::PI / 60
        x_off = @radius * Math.cos(@angle)
        y_off = @radius * Math.sin(@angle)
        @eff1.move(@center.x + x_off, @center.y - y_off)
        @eff2.move(@center.x - x_off, @center.y + y_off)
      end

      if @timer % 10 == 0
        if @state == 0 or @state == 1; @y -= 1
        else; @y += 1; end
        @state += 1
        @state = 0 if @state == 4
      end
    end
  end

  def hit_by_bomb(section); end
end

class Ignel < Enemy
  def initialize(x, y, args, section)
    super x + 4, y - 16, 24, 48, Vector.new(-2, -12), 3, 1, [0, 1, 2], 5, 450
    @radius = (args || 4).to_i
    @timer = 0
    @center = Vector.new(@x + @w/2, @y + @h)
  end

  def update(section)
    super(section) do
      @timer += 1
      if @timer == 120
        (1..@radius).each do |i|
          section.add_effect(Fire.new(@center.x + i * C::TILE_SIZE, @center.y))
          section.add_effect(Fire.new(@center.x - i * C::TILE_SIZE, @center.y))
        end
      elsif @timer == 240
        @timer = 0
      end
    end
  end

  def hit_by_bomb(section)
    SB.player.bomb.hit
  end

  def hit_by_explosion(section); end
end

class Warclops < Enemy
  def initialize(x, y, args, section)
    super x - 19, y - 84, 70, 116, Vector.new(-10, -4), 2, 2, [0, 1, 0, 2], 9, 800, 3
  end

  def update(section)
    super(section) do
      forces = Vector.new(0, 0)
      unless @invulnerable
        b = SB.player.bomb
        d = b.x + b.w/2 - @x - @w/2
        d = 150 if d > 150
        d = -150 if d < -150
        forces.x = d * 0.01666667
        if d > 0 and not @facing_right
          @facing_right = true
        elsif d < 0 and @facing_right
          @facing_right = false
        end
        @speed.x = 0
      end
      move forces, section.get_obstacles(@x, @y, @w, @h), section.ramps
    end
  end

  def draw(map)
    super map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil
  end

  def hit_by_bomb(section)
    b = SB.player.bomb
    b.bounce(b.power > 1)
    hit(section) if b.power > 1
  end

  def hit_by_explosion(section)
    @hp -= 1
    hit(section)
  end
end

class Necrul < FloorEnemy
  def initialize(x, y, args, section)
    super(x - 20, y - 32, nil, 72, 64, Vector.new(-34, -10), 2, 3, [1,0,1,2], 7, 400, 2, 2)
  end

  def update(section)
    super(section) do
      @timer += 1
      if @timer % 28 == 0
        section.add(Projectile.new(@facing_right ? @x + @w + 30 : @x - 30, @y + 30, 6, @facing_right ? 0 : 180, self))
        if @timer == 112
          @indices = [1, 0, 1, 2]
          set_animation(@indices[0])
          set_direction
        elsif @timer == 56
          @facing_right = !@facing_right
        end
      end
    end
  end

  def prepare_turn(dir)
    @timer = 0
    @indices = [1, 3, 4, 3]
    set_animation @indices[0]
    super(dir)
  end
end

class Ulor < FloorEnemy
  include Boss

  alias :super_update :update

  def initialize(x, y, args, section)
    super(x - 34, y - 88, args, 100, 120, Vector.new(-20, -8), 2, 2, [0, 1, 0, 2], 7, 2400, 3, 5)
    @timer = 0
    @state = :walking
    @spawn_point = Vector.new(x - 12 * C::TILE_SIZE, y - 9 * C::TILE_SIZE)
    init
  end

  def update(section)
    update_boss(section, false) do
      @attack_time = 180 + rand(120) if @attack_time.nil?
      @timer += 1
      if @state == :preparing
        if @timer == 90
          set_animation(3)
          (1..25).each do |i|
            section.activate_object(Stalactite, i)
          end
          @spawned = false
          @timer = 0
          @state = :attacking
        end
        if @timer % 10 == 0
          @x += 5
        elsif @timer % 5 == 0
          @x -= 5
        end
      elsif @state == :attacking
        if @timer == (@hp < 3 ? 60 : 120)
          set_animation(0)
          @timer = 0
          @state = :walking
        end
      else
        super_update(section)
        unless @spawned
          (0..24).each do |i|
            section.add(Stalactite.new(@spawn_point.x + i * C::TILE_SIZE, @spawn_point.y, "2,!,#{i + 1}", section))
          end
          @spawned = true
        end
        if @timer == @attack_time
          set_animation(0)
          @timer = 0
          @attack_time = nil
          @state = :preparing
        end
      end

      if @state != :walking
        unless SB.player.dead?
          b = SB.player.bomb
          if b.over?(self, nil)
            hit_by_bomb(section)
          elsif b.collide?(self)
            b.hit
          end
        end
      end
    end
  end

  def hit_by_bomb(section)
    can_hit = @state == :attacking && !@invulnerable
    SB.player.bomb.bounce(can_hit)
    if can_hit
      hit(section, 1)
      if @hp < 3
        @speed_m = 4
        @speed.x = (@speed.x <=> 0) * 4
      end
      @state = :walking
    end
  end

  def hit_by_projectile(section); end

  def draw(map)
    super(map, @hp < 3 ? 0xff9999 : 0xffffff)
    draw_boss
  end
end

class Umbrex < FloorEnemy
  RANGE = 10

  def initialize(x, y, args, section)
    super(x, y - 118, args, 32, 150, Vector.new(-64, -10), 4, 2, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1], 7, 350, 3)
    @hop_timer = 0
  end

  def update(section)
    b = SB.player.bomb
    if @attacking
      @timer += 1
      if @timer == 80
        set_animation(0)
        @attacking = false
      elsif @timer < 20
        animate([3, 4, 5, 6], 5)
      elsif @timer >= 60
        animate([6, 5, 4, 3], 5)
      end
      if @timer >= 10 && @timer < 60
        b.hit if b.collide?(self)
      end
    elsif @dying
      super(section)
    else
      area = Rectangle.new(@x + @img_gap.x, @y + @img_gap.y, 160, 160)
      if b.bounds.intersect?(area)
        if b.y > area.y && b.x >= @active_bounds.x - @img_gap.x && b.x + b.w <= @active_bounds.x + @active_bounds.w + @img_gap.x
          @x += 0.1 * (b.x - @x)
          if (b.x - @x).abs <= RANGE
            set_animation(3)
            @attacking = true
            @timer = 0
          end
        elsif b.over?(self)
          hit_by_bomb(section)
        end
      else
        super(section)
      end
    end

    if @attacking || @dying
      @hop_timer = 0
    else
      @hop_timer += 1
      @hop_timer = 0 if @hop_timer == 16
    end
  end

  def draw(map)
    d_y = 16 - 0.25 * (@hop_timer - 8)**2
    @y -= d_y
    super(map)
    @y += d_y
  end
end

class Quartin < Enemy
  class QuartinShield < GameObject
    RADIUS = 36

    attr_reader :dead

    def initialize(x, y, x_c, y_c, angle)
      super(x, y, 24, 24, :sprite_QuartinShield, Vector.new(-4, -4), 2, 2)
      @x_c = x_c
      @y_c = y_c
      @angle = angle
    end

    def update(x_c, y_c)
      @x_c = x_c
      @y_c = y_c
      if @dying
        animate([1, 2, 3], 5)
        @timer += 1
        @dead = true if @timer == 15
      else
        b = SB.player.bomb
        if b.over?(self)
          b.bounce
          set_animation(1)
          @dying = true
          @timer = 0
        else
          b.hit if b.collide?(self)
          @angle += 2
          @angle = 0 if @angle == 360
          rad = @angle * Math::PI / 180
          @x = @x_c + Math.cos(rad) * RADIUS - @w / 2
          @y = @y_c + Math.sin(rad) * RADIUS - @h / 2
        end
      end
    end

    def draw(map)
      super(map, 2, 2)
    end
  end

  def initialize(x, y, args, section)
    super(x + 2, y + 2, 28, 28, Vector.new(-4, -4), 2, 2, [0, 1, 2, 1], 10, 400)
    x_c = @x + @w / 2
    y_c = @y + @h / 2
    @shields = [
      QuartinShield.new(@x + 38, @y + 2, x_c, y_c, 0),
      QuartinShield.new(@x + 2, @y - 34, x_c, y_c, 90),
      QuartinShield.new(@x - 34, @y + 2, x_c, y_c, 180),
      QuartinShield.new(@x + 2, @y + 38, x_c, y_c, 270)
    ]
    args = args.split(',')
    @movement = C::TILE_SIZE * args[0].to_i
    @facing_right = args[1].nil?
    @aim = Vector.new(@facing_right ? @x + @movement : @x - @movement, @y)
  end

  def update(section)
    super(section) do
      move_free @aim, 2
      if @speed.x == 0 && @speed.y == 0
        @facing_right = !@facing_right
        @aim = Vector.new(@facing_right ? @x + @movement : @x - @movement, @y)
      end
      @shields.reverse_each do |s|
        s.update(@x + @w / 2, @y + @h / 2)
        @shields.delete(s) if s.dead
      end
      hit(section) if @shields.empty? && @hp > 0
    end
  end

  def hit_by_bomb(section)
    SB.player.bomb.hit
  end

  def hit_by_projectile(section); end

  def draw(map)
    super(map)
    @shields.each do |s|
      s.draw(map)
    end
  end
end

class Xylophob < FloorEnemy
  def initialize(x, y, args, section)
    super x - 8, y - 22, args, 48, 54, Vector.new(-8, -10), 2, 2, [0, 1, 2, 1], 7, 350, 2, 3
  end

  def get_invulnerable
    super
    @indices = [3]
    set_animation 3
  end

  def return_vulnerable
    super
    @timer = 0
    @indices = [0, 1, 2, 1]
    set_animation 0
    @speed_m += 1
    @speed.x += @speed.x <=> 0
  end
end

class Bardin < FloorEnemy
  def initialize(x, y, args, section)
    super x + 2, y - 28, args, 28, 60, Vector.new(-12, -4), 4, 2, [0, 1, 2, 1], 7, 250, 2, 2
    @timer = 0
  end

  def update(section)
    super(section) do
      @timer += 1
      if @timer == 35
        section.add(Projectile.new(@facing_right ? @x + @w - 4 : @x - 4, @y + 10, 8, @facing_right ? 0 : 180, self))
        @indices = [0, 1, 2, 1]
        @interval = 7
        set_animation(@indices[0])
        set_direction
      end
    end
  end

  def prepare_turn(dir)
    @timer = 0
    @indices = [3, 4, 5, 6, 5, 4, 3]
    @interval = 5
    set_animation @indices[0]
    super(dir)
  end
end

class Dynamike < FloorEnemy
  def initialize(x, y, args, section)
    super x + 2, y - 28, args, 28, 60, Vector.new(-6, -4), 2, 2, [0, 1, 2, 1], 7, 250, 2.5
  end

  def explode(section)
    section.add_effect(Explosion.new(@x + @w / 2, @y + @h / 2, 90, self))
    SB.play_sound(Res.sound(:explode))
  end

  def hit_by_bomb(section)
    explode(section)
    super(section)
  end

  def hit_by_projectile(section)
    explode(section)
    super(section)
  end

  def hit_by_explosion(section)
    explode(section)
    super(section)
  end
end

class Hooman < Enemy
  def initialize(x, y, args, section)
    super(x + 2, y - 28, 28, 60, Vector.new(-6, -4), 2, 2, [0, 1, 2, 1], 7, 250, 2)
    @facing_right = !args.nil?
    @max_speed.x = 4
  end

  def update(section)
    super(section) do
      forces = Vector.new(0, 0)
      unless @invulnerable
        d = SB.player.bomb.x - @x
        d = 150 if d > 150
        d = -150 if d < -150
        if @bottom && (d < 0 && @left || d > 0 && @right)
          forces.x = d * 0.01666667
          forces.y = -12.5
          @speed.x = 0
        else
          forces.x = d * 0.001
        end
        if d > 0 and not @facing_right
          @facing_right = true
        elsif d < 0 and @facing_right
          @facing_right = false
        end
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
    end
  end

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end