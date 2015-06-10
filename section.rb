require 'minigl'
require_relative 'global'
require_relative 'elements'
require_relative 'enemies'
require_relative 'items'

Tile = Struct.new :back, :fore, :pass, :wall, :hide, :broken

class ScoreEffect
  def initialize(x, y, score)
    @x = x
    @y = y
    @text = score
    @alpha = 0
    @timer = 0
  end

  def dead?; @dead; end

  def update
    if @timer < 15
      @alpha += 17
    elsif @timer > 135
      @alpha -= 17
      @dead = true if @alpha == 0
    end
    @y -= 0.5
    @timer += 1
  end

  def draw(map)
    SB.small_text_helper.write_line @text, @x - map.cam.x, @y - map.cam.y, :center, 0xffffff, @alpha, :border, 0, 1, @alpha
  end
end

class Section
  ELEMENT_TYPES = [
    Attack1,
    Ball,
    BallReceptor,
    Bombie,
    Chamal,
    Chrazer,
    Crack,
    Door,
    Ekips,
    Electong,
    Elevator,
    Faller,
    FireRock,
    FixedSpikes,
    Fureel,
    Goal,
    GunPowder,
    Key,
    Life,
    MovingWall,
    Pin,
    Poison,
    Robort,
    SaveBombie,
    Spec,
    SpecGate,
    Spikes,
    Spring,
    Sprinny,
    Turner,
    Wheeliam,
    Yaw
  ]

  attr_reader :reload, :tiles, :obstacles, :ramps, :size, :default_entrance
  attr_accessor :entrance, :warp, :loaded, :locked_door

  def initialize(file, entrances, switches, taken_switches, used_switches)
    parts = File.read(file).chomp.split('#', -1)
    set_map_tileset parts[0].split ','
    set_bgs parts[1].split ','
    set_elements parts[2].split(';'), entrances, switches, taken_switches, used_switches
    set_ramps parts[3].split ';'
  end

  # initialization
  def set_map_tileset(s)
    t_x_count = s[0].to_i; t_y_count = s[1].to_i
    @tiles = Array.new(t_x_count) {
      Array.new(t_y_count) {
        Tile.new -1, -1, -1, -1, -1, false
      }
    }
    @border_exit = s[2].to_i # 0: top, 1: right, 2: down, 3: left, 4: none
    @tileset_num = s[3].to_i
    @tileset = Res.tileset s[3]
    @bgm = Res.song "s#{s[4]}"
    @map = Map.new C::TILE_SIZE, C::TILE_SIZE, t_x_count, t_y_count
    # @map.set_camera 4500, 1200
    @size = @map.get_absolute_size
  end

  def set_bgs(s)
    @bgs = []
    s.each do |bg|
      if File.exist?("#{Res.prefix}img/bg/#{bg}.png")
        @bgs << Res.img("bg_#{bg}", false, true)
      else
        @bgs << Res.img("bg_#{bg}", false, true, '.jpg')
      end
    end
  end

  def set_elements(s, entrances, switches, taken_switches, used_switches)
    x = 0; y = 0; s_index = switches.length
    @element_info = []
    @hide_tiles = []
    s.each do |e|
      if e[0] == '_'; x, y = set_spaces e[1..-1].to_i, x, y
      elsif e[3] == '*'; x, y = set_tiles e[4..-1].to_i, x, y, tile_type(e[0]), e[1, 2]
      else
        i = 0
        begin
          t = tile_type e[i]
          if t != :none
            set_tile x, y, t, e[i+1, 2]
          else
            if e[i] == '!'
              index = e[(i+1)..-1].to_i
              entrances[index] = {x: x * C::TILE_SIZE, y: y * C::TILE_SIZE, section: self, index: index}
              @default_entrance = index if e[-1] == '!'
            else
              t, a = element_type e[(i+1)..-1]
              if t != :none # teste poderá ser removido no final
                el = {x: x * C::TILE_SIZE, y: y * C::TILE_SIZE, type: t, args: a}
                if e[i] == '$'
                  if s_index == used_switches[0]
                    used_switches.shift
                    el[:state] = :used
                  elsif s_index == taken_switches[0]
                    taken_switches.shift
                    el[:state] = :taken
                  else
                    el[:state] = :normal
                  end
                  el[:section] = self
                  el[:index] = s_index
                  switches << el
                  s_index += 1
                else
                  @element_info << el
                end
              end           # teste poderá ser removido no final
            end
            i += 1000 # forçando e[i].nil? a retornar true
          end
          i += 3
        end until e[i].nil?
        x += 1
        begin y += 1; x = 0 end if x == @tiles.length
      end
    end
  end

  def tile_type(c)
    case c
      when 'b' then :back
      when 'f' then :fore
      when 'p' then :pass
      when 'w' then :wall
      when 'h' then :hide
      else :none
    end
  end

  def element_type(s)
    i = s.index ':'
    if i
      n = s[0..i].to_i
      args = s[(i+1)..-1]
    else
      n = s.to_i
      args = nil
    end
    type = ELEMENT_TYPES[n - 1]
    [type, args]
  end

  def set_spaces(amount, x, y)
    x += amount
    if x >= @tiles.length
      y += x / @tiles.length
      x %= @tiles.length
    end
    [x, y]
  end

  def set_tiles(amount, x, y, type, s)
    amount.times do
      set_tile x, y, type, s
      x += 1
      begin y += 1; x = 0 end if x == @tiles.length
    end
    [x, y]
  end

  def set_tile(x, y, type, s)
    @tiles[x][y].send "#{type}=", s.to_i
  end

  def set_ramps(s)
    @ramps = []
    s.each do |r|
      left = r[0] == 'l'
      w = r[1].to_i * C::TILE_SIZE
      h = r[2].to_i * C::TILE_SIZE
      coords = r.split(':')[1].split(',')
      x = coords[0].to_i * C::TILE_SIZE
      y = coords[1].to_i * C::TILE_SIZE
      @ramps << Ramp.new(x, y, w, h, left)
    end
  end
  #end initialization

  def start(switches, bomb_x, bomb_y)
    @elements = []
    @obstacles = [] #vetor de obstáculos não-tile
    @effects = []
    @locked_door = nil
    @reload = false
    @loaded = true

    @ball_receptors = []
    switches.each do |s|
      if s[:section] == self
        @elements << s[:obj]
      end
    end

    @element_info.each do |e|
      @elements << e[:type].new(e[:x], e[:y], e[:args], self)
    end

    index = 1
    @tiles.each_with_index do |v, i|
      v.each_with_index do |t, j|
        if t.hide == 0
          @hide_tiles << HideTile.new(i, j, index, @tiles, @tileset_num)
          index += 1
        elsif t.broken
          t.broken = false
        end
      end
    end

    @margin = MiniGL::Vector.new((C::SCREEN_WIDTH - SB.player.bomb.w) / 2, (C::SCREEN_HEIGHT - SB.player.bomb.h) / 2)
    do_warp bomb_x, bomb_y

    SB.play_song @bgm
  end

  def do_warp(x, y)
    SB.player.bomb.do_warp x, y
    @map.set_camera SB.player.bomb.x - @margin.x, SB.player.bomb.y - @margin.y
    @warp = nil
  end

  def get_obstacles(x, y)
    obstacles = []
    if x > @size.x - 4 * C::TILE_SIZE and @border_exit != 1
      obstacles << Block.new(@size.x, 0, 1, @size.y, false)
    end
    if x < 4 * C::TILE_SIZE and @border_exit != 3
      obstacles << Block.new(-1, 0, 1, @size.y, false)
    end

    i = (x / C::TILE_SIZE).round
    j = (y / C::TILE_SIZE).round
    ((i-2)..(i+2)).each do |k|
      ((j-2)..(j+2)).each do |l|
        if @tiles[k] and @tiles[k][l]
          if @tiles[k][l].pass >= 0
            obstacles << Block.new(k * C::TILE_SIZE, l * C::TILE_SIZE, C::TILE_SIZE, C::TILE_SIZE, true)
          elsif not @tiles[k][l].broken and @tiles[k][l].wall >= 0
            obstacles << Block.new(k * C::TILE_SIZE, l * C::TILE_SIZE, C::TILE_SIZE, C::TILE_SIZE, false)
          end
        end
      end
    end

    @obstacles.each do |o|
