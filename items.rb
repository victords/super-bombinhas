############################### classes abstratas ##############################

module Item
  attr_reader :icon

  def check(switch)
    if switch[:state] == :taken
      SB.player.add_item switch
      switch[:obj] = self
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
      use section, info
      info[:state] = :temp_taken_used
    end
  end

  def set_switch(switch)
    if switch[:state] == :temp_taken
      switch[:state] = :temp_taken_used
    else
      switch[:state] = :temp_used
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
    super x + 2, y + 2, 28, 28, :sprite_Life, nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
  end

  def update(section)
    super(section) do
      take section, false
    end
  end

  def use(section, switch)
    SB.player.lives += 1
    set_switch(switch)
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

  def use(section, switch)
    obj = section.active_object
    if obj.is_a? Door and obj.locked
      obj.unlock
      SB.stage.set_switch obj
      set_switch(switch)
    end
  end
end

class Attack1 < FloatingItem
  include Item

  def initialize(x, y, args, section, switch)
    set_icon :Attack1
    return if check switch
    super x + 2, y + 2, 28, 28, :sprite_Attack1, nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, :azul
  end

  def update(section)
    super(section) do
      take section, true
    end
  end

  def use(section, switch)
    b = SB.player.bomb
    return false if b.type != @type
    if b.facing_right; angle = 0
    else; angle = Math::PI; end
    section.add Projectile.new(b.x, b.y, 1, angle, b)
    set_switch(switch)
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
    super x + 2, y + 2, 28, 28, "sprite_heart#{args}", nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, bomb
  end

  def update(section)
    super(section) do
      SB.player.bomb.hp += 1
    end
  end
end

class BoardItem < FloatingItem
  include Item

  def initialize(x, y, args, section, switch)
    set_icon :board
    return if check switch
    super x + 6, y + 3, 20, 26, :sprite_boardItem, Vector.new(-6, -3)
    @item = true
  end

  def update(section)
    super(section) do
      take section, true
    end
  end

  def use(section, switch)
    b = SB.player.bomb
    @board = Board.new(b.x + (b.facing_right ? 0 : b.w - 50), b.y + b.h - 2, b.facing_right, section, switch)
    section.add(@board)
    switch[:state] = :normal
  end
end

class Hammer < FloatingItem
  include Item

  def initialize(x, y, args, section, switch)
    set_icon :hammer
    return if check(switch)
    super x + 7, y + 1, 18, 30, :sprite_hammer, Vector.new(-7, -1)
  end

  def update(section)
    super(section) do
      take section, true
    end
  end

  def use(section, switch)
    obj = section.active_object
    if obj.is_a? Board
      obj.take(section)
      set_switch(switch)
    end
  end
end

class Spring < GameObject
  include Item

  def initialize(x, y, args, section, switch)
    @switch = switch
    set_icon :spring
    return if check(switch)
    super x, y, 32, 32, :sprite_Spring, Vector.new(-2, -16), 3, 2
    @active_bounds = Rectangle.new x, y - 16, 32, 48
    @start_y = y
    @state = 0
    @timer = 0
    @indices = [0, 4, 4, 5, 0, 5, 0, 5, 0, 5]
    @passable = true
    @ready = false
  end

  def update(section)
    unless @ready
      section.obstacles << self
      @ready = true
    end
    if SB.player.bomb.bottom == self
      reset if @state == 4
      @timer += 1
      if @timer == 10
        case @state
          when 0 then @y += 8; @img_gap.y -= 8; SB.player.bomb.y += 8
          when 1 then @y += 6; @img_gap.y -= 6; SB.player.bomb.y += 6
          when 2 then @y += 4; @img_gap.y -= 4; SB.player.bomb.y += 4
        end
        @state += 1
        if @state == 4
          SB.player.bomb.stored_forces.y = -18
        else
          set_animation @state
        end
        @timer = 0
      end
    elsif SB.player.bomb.collide?(self) and KB.key_pressed?(Gosu::KbUp)
      take(section, true)
      @dead = true
      section.obstacles.delete self
    elsif @state > 0 and @state < 4
      reset
    end

    if @state == 4
      animate @indices, 7
      @timer += 1
      if @timer == 70
        reset
      elsif @timer == 7
        @y = @start_y
        @img_gap.y = -16
      end
    end
  end

  def reset
    set_animation 0
    @state = @timer = 0
    @y = @start_y
    @img_gap.y = -16
  end

  def use(section, switch)
    b = SB.player.bomb
    x = b.facing_right ? b.x + b.w : b.x - @w
    return false if section.obstacle_at?(x, b.y)
    switch[:state] = :normal
    spring = Spring.new(x, b.y, nil, section, @switch)
    switch[:obj] = spring
    section.add spring
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
