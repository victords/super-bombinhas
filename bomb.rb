require 'minigl'

class Bomb < GameObject
  attr_reader :type, :name, :hp, :facing_right

  def initialize(type, hp)
    case type
    when :azul     then @name = 'Bomba Azul';     @def_hp = 1; @max_hp = 1;   l_img_gap = -10; r_img_gap = -10; t_img_gap = -6
    when :vermelha then @name = 'Bomba Vermelha'; @def_hp = 2; @max_hp = 999; l_img_gap = -4; r_img_gap = -6;   t_img_gap = -10
    when :amarela  then @name = 'Bomba Amarela';  @def_hp = 1; @max_hp = 1;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -10
    when :verde    then @name = 'Bomba Verde';    @def_hp = 2; @max_hp = 3;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -10
    else                @name = 'Aldan';          @def_hp = 1; @max_hp = 2;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -26
    end

    super -1000, -1000, 20, 30, "sprite_Bomba#{type.to_s.capitalize}", Vector.new(r_img_gap, t_img_gap), 6, 4
    @hp = hp == 0 ? @def_hp : hp
    @max_speed.x = 5
    @max_speed.y = 30
    @indices = [0, 1, 0, 2]
    @facing_right = true
    @ready = true
    @type = type

    @explosion = Sprite.new 0, 0, :fx_Explosion, 2, 2
    @explosion_timer = 0
    @explosion_counter = 10
  end

  def update(section)
    if @celebrating
      return if @img_index == (@facing_right ? 7 : 19)
      animate @indices, 8
      return
    elsif @dying
      return if @img_index == (@facing_right ? 10 : 22)
      animate @indices, 8
      return
    elsif @invulnerable
      @invulnerable_timer += 1
      @invulnerable = false if @invulnerable_timer == 120
    end

    SB.player.change_item if KB.key_pressed? Gosu::KbLeftShift or KB.key_pressed? Gosu::KbRightShift
    SB.player.use_item section if KB.key_pressed? Gosu::KbA

    forces = Vector.new 0, 0
    if @exploding
      @explosion.animate [0, 1, 2, 3], 5
      @explosion_counter += 1
      @exploding = false if @explosion_counter == 90
      forces.x -= 0.15 * @speed.x if @bottom and @speed.x != 0
    else
      if @will_explode
        @explosion_timer += 1
        if @explosion_timer == 60
          @explosion_counter -= 1
          explode if @explosion_counter == 0
          @explosion_timer = 0
        end
      end
      if KB.key_down? Gosu::KbLeft
        set_direction :left if @facing_right
        forces.x -= @bottom ? 0.4 : 0.05
      end
      if KB.key_down? Gosu::KbRight
        set_direction :right unless @facing_right
        forces.x += @bottom ? 0.4 : 0.05
      end
      if @bottom
        if @speed.x != 0
          animate @indices, 30 / @speed.x.abs
        elsif @facing_right
          set_animation 0
        else
          set_animation 12
        end
        if KB.key_pressed? Gosu::KbSpace
          forces.y -= 13.7 + 0.5 * @speed.x.abs
          if @facing_right; set_animation 3
          else; set_animation 15; end
        end
        forces.x -= @speed.x * 0.1
      end
    end
    move forces, section.get_obstacles(@x, @y), section.ramps
  end

  def set_direction(dir)
    if dir == :left
      @facing_right = false
      @indices = [12, 13, 12, 14]
      set_animation 12
    else
      @facing_right = true
      @indices = [0, 1, 0, 2]
      set_animation 0
    end
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
    set_animation(@facing_right ? 4 : 16)
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
      @invulnerable = true
      @invulnerable_timer = 0
    end
  end

  def reset
    @will_explode = @exploding = @celebrating = @dying = false
    @speed.x = @speed.y = 0
    @hp = @max_hp
    set_direction :right
  end

  def celebrate
    @celebrating = true
    @indices = (@facing_right ? [5, 6, 7] : [17, 18, 19])
    set_animation(@facing_right ? 5 : 17)
  end

  def die
    @dying = true
    @indices = (@facing_right ? [8, 9, 10] : [20, 21, 22])
    set_animation(@facing_right ? 8 : 20)
  end

  def is_visible(map)
    true
  end

  def draw(map)
    super map
    if @will_explode
      SB.font.draw_rel SB.text(:count_down), 400, 200, 0, 0.5, 0.5, 1, 1, 0xff000000 if @explosion_counter > 6
      SB.font.draw_rel @explosion_counter.to_s, 400, 220, 0, 0.5, 0.5, 1, 1, 0xff000000
    end
    @explosion.draw map if @exploding
  end
end