#      if o.x > x - 2 * C::TileSize and o.x < x + 2 * C::TileSize and
#         o.y > y - 2 * C::TileSize and o.y < y + 2 * C::TileSize
        obstacles << o
#      end
    end

    obstacles
  end

  def obstacle_at?(x, y)
    i = x / C::TILE_SIZE
    j = y / C::TILE_SIZE
    @tiles[i] and @tiles[i][j] and not @tiles[i][j].broken and @tiles[i][j].pass + @tiles[i][j].wall >= 0
  end

  def get_next_ball_receptor
    SB.stage.switches.each do |s|
      if s[:section] == self && s[:type] == BallReceptor && s[:state] == :taken && !@ball_receptors.include?(s[:index])
        @ball_receptors << s[:index]
        return s[:obj]
      end
    end
    nil
  end

  def projectile_hit?(obj)
    @elements.each do |e|
      if e.is_a? Projectile
        if e.bounds.intersect? obj.bounds
          @elements.delete e
          return true
        end
      end
    end
    false
  end

  def add(element)
    @elements << element
  end

  def add_score_effect(x, y, score)
    @effects << ScoreEffect.new(x, y, score)
  end

  def save_check_point(id, obj)
    @entrance = id
    SB.stage.set_switch obj
    SB.stage.save_switches
  end

  def unlock_door
    if @locked_door
      @locked_door.unlock
      SB.stage.set_switch @locked_door
      return true
    end
    false
  end

  def open_wall(id)
    @elements.each do |e|
      if e.class == MovingWall and e.id == id
        e.open
        break
      end
    end
  end

  def set_fixed_camera(x, y)
    @map.set_camera x, y
    @fixed_camera = true
  end

  def unset_fixed_camera
    @fixed_camera = false
  end

  def finish
    @finished = true
  end

  def update
    @locked_door = nil
    @elements.each do |e|
      e.update self if e.is_visible @map
      @elements.delete e if e.dead?
    end
    @effects.each do |e|
      e.update
      @effects.delete e if e.dead?
    end
    @hide_tiles.each do |t|
      t.update self if t.is_visible @map
    end

    unless @fixed_camera
      SB.player.bomb.update(self)

      if SB.player.dead?
        @reload = true if KB.key_pressed? Gosu::KbReturn
        return
      end

      if @finished
        return :finish
      elsif @border_exit == 0 && SB.player.bomb.y + SB.player.bomb.h <= -C::EXIT_MARGIN ||
            @border_exit == 1 && SB.player.bomb.x >= @size.x - C::EXIT_MARGIN ||
            @border_exit == 2 && SB.player.bomb.y >= @size.x + C::EXIT_MARGIN ||
            @border_exit == 3 && SB.player.bomb.x + SB.player.bomb.w <= C::EXIT_MARGIN
        return :next_section
      elsif @border_exit != 2 && SB.player.bomb.y >= @size.x + C::EXIT_MARGIN # abismo
        SB.player.die
        return
      end

      @map.set_camera (SB.player.bomb.x - @margin.x).round, (SB.player.bomb.y - @margin.y).round
      if KB.key_pressed? Gosu::KbEscape
        SB.state = :paused
      end
    end
  end

  def draw
    draw_bgs

    @map.foreach do |i, j, x, y|
      @tileset[@tiles[i][j].back].draw x, y, 0 if @tiles[i][j].back >= 0
      @tileset[@tiles[i][j].pass].draw x, y, 0 if @tiles[i][j].pass >= 0
      @tileset[@tiles[i][j].wall].draw x, y, 0 if @tiles[i][j].wall >= 0 and not @tiles[i][j].broken
    end

    @elements.each do |e|
      e.draw @map if e.is_visible @map
    end
    @effects.each do |e|
      e.draw @map
    end
    SB.player.bomb.draw @map

    @map.foreach do |i, j, x, y|
      @tileset[@tiles[i][j].fore].draw x, y, 0 if @tiles[i][j].fore >= 0
    end

    @hide_tiles.each do |t|
      t.draw @map if t.is_visible @map
    end
  end

  def draw_bgs
    @bgs.each_with_index do |bg, ind|
      back_x = -@map.cam.x * 0.9 + ind * 0.1; back_y = -@map.cam.y * 0.9 + ind * 0.1
      tiles_x = @size.x / bg.width; tiles_y = @size.y / bg.height
      (1..tiles_x-1).each do |i|
        if back_x + i * bg.width > 0
          back_x += (i - 1) * bg.width
          break
        end
      end
      (1..tiles_y-1).each do |i|
        if back_y + i * bg.height > 0
          back_y += (i - 1) * bg.height
          break
        end
      end
      first_back_y = back_y
      while back_x < C::SCREEN_WIDTH
        while back_y < C::SCREEN_HEIGHT
          bg.draw back_x, back_y, 0
          back_y += bg.height
        end
        back_x += bg.width
        back_y = first_back_y
      end
    end
  end
end
