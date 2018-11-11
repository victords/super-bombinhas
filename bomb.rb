require 'minigl'

class Bomb < GameObject
  attr_reader :type, :name, :hp, :saved_hp, :facing_right, :can_use_ability, :will_explode
  attr_accessor :active, :power, :slipping

  def initialize(type, hp)
    case type
    when :azul     then @name = 'Bomba Azul';     @def_hp = 1; @max_hp = 1;   l_img_gap = -10; r_img_gap = -10; t_img_gap = -5
    when :vermelha then @name = 'Bomba Vermelha'; @def_hp = 2; @max_hp = 999; l_img_gap = -4; r_img_gap = -6;   t_img_gap = -11
    when :amarela  then @name = 'Bomba Amarela';  @def_hp = 1; @max_hp = 1;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -22
    when :verde    then @name = 'Bomba Verde';    @def_hp = 2; @max_hp = 3;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -11
    else                @name = 'Aldan';          @def_hp = 1; @max_hp = 2;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -27
    end

    super -1000, -1000, 20, 27, "sprite_Bomba#{type.to_s.capitalize}", Vector.new(r_img_gap, t_img_gap), 6, 2
    @hp = hp == 0 ? @def_hp : hp
    @saved_hp = @hp
    @max_speed_x = type == :amarela ? 6 : 4
    @max_speed_x_sq = @max_speed_x ** 2
    @max_speed.y = 15
    @jump_speed = 0.045
    @jump_frames = 0
    @facing_right = true
    @active = true
    @type = type
    @power = 1

    @explosion = Sprite.new(0, 0, :fx_Explosion, 2, 2)
    @explosion_timer = 0
    @explosion_counter = 10

    @aura_fx = Sprite.new(0, 0, :fx_aura, 2, 1)

    @can_use_ability = true
  end

  def update(section)
    forces = Vector.new 0, 0
    if @dying
      animate [9, 10, 11], 8 unless @img_index == 11
    elsif @exploding
      animate [6, 7], 5
      @explosion.animate [0, 1, 2, 3], 5
      @explosion_counter += 1
      @exploding = false if @explosion_counter == 90
      forces.x -= 0.3 * @speed.x if @bottom and @speed.x != 0
    elsif @active
      if @invulnerable
        @invulnerable_timer += 1
        @invulnerable = false if @invulnerable_timer == @invulnerable_time
      end
      if @aura
        @aura_fx.animate([0, 1], 5)
        @aura_timer += 1
        if @aura_timer == @aura_duration
          @power = 1
          @aura = false
        end
      end
      if @will_explode
        @explosion_timer += 1
        if @explosion_timer == 60
          @explosion_counter -= 1
          explode if @explosion_counter == 0
          @explosion_timer = 0
        end
      end
      if KB.key_down? SB.key[:left]
        @facing_right = false
        forces.x -= @slipping ? 0.15 : 0.4
      end
      if KB.key_down?(SB.key[:right])
        @facing_right = true
        forces.x += @slipping ? 0.15 : 0.4
      end
      if @bottom
        if @speed.x != 0
          animate [2, 3, 4, 3], 30 / @speed.x.abs
        else
          animate [0, 1], 10
        end
        @jump_frames = 0
      else
        @jump_frames += 1 if @jump_frames < 30
      end
      if @jump_frames == 0 && KB.key_pressed?(SB.key[:jump]) || @jump_frames > 0 && KB.key_down?(SB.key[:jump])
        forces.y -= (1.31 + @jump_speed * @speed.x.abs) / (0.3 * @jump_frames + 0.33) - 0.1
        set_animation 5
      end
      SB.player.change_item if KB.key_pressed? SB.key[:next]
      SB.player.use_item section if KB.key_pressed? SB.key[:item]

      if @can_use_ability
        if KB.key_pressed? SB.key[:ab]
          if @type == :verde
            explode(false); @can_use_ability = false; @cooldown = C::EXPLODE_COOLDOWN
          elsif @type == :branca
            SB.stage.stop_time; @can_use_ability = false; @cooldown = C::STOP_TIME_COOLDOWN
          end
        end
      else
        @cooldown -= 1
        if @cooldown == 0
          @can_use_ability = true
        end
      end

      hit if section.projectile_hit?(self)
    end

    friction_factor = @slipping ? @speed.x**2 / @max_speed_x_sq : @speed.x.abs / @max_speed_x
    friction_factor = 1 if friction_factor > 1
    friction_factor = -1 if friction_factor < -1
    forces.x -= (@slipping ? 0.15 : 0.4) * friction_factor * (@speed.x <=> 0)
    move forces, section.get_obstacles(@x, @y), section.ramps if @active
    @slipping = false
  end

  def do_warp(x, y)
    @speed.x = @speed.y = 0
    @x = x + C::TILE_SIZE / 2 - @w / 2; @y = y + C::TILE_SIZE - @h
    @facing_right = true
    set_animation 0
  end

  def set_exploding(time)
    @will_explode = true
    @explosion_timer = 0
    @explosion_counter = time
  end

  def explode(gun_powder = true)
    @will_explode = false
    @exploding = true
    @explosion_timer = 0
    @explosion_radius = if gun_powder
                          @type == :verde ? 135 : 90
                        else
                          90
                        end
    @explosion.x = @x + @w / 2 - @explosion_radius
    @explosion.y = @y + @h / 2 - @explosion_radius
    set_animation 6
  end

  def explode?(obj)
    return false unless @exploding
    c_x = @x + @w / 2; c_y = @y + @h / 2
    o_c_x = obj.x + obj.w / 2; o_c_y = obj.y + obj.h / 2
    sq_dist = (o_c_x - c_x)**2 + (o_c_y - c_y)**2
    sq_dist <= (obj.is_a?(Chamal) ? @explosion_radius * 1.25 : @explosion_radius)**2
  end

  def collide?(obj)
    bounds.intersect? obj.bounds
  end

  def over?(obj)
    tolerance = @speed.y > C::PLAYER_OVER_TOLERANCE ? @speed.y : C::PLAYER_OVER_TOLERANCE
    @x + @w > obj.x and obj.x + obj.w > @x and
      @y + @h > obj.y and @y + @h <= obj.y + tolerance
  end

  def bounce
    @speed.y = -(C::BOUNCE_SPEED_BASE + (@speed.y / @max_speed.y) * C::BOUNCE_SPEED_INCREMENT)
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

  def save_hp
    @saved_hp = @hp
  end

  def set_invulnerable(time = nil)
    @invulnerable = true
    @invulnerable_timer = 0
    @invulnerable_time = time || C::INVULNERABLE_TIME
  end

  def set_aura(power, duration)
    @power = power
    @aura = true
    @aura_timer = 0
    @aura_duration = duration
  end

  def reset(loaded = false)
    @will_explode = @exploding = @aura = @celebrating = @dying = false
    @speed.x = @speed.y = @stored_forces.x = @stored_forces.y = 0
    if loaded; @hp = @saved_hp
    else; @saved_hp = @hp = @def_hp; end
    @active = @facing_right = true
  end

  def celebrate
    @celebrating = true
    set_animation 8
  end

  def die
    @dying = true
    set_animation 9
    stop
  end

  def stop
    @speed.x = @speed.y = @stored_forces.x = @stored_forces.y = 0
  end

  def is_visible(map)
    true
  end

  def draw(map)
    super(map, 2, 2, 255, 0xffffff, nil, @facing_right ? nil : :horiz) unless @invulnerable && @invulnerable_timer % 6 < 3
    if @aura
      @aura_fx.x = @x - 10; @aura_fx.y = @y - 30
      @aura_fx.draw(map, 2, 2)
    end
    if @will_explode && !SB.player.dead?
      SB.text_helper.write_line SB.text(:count_down), 400, 200, :center, 0xffffff, 255, :border, 0, 1, 255, 1 if @explosion_counter > 6
      SB.text_helper.write_line @explosion_counter.to_s, 400, 220, :center, 0xffffff, 255, :border, 0, 1, 255, 1
    end
    @explosion.draw map, 2 * @explosion_radius.to_f / 90, 2 * @explosion_radius.to_f / 90 if @exploding
  end
end
