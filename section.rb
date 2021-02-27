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
require_relative 'global'
require_relative 'elements'
require_relative 'enemies'
require_relative 'items'

Tile = Struct.new :back, :fore, :pass, :wall, :hide, :broken, :ramp_end, :obj, :code

class ScoreEffect
  attr_reader :dead

  def initialize(x, y, score, life = false)
    @x = x
    @y = y
    @text = life ? "+#{score}" : score.to_s
    @color = life ? 0x00ff00 : 0xffffff
    @scale = life && score > 1 ? 3 : 1.5
    @alpha = 0
    @timer = 0
  end

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

  def draw(map, scale_x, scale_y)
    SB.text_helper.write_line(@text, @x - map.cam.x, @y - map.cam.y, :center, @color, @alpha, :border, 0, @scale / 1.5, @alpha, 0, @scale, @scale)
  end
end

class Section
  ELEMENT_TYPES = {
    1   => FireRock,
    2   => Graphic,
    3   => Wheeliam,
    4   => Life,
    5   => FixedSpikes,
    6   => Ekips,
    7   => Star,
    8   => Door,
    9   => SaveBombie,
    10  => Attack1,
    11  => Key,
    12  => Shield,
    13  => Elevator,
    14  => Sprinny,
    15  => Spec,
    16  => Goal,
    17  => Spikes,
    18  => Electong,
    19  => GunPowder,
    20  => Crack,
    21  => Pin,
    22  => Faller,
    23  => Turner,
    24  => Poison,
    25  => Vortex,
    26  => Chrazer,
    27  => BoardItem,
    28  => Fureel,
    29  => Hammer,
    30  => Yaw,
    31  => Robort,
    32  => Ball,
    33  => BallReceptor,
    34  => MovingWall,
    35  => Chamal,
    36  => Branch,
    37  => Shep,
    38  => Heart,
    39  => Flep,
    40  => Spring,
    41  => Water,
    42  => Jellep,
    43  => Rock,
    44  => Vamep,
    45  => Monep,
    46  => Snep,
    47  => Herb,
    48  => Owlep,
    49  => Attack2,
    50  => Bombie,
    51  => Armep,
    52  => Stalactite,
    53  => FragileFloor,
    54  => Butterflep,
    55  => Zep,
    56  => Crusher,
    57  => ForceField,
    58  => Boulder,
    59  => StalactiteGenerator,
    60  => Sahiss,
    61  => Forsby,
    62  => Stilty,
    63  => Ignel,
    64  => Attack3,
    65  => Box,
    66  => AButton,
    67  => Warclops,
    68  => Mantul,
    69  => Lambul,
    70  => WindMachine,
    71  => MountainBombie,
    72  => JillisStone,
    73  => TwinWalls,
    74  => Icel,
    75  => IcyFloor,
    76  => Necrul,
    77  => Ulor,
    78  => Umbrex,
    79  => Quartin,
    80  => FallingWall,
    81  => Lift,
    82  => Xylophob,
    83  => Bardin,
    84  => Dynamike,
    85  => Puzzle,
    86  => PuzzlePiece,
    87  => Hooman,
    88  => Bell,
    89  => Gargoil,
    90  => Zirkn,
    91  => Pantan,
    92  => Frock,
    93  => AirMattress,
    94  => ThornyPlant,
    95  => Kraklet,
    96  => Attack4,
    97  => PoisonGas,
    98  => SideSpring,
    99  => Pikey,
    100 => Gars,
    101 => Nest,
    102 => Zingz,
    103 => Globb,
    104 => Bombark,
    105 => Vamdark,
    106 => Aldan,
    107 => StickyFloor,
    108 => Hourglass,
    109 => HeatBomb,
    110 => Masstalactite,
    111 => Luminark,
    112 => ToxicDrop,
    113 => Drepz,
    114 => Bombinfant,
    115 => Bombarcher,
    116 => Attack5,
    117 => SpikeBall,
    118 => Bombnight,
    119 => SeekBomb,
    120 => Cannon,
    121 => Bombaladin,
    122 => Bomblancer,
    123 => Gate,
    124 => BattleArena,
    125 => Gaxlon,
    126 => SpecPlatform,
    127 => SpecGate,
  }

  attr_reader :reload, :tiles, :obstacles, :ramps, :passengers, :size, :default_entrance, :warp, :tileset_num, :map, :bgm, :fixed_camera
  attr_accessor :entrance, :loaded, :active_object

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
        Tile.new
      }
    }
    @border_exit = s[2].to_i # 0: top, 1: right, 2: down, 3: left, 4: none
    @tileset_num = s[3].to_i
    @tileset = Res.tileset s[3], 16, 16
    @bgm = s[4]
    @map = Map.new C::TILE_SIZE, C::TILE_SIZE, t_x_count, t_y_count
    @size = @map.get_absolute_size
    @dark = s[5] && s[5] == '.'
    if s[5] && s[5] == '$'
      @rain = Res.img(:fx_rain)
      @rain_offset = Vector.new(0, 0)
    end
  end

  def set_bgs(s)
    @bgs = []
    @repeat_bg_y = true
    s.each do |bg|
      if bg.end_with?('!')
        @repeat_bg_y = false
        bg = bg[0..-2]
      end
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
    @passengers = [SB.player.bomb]
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
              el = {x: x * C::TILE_SIZE, y: y * C::TILE_SIZE, type: t, args: a}
              if t.instance_method(:initialize).parameters.length == 5
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
    type = ELEMENT_TYPES[n]
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
      a = r[1] == "'" ? 2 : 1
      rw = r[a].to_i
      w = rw * C::TILE_SIZE
      h = r[a + 1].to_i * C::TILE_SIZE
      h -= 1 if r[1] == "'"
      coords = r.split(':')[1].split(',')
      i = coords[0].to_i
      j = coords[1].to_i
      x = i * C::TILE_SIZE
      y = j * C::TILE_SIZE
      @ramps << Ramp.new(x, y, w, h, left)
      @tiles[i + (left ? rw : -1)][j].ramp_end = true
    end
  end
  #end initialization

  def start(switches, bomb_x, bomb_y)
    @elements = []
    @inter_elements = [] # array of objects that can interact with other objects
    @obstacles = [] # array of obstacles that are not wall tiles
    @light_tiles = [] # array of tiles that receive light (for dark sections)
    @effects = []
    @reload = false
    @loaded = true
    @dead_timer = 0

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
        elsif t.hide == 99
          @hide_tiles << Fog.new(i, j, @tiles)
        elsif t.broken
          t.broken = false
        end
      end
    end
    @tile_timer = 0
    @tile_3_index = 0
    @tile_4_index = 0

    @margin = Vector.new(@map.cam.w / 2, @map.cam.h / 2)
    do_warp bomb_x, bomb_y

    SB.play_song @bgm
  end

  def do_warp(x, y)
    bomb = SB.player.bomb
    bomb.do_warp x, y
    bomb.active = true
    @camera_timer = 0
    @camera_moving = false
    @camera_ref_pos = Vector.new(bomb.x + bomb.w / 2, bomb.y + bomb.h / 2)
    update_camera
    update_passengers
    @warp = nil
  end

  def start_warp(entrance)
    @warp = entrance
    SB.player.bomb.active = false
  end

  def update_camera
    @map.set_camera(@camera_ref_pos.x - @margin.x, @camera_ref_pos.y - @margin.y)
  end

  def get_obstacles(x, y, w = 0, h = 0)
    obstacles = []
    if x > @size.x - 4 * C::TILE_SIZE and @border_exit != 1
      obstacles << Block.new(@size.x, 0, 1, @size.y, false)
    end
    if x < 4 * C::TILE_SIZE and @border_exit != 3
      obstacles << Block.new(-1, 0, 1, @size.y, false)
    end

    @obstacles.each do |o|
      obstacles << o
    end

    offset_x = offset_y = 2
    if w > 0
      x += w / 2
      offset_x = w / 64 + 2
    end
    if h > 0
      y += h / 2
      offset_y = h / 64 + 2
    end

    i = (x / C::TILE_SIZE).round
    j = (y / C::TILE_SIZE).round
    ((j-offset_y)..(j+offset_y)).each do |l|
      next if l < 0
      bw = 0
      pass = false
      ((i-offset_x)..(i+offset_x)).each do |k|
        next if k < 0
        if @tiles[k] and @tiles[k][l]
          if @tiles[k][l].pass
            if bw > 0 && !pass
              add_block(obstacles, k - bw, l, bw, false)
              bw = 0
            end
            bw += 1
            pass = true
          elsif not @tiles[k][l].broken and @tiles[k][l].wall
            if @tiles[k][l].ramp_end
              add_block(obstacles, k - bw, l, bw, pass) if bw > 0
              add_block(obstacles, k, l, 1, true)
              add_block(obstacles, k, l, 1, false, C::TILE_SIZE / 2)
              bw = -1
            elsif bw > 0 && pass
              add_block(obstacles, k - bw, l, bw, true)
              bw = 0
            end
            bw += 1
            pass = false
          elsif bw > 0
            add_block(obstacles, k - bw, l, bw, pass)
            bw = 0
          end
        end
      end
      if bw > 0
        k = i + offset_x >= @map.size.x ? @map.size.x : i + offset_x + 1
        add_block(obstacles, k - bw, l, bw, pass)
      end
    end

    obstacles
  end

  def add_block(list, i, j, w_t, pass, y_off = 0)
    list << Block.new(i * C::TILE_SIZE, j * C::TILE_SIZE + y_off, w_t * C::TILE_SIZE, C::TILE_SIZE - y_off, pass)
  end

  def obstacle_at?(x, y)
    i = x / C::TILE_SIZE
    j = y / C::TILE_SIZE
    return true if @tiles[i] && @tiles[i][j] && (@tiles[i][j].pass || @tiles[i][j].wall) && !@tiles[i][j].broken
    @obstacles.each do |o|
      return true if x >= o.x && x < o.x + o.w && y >= o.y && y < o.y + o.h
    end
    false
  end

  def add_interacting_element(el)
    @inter_elements << el
  end

  def remove_interacting_element(el)
    @inter_elements.delete(el)
  end

  def element_at(type, x, y)
    @inter_elements.each do |e|
      if e.is_a? type and x >= e.x and x < e.x + e.w and y >= e.y and y < e.y + e.h
        return e
      end
    end
    nil
  end

  def projectile_hit?(obj)
    bounds = obj.respond_to?(:bounds) ? obj.bounds : obj
    @elements.each do |e|
      if e.is_a? Projectile
        if e.owner != obj && e.bounds.intersect?(bounds)
          @elements.delete e
          return e.type
        end
      end
    end
    false
  end

  def explode?(obj)
    o_c_x = obj.x + obj.w / 2; o_c_y = obj.y + obj.h / 2
    @effects.each do |e|
      if e.is_a?(Explosion) && e.owner != obj
        sq_dist = (o_c_x - e.c_x)**2 + (o_c_y - e.c_y)**2
        return true if sq_dist <= e.radius**2
      end
    end
    false
  end

  def add(element)
    @elements << element
  end

  def add_effect(e)
    @effects << e
    e
  end

  def add_score_effect(x, y, score)
    add_effect ScoreEffect.new(x, y, score)
  end

  def add_light_tiles(tiles, x, y, w, h)
    t_x = (x + w / 2 - @map.cam.x).floor / C::TILE_SIZE
    t_y = (y + h / 2 - @map.cam.y).floor / C::TILE_SIZE
    @light_tiles += tiles.map { |t| [t_x + t[0], t_y + t[1], t[2]] }.select { |t| t[0] >= 0 && t[1] >= 0 && t[0] < 25 && t[1] < 19 }
  end

  def save_check_point(id, obj)
    @entrance = id
    SB.stage.set_switch obj
    SB.stage.save_switches
    SB.player.save_bomb_hps
  end

  def activate_object(type, id, arg = nil)
    @elements.each do |e|
      if e.class == type && e.id == id
        e.activate(self, arg)
        break
      end
    end
  end

  def update_passengers
    @passengers.delete_at(0)
    @passengers.insert(0, SB.player.bomb)
  end

  def set_fixed_camera(x, y)
    @camera_target_pos = Vector.new(x, y)
    @fixed_camera = true
    SB.player.bomb.active = false
    SB.stage.stop_time(1_000_000_000, false)
  end

  def unset_fixed_camera
    @fixed_camera = false
    SB.player.bomb.active = true unless SB.player.bomb.in_vortex
    SB.stage.resume_time
  end

  def finish
    @finished = true
    SB.player.bomb.active = false
    SB.player.bomb.celebrate
  end

  def update(stopped)
    bomb = SB.player.bomb
    bomb.poisoned = false

    enemy_count = 0
    fire_rock_count = 0
    @light_tiles.clear
    @elements.reverse_each do |e|
      is_enemy = e.is_a?(Enemy) || e.is_a?(Ekips) || e.is_a?(Faller) || e.is_a?(Kraklet)
      e.update(self) if e.is_visible(@map) && ((stopped != :all && (stopped != :enemies || !is_enemy)) || is_enemy && e.dying || e.stop_time_immune?)
      if e.dead?
        @elements.delete(e)
      else
        enemy_count += 1 if is_enemy
        fire_rock_count += 1 if e.is_a?(FireRock)
      end
    end
    @effects.each do |e|
      e.update
      @effects.delete e if e.dead
    end
    @hide_tiles.each do |t|
      t.update self if t.is_visible @map
    end

    unless @fixed_camera
      @camera_target_pos = Vector.new(bomb.x + bomb.w / 2, bomb.y + bomb.h / 2)
      @camera_target_pos.y += @camera_offset if @camera_offset
    end
    d_x = @camera_target_pos.x - @camera_ref_pos.x
    d_y = @camera_target_pos.y - @camera_ref_pos.y
    should_move_x = d_x.abs > 0.5
    moved_y = false

    if should_move_x
      @camera_ref_pos.x += (@fixed_camera ? 0.1 : C::CAMERA_HORIZ_SPEED) * d_x
    end

    d_y_abs = d_y.abs
    if @camera_moving
      if d_y_abs >= C::CAMERA_VERTICAL_MIN
        @camera_ref_pos.y += C::CAMERA_VERTICAL_SPEED * d_y * [d_y_abs.to_f / C::CAMERA_VERTICAL_TOLERANCE, 1].max
        moved_y = true
      else
        @camera_moving = false
        @camera_timer = 0
      end
    elsif d_y_abs > C::CAMERA_VERTICAL_TOLERANCE
      if d_y_abs >= C::CAMERA_VERTICAL_LIMIT
        @camera_timer = C::CAMERA_VERTICAL_DELAY
      else
        @camera_timer += 1
      end
      if @camera_timer >= C::CAMERA_VERTICAL_DELAY
        @camera_moving = true
      end
    else
      @camera_timer = 0
    end

    update_camera if should_move_x || moved_y

    bomb.update(self)
    SB.player.update_timers

    @camera_offset = nil
    unless @fixed_camera
      if SB.player.dead?
        @dead_timer += 1 if @dead_timer < 120
        @reload = true if SB.key_pressed?(:confirm) && @dead_timer >= 30 || SB.player.lives + SB.stage.life_count == 0 && @dead_timer >= 150
        return
      end

      if SB.stage.is_bonus
        finish if SB.stage.objective == :kill_all && enemy_count == 0
        finish if SB.stage.objective == :get_all_rocks && fire_rock_count == 0
      end

      if bomb.bottom
        if SB.key_down?(:up)
          @camera_offset = -4 * C::TILE_SIZE
        elsif SB.key_down?(:down)
          @camera_offset = 4 * C::TILE_SIZE
        end
      end

      if @finished
        return :finish
      elsif @warp.nil? &&
            (@border_exit == 0 && bomb.y + bomb.h <= -C::EXIT_MARGIN ||
             @border_exit == 1 && bomb.x >= @size.x - C::EXIT_MARGIN ||
             @border_exit == 2 && bomb.y >= @size.y + C::EXIT_MARGIN ||
             @border_exit == 3 && bomb.x + bomb.w <= C::EXIT_MARGIN)
        return :next_section
      elsif @border_exit != 2 && bomb.y >= @size.y + C::EXIT_MARGIN # pit
        SB.player.die
        return
      end
    end

    if SB.key_pressed?(:pause)
      SB.state = :paused
    end
  end

  def draw
    draw_bgs

    @map.foreach do |i, j, x, y|
      b = @tiles[i][j].back
      if b
        ind = b
        if b >= 90 && b < 93; ind = 90 + (b - 90 + @tile_3_index) % 3
        elsif b >= 93 && b < 96; ind = 93 + (b - 93 + @tile_3_index) % 3
        elsif b >= 96; ind = 96 + (b - 96 + @tile_4_index) % 4; end
        @tileset[ind].draw x, y, -2, 2, 2
      end
      @tileset[@tiles[i][j].pass].draw x, y, -2, 2, 2 if @tiles[i][j].pass
      @tileset[@tiles[i][j].wall].draw x, y, -2, 2, 2 if @tiles[i][j].wall and not @tiles[i][j].broken
    end

    @elements.each do |e|
      e.draw(@map, self) if e.is_visible @map
    end
    SB.player.bomb.draw(@map, self)
    @effects.each do |e|
      e.draw @map, 2, 2
    end

    @map.foreach do |i, j, x, y|
      f = @tiles[i][j].fore
      if f
        ind = f
        if f >= 90 && f < 93; ind = 90 + (f - 90 + @tile_3_index) % 3
        elsif f >= 93 && f < 96; ind = 93 + (f - 93 + @tile_3_index) % 3
        elsif f >= 96; ind = 96 + (f - 96 + @tile_4_index) % 4; end
        @tileset[ind].draw x, y, 0, 2, 2
      end
    end

    unless SB.stage.stopped == :all
      @tile_timer += 1
      if @tile_timer == C::TILE_ANIM_INTERVAL
        @tile_3_index = (@tile_3_index + 1) % 3
        @tile_4_index = (@tile_4_index + 1) % 4
        @tile_timer = 0
      end
    end

    @hide_tiles.each do |t|
      t.draw @map if t.is_visible @map
    end

    if @dark
      tiles = Array.new(25) {
        Array.new(19) {
          255
        }
      }
      @light_tiles.each do |t|
        tiles[t[0]][t[1]] = t[2] if tiles[t[0]][t[1]] > t[2]
      end
      tiles.each_with_index do |col, i|
        col.each_with_index do |cell, j|
          color = cell << 24
          G.window.draw_quad(i * C::TILE_SIZE, j * C::TILE_SIZE, color,
                             (i + 1) * C::TILE_SIZE, j * C::TILE_SIZE, color,
                             i * C::TILE_SIZE, (j + 1) * C::TILE_SIZE, color,
                             (i + 1) * C::TILE_SIZE, (j + 1) * C::TILE_SIZE, color, 0)
        end
      end
    elsif @rain
      x = @rain_offset.x
      y = @rain_offset.y
      y -= @rain.height * 2 while y > 0
      while x < @map.cam.w
        y2 = y
        while y2 < @map.cam.h
          @rain.draw(x, y2, 0, 2, 2)
          y2 += @rain.height * 2
        end
        x += @rain.width * 2
      end
      @rain_offset.x -= 1.8
      @rain_offset.x = 0 if @rain_offset.x <= -@rain.width * 2
      @rain_offset.y += 7
      @rain_offset.y = 0 if @rain_offset.y >= @rain.height * 2
    end
  end

  def draw_bgs
    @bgs.each_with_index do |bg, ind|
      back_x = -@map.cam.x * (0.5 + ind * 0.1)
      back_y = @repeat_bg_y ? -@map.cam.y * (0.5 + ind * 0.1) :
                              -(@map.cam.y.to_f / (@map.get_absolute_size.y - @map.cam.h) * (bg.height * 2 - @map.cam.h))
      tiles_x = @size.x / bg.width / 2
      tiles_y = @repeat_bg_y ? @size.y / bg.height / 2 : 1
      (1...tiles_x).each do |i|
        if back_x + i * bg.width * 2 > 0
          back_x += (i - 1) * bg.width * 2
          break
        end
      end
      (1...tiles_y).each do |i|
        if back_y + i * bg.height * 2 > 0
          back_y += (i - 1) * bg.height * 2
          break
        end
      end
      first_back_y = back_y
      while back_x < @map.cam.w
        while back_y < @map.cam.h
          bg.draw back_x, back_y, -10, 2, 2
          back_y += bg.height * 2
        end
        back_x += bg.width * 2
        back_y = first_back_y
      end
    end
  end
end
