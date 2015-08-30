require 'minigl'

class Bomb < GameObject
  attr_reader :type, :name, :hp, :facing_right, :can_use_ability
  attr_accessor :active

  def initialize(type, hp)
    case type
    when :azul     then @name = 'Bomba Azul';     def_hp = 1; @max_hp = 1;   l_img_gap = -10; r_img_gap = -10; t_img_gap = -6
    when :vermelha then @name = 'Bomba Vermelha'; def_hp = 2; @max_hp = 999; l_img_gap = -4; r_img_gap = -6;   t_img_gap = -10
    when :amarela  then @name = 'Bomba Amarela';  def_hp = 1; @max_hp = 1;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -10
    when :verde    then @name = 'Bomba Verde';    def_hp = 2; @max_hp = 3;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -10
    else                @name = 'Aldan';          def_hp = 1; @max_hp = 2;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -26
    end

    super -1000, -1000, 20, 30, "sprite_Bomba#{type.to_s.capitalize}", Vector.new(r_img_gap, t_img_gap), 6, 4
    @hp = hp == 0 ? def_hp : hp
    @max_speed.x = 5
    @max_speed.y = 30
    @indices = [0, 1, 0, 2]
    @facing_right = true
    @active = true
    @type = type

    @explosion = Sprite.new 0, 0, :fx_Explosion, 2, 2
    @explosion_timer = 0
    @explosion_counter = 10

    @can_use_ability = true
  end

  def update(section)
    forces = Vector.new 0, 0
    if @celebrating
      return if @img_index == 7
      animate @indices, 8
      return
    elsif @dying
      animate @indices, 8 unless @img_index == 10
    elsif @exploding
      @explosion.animate [0, 1, 2, 3], 5
      @explosion_counter += 1
      @exploding = false if @explosion_counter == 90
      forces.x -= 0.15 * @speed.x if @bottom and @speed.x != 0
    elsif @active
      if @invulnerable
        @invulnerable_timer += 1
        @invulnerable = false if @invulnerable_timer == @invulnerable_time
      end
      if @will_explode
        @explosion_timer += 1
        if @explosion_timer == 60
          @explosion_counter -= 1
          explode if @explosion_counter == 0
          @explosion_timer = 0
        end
      end
      if KB.key_down? Gosu::KbLeft
        @facing_right = false
        forces.x -= @bottom ? 0.5 : 0.08
      end
      if KB.key_down? Gosu::KbRight
        @facing_right = true
        forces.x += @bottom ? 0.5 : 0.08
      end
      if @bottom
        if @speed.x != 0
          animate @indices, 30 / @speed.x.abs
        else
          set_animation 0
        end
        if KB.key_pressed? Gosu::KbSpace
          forces.y -= 14 + 0.52 * @speed.x.abs
          set_animation 3
        end
        forces.x -= @speed.x * 0.15
      end
      SB.player.change_item if KB.key_pressed? Gosu::KbLeftShift or KB.key_pressed? Gosu::KbRightShift
      SB.player.use_item section if KB.key_pressed? Gosu::KbA

      if @can_use_ability
        if KB.key_pressed? Gosu::KbS
          if @type == :verde
            explode; @can_use_ability = false; @cooldown = C::EXPLODE_COOLDOWN
          elsif @type == :azul
            SB.stage.stop_time; @can_use_ability = false; @cooldown = C::STOP_TIME_COOLDOWN
          end
        end
      else
        @cooldown -= 1
        if @cooldown == 0
          @can_use_ability = true
        end
      end
    end
    move forces, section.get_obstacles(@x, @y), section.ramps if @active

    hit if section.projectile_hit?(self)
  end

  def do_warp(x, y)
    @speed.x = @speed.y = 0
    @x = x + 6; @y = y + 2
    @facing_right = true
    @indices = [0, 1, 0, 2]
    set_animation 0
  end

  def set_exploding
    @will_explode = true
    @explosion_timer = 0
    @explosion_counter = 10
  end

  def explode
    @will_explode = false
    @exploding = true
    @explosion_timer = 0
    @explosion.x = @x - 80
    @explosion.y = @y - 75
    set_animation 4
  end

  def explode?(obj)
    return false unless @exploding
    radius = @type == :verde ? 120 : 90
    c_x = @x + @w / 2; c_y = @y + @h / 2
    o_c_x = obj.x + obj.w / 2; o_c_y = obj.y + obj.h / 2
    sq_dist = (o_c_x - c_x)**2 + (o_c_y - c_y)**2
    sq_dist <= radius**2
  end

  def collide?(obj)
    bounds.intersect? obj.bounds
  end

  def over?(obj)
    @x + @w > obj.x and obj.x + obj.w > @x and
      @y + @h > obj.y and @y < obj.y - C::PLAYER_OVER_TOLERANCE
  end

  def hit(damage = 1)
    unless @invulnerable
      @hp -= damage
      @hp = 0 if @hp < 0
      if @hp == 0
        SB.player.die
        return
      end
      set_invulnerable
    end
  end

  def hp=(value)
    @hp = value
    @hp = @max_hp if @hp > @max_hp
  end

  def set_invulnerable(time = nil)
    @invulnerable = true
    @invulnerable_timer = 0
    @invulnerable_time = time || C::INVULNERABLE_TIME
  end

  def reset
    @will_explode = @exploding = @celebrating = @dying = false
    @speed.x = @speed.y = @stored_forces.x = @stored_forces.y = 0
    @hp = @max_hp
    @facing_right = true
  end

  def celebrate
    @celebrating = true
    @indices = [5, 6, 7]
    set_animation 5
  end

  def die
    @dying = true
    @speed.x = @speed.y = @stored_forces.x = @stored_forces.y = 0
    @indices = [8, 9, 10]
    set_animation 8
  end

  def is_visible(map)
    true
  end

  def draw(map)
    super map, 1, 1, 255, 0xffffff, nil, @facing_right ? nil : :horiz
    if @will_explode
      SB.font.draw_rel SB.text(:count_down), 400, 200, 0, 0.5, 0.5, 1, 1, 0xff000000 if @explosion_counter > 6
      SB.font.draw_rel @explosion_counter.to_s, 400, 220, 0, 0.5, 0.5, 1, 1, 0xff000000
    end
    @explosion.draw map if @exploding
  end
end
