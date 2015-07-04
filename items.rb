############################### classes abstratas ##############################

module Item
  attr_reader :icon

  def check(switch)
    if switch[:state] == :taken
      SB.player.add_item switch
      return true
    elsif switch[:state] == :used
      return true
    end
    false
  end

  def set_icon(type)
    @icon = Res.img "icon_#{type}"
  end

  def take(section, store)
    info = SB.stage.find_switch self
    if store
      SB.player.add_item info
      info[:state] = :temp_taken
    else
      use section
      info[:state] = :temp_taken_used
    end
  end
end

class FloatingItem < GameObject
  def initialize(x, y, w, h, img, img_gap = nil, sprite_cols = nil, sprite_rows = nil, indices = nil, interval = nil, type = nil)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
    img_gap = Vector.new(0, 0) if img_gap.nil?
    @active_bounds = Rectangle.new x + img_gap.x, y - img_gap.y, @img[0].width, @img[0].height
    @state = 3
    @counter = 0
    @indices = indices
    @interval = interval
    @type = type
  end

  def update(section)
    if SB.player.bomb.collide?(self) and (@type.nil? or SB.player.bomb.type == @type)
      yield
      @dead = true
      return
    end
    @counter += 1
    if @counter == 10
      if @state == 0 or @state == 1; @y -= 1
      else; @y += 1; end
      @state += 1
      @state = 0 if @state == 4
      @counter = 0
    end
    animate @indices, @interval if @indices
  end
end

################################################################################

class FireRock < FloatingItem
  def initialize(x, y, args, section)
    super x + 6, y + 7, 20, 20, :sprite_FireRock, Vector.new(-2, -17), 4, 1, [0, 1, 2, 3], 5
  end

  def update(section)
    super(section) do
      SB.player.stage_score += 10
    end
  end
end

class Life < FloatingItem
  include Item

  def initialize(x, y, args, section, switch)
    return if check switch
    super x + 2, y + 2, 26, 26, :sprite_Life, nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
  end

  def update(section)
    super(section) do
      take section, false
    end
  end

  def use(section)
    SB.player.lives += 1
    true
  end
end

class Key < FloatingItem
  include Item

  def initialize(x, y, args, section, switch)
    set_icon :Key
    return if check switch
    super x + 3, y + 3, 26, 26, :sprite_Key, Vector.new(-3, -3)
  end

  def update(section)
    super(section) do
      take section, true
    end
  end

  def use(section)
    section.unlock_door
  end
end

class Attack1 < FloatingItem
  include Item

  def initialize(x, y, args, section, switch)
    set_icon :Attack1
    return if check switch
    super x + 2, y + 2, 26, 26, :sprite_Attack1, nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, :azul
  end

  def update(section)
    super(section) do
      take section, true
    end
  end

  def use(section)
    if SB.player.bomb.facing_right; angle = 0
    else; angle = Math::PI; end
    section.add Projectile.new SB.player.bomb.x, SB.player.bomb.y, 1, angle
    true
  end
end

class Heart < FloatingItem
  def initialize(x, y, args, section)
    args = (args || '1').to_i
    bomb = case args
           when 1 then :vermelha
           when 2 then :verde
           when 3 then :branca
           end
    super x + 2, y + 2, 26, 26, "sprite_heart#{args}", nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, bomb
  end

  def update(section)
    super(section) do
      SB.player.bomb.hp += 1
    end
  end
end

class Spec < FloatingItem
  def initialize(x, y, args, section)
    return if SB.player.specs.index(SB.stage.id)
    super x - 1, y - 1, 34, 34, :sprite_Spec, Vector.new(-12, -12), 2, 2, [0,1,2,3], 5
  end

  def update(section)
    super(section) do
      SB.player.stage_score += 1000
      SB.set_spec_taken
    end
  end
end
