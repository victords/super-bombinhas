# Copyright 2019 Victor David Santos
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

require_relative 'global'
require_relative 'stage'
include MiniGL

class Entrance
  attr_accessor :x, :y
  attr_reader :index

  def initialize(x, y, index)
    @x = x
    @y = y
    @index = index
    @img = Res.img(:editor_entrance)
    @bounds = Rectangle.new(@x, @y, C::TILE_SIZE, C::TILE_SIZE)
  end

  def is_visible(map)
    map.cam.intersect?(@bounds)
  end

  def draw(map, section)
    @img.draw(@x - map.cam.x, @y - map.cam.y, 0, 2, 2)
  end
end

class EditorRamp < Ramp
  attr_writer :x, :y
  attr_accessor :code

  def initialize(x, y, w, h, left, code)
    super(x, y, w, h, left)
    @code = code
  end
end

class EditorStage < Stage
  attr_reader :entrances, :bomb_mask
  attr_accessor :start_pos

  def initialize(name = nil)
    name ||= '__temp'
    super('custom', name)
    @entrances = []
    @switches = []

    sections = Dir["#{Res.prefix}stage/#{@world}/#{@num}-*"]
    sections.sort.each_with_index do |s, i|
      content = File.read(s)
      entrances = content.scan(/!\d+/)
      entrances.each do |e|
        index = e[1..-1].to_i
        @entrances[index] = { index: index }
      end

      @bomb_mask = content.split('#', -1)[4].to_i if i == 0
    end
  end

  def start(loaded = false, time = nil, objective = nil, reward = nil)
    @warp_timer = 0
    @star_count = 0
    @life_count = 0
    @switches = []
    taken_switches = []
    used_switches = []

    @sections = []
    @entrances = []
    sections = Dir["#{Res.prefix}stage/#{@world}/#{@num}-*"]
    sections.sort.each do |s|
      @sections << Section.new(s, @entrances, @switches, taken_switches, used_switches)
    end

    SB.player.reset(loaded)

    if @start_pos
      section = @sections.find { |s| s.id == @start_pos[2] }
      @entrances << (entrance = {x: @start_pos[0] * C::TILE_SIZE, y: @start_pos[1] * C::TILE_SIZE, section: section, index: @entrances.size})
      @cur_entrance = entrance
      @cur_section = section
    else
      @cur_entrance = @entrances[0]
      @cur_section = @cur_entrance[:section]
    end

    reset(true)
  end
end

class EditorSection < Section
  def initialize(file, entrances, switches)
    @elements = []
    @inter_elements = []
    @obstacles = []
    @light_tiles = []
    @effects = []
    @ramps = []

    if file.index('/')
      super(file, entrances, switches, [], [])
    else
      parts = file.split('#', -1)
      set_map_tileset parts[0].split ','
      set_bgs parts[1].split ','
      set_elements parts[2].split(';'), entrances, switches, [], []
      set_ramps parts[3].split ';'
    end

    @map = Map.new(C::TILE_SIZE, C::TILE_SIZE, @tiles.size, @tiles[0].size, C::EDITOR_SCREEN_WIDTH, C::EDITOR_SCREEN_HEIGHT)
    @size = @map.get_absolute_size

    @dead_timer = 0
    @tile_timer = 0
    @tile_3_index = 0
    @tile_4_index = 0
    @margin = Vector.new(C::EDITOR_SCREEN_WIDTH / 2, C::EDITOR_SCREEN_HEIGHT / 2)
    @wall_ish_tiles = [11, 7, 46, 47, 8, 9, 17, 18, 26, 36, 37, 48, 49, 27, 28, 38, 39, 19, 29]
  end

  def set_elements(s, entrances, switches, taken_switches, used_switches)
    s_index = switches.length
    super

    @element_info.each do |el|
      i = el[:x] / C::TILE_SIZE
      j = el[:y] / C::TILE_SIZE
      @tiles[i][j].obj = el[:type].new(el[:x], el[:y], el[:args], self)
      @tiles[i][j].code = "@#{ELEMENT_TYPES.key(el[:type])}#{el[:args] ? ":#{el[:args]}" : ''}"
    end
    entrances.select { |e| e && e[:section] == self }.each do |e|
      i = e[:x] / C::TILE_SIZE
      j = e[:y] / C::TILE_SIZE
      @tiles[i][j].obj = Entrance.new(e[:x], e[:y], e[:index])
      @tiles[i][j].code = "!#{e[:index]}#{e[:index] == @default_entrance ? '!' : ''}"
    end
    switches[s_index..-1].each do |s|
      i = s[:x] / C::TILE_SIZE
      j = s[:y] / C::TILE_SIZE
      @tiles[i][j].obj = s[:obj] = s[:type].new(s[:x], s[:y], s[:args], self, s)
      @tiles[i][j].code = "@#{ELEMENT_TYPES.key(s[:type])}#{s[:args] ? ":#{s[:args]}" : ''}"
    end
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
      @ramps << EditorRamp.new(x, y, w, h, left, r)
      @tiles[i + (left ? rw : -1)][j].ramp_end = true
    end
  end

  def change_size(w, h)
    return if w <= 0 || h <= 0
    
    p_w = @tiles.size
    p_h = @tiles[0].size
    if w < p_w
      @tiles = @tiles[0...w]
    elsif w > p_w
      min_y = h < p_h ? h : p_h
      (p_w...w).each do |i|
        @tiles[i] = []
        (0...min_y).each { |j| @tiles[i][j] = Tile.new }
      end
    end
    if h < p_h
      @tiles.map! { |o| o[0...h] }
    elsif h > p_h
      @tiles.each do |o|
        (p_h...h).each { |j| o[j] = Tile.new }
      end
    end
    @ramps.reverse_each do |r|
      @ramps.delete(r) if r.x + r.w > w || r.y + r.h > h
    end
    @map = Map.new(C::TILE_SIZE, C::TILE_SIZE, w, h, C::EDITOR_SCREEN_WIDTH, C::EDITOR_SCREEN_HEIGHT)
  end

  def change_bg(index, bg, tiled)
    if bg == '-'
      @bgs.delete_at(index)
    else
      @bgs[index] = {img: Res.img("bg_#{bg}"), tiled: tiled}
    end
  end

  def change_tileset(num)
    @tileset_num = num.to_i
    @tileset = Res.tileset(num, 16, 16)
  end

  def clear
    w = @tiles.size
    h = @tiles[0].size
    @tiles = Array.new(w) {
      Array.new(h) {
        Tile.new
      }
    }
    @ramps.clear
    @elements.clear
    @inter_elements.clear
    SB.stage.entrances.delete_if { |e| e.nil? || e[:section] == self }
  end

  def set_wall_tile(i, j, must_set = false)
    return if i < 0 || j < 0 || i >= @map.size.x || j >= @map.size.y
    return unless must_set || @tiles[i][j].wall && @tiles[i][j].wall < 50 || @tiles[i][j].back == 11
    up = j == 0 || wall_ish_tile?(i, j - 1)
    rt = i == @map.size.x - 1 || wall_ish_tile?(i + 1, j)
    dn = j == @map.size.y - 1 || wall_ish_tile?(i, j + 1)
    lf = i == 0 || wall_ish_tile?(i - 1, j)
    tl = !up && i > 0 && j > 0 && (wall_ish_tile?(i - 1, j - 1) || wall_ish_tile?(i - 1, j, true))
    tr = !up && i < @map.size.x - 1 && j > 0 && (wall_ish_tile?(i + 1, j - 1) || wall_ish_tile?(i + 1, j, true))
    tile =
      if up && rt && dn && lf; 11
      elsif up && rt && dn; 10
      elsif up && rt && lf; 21
      elsif up && dn && lf; 12
      elsif up && rt; 20
      elsif up && dn; 13
      elsif up && lf; 22
      elsif up; 23
      elsif tl && tr && rt && dn && lf; 6
      elsif tl && rt && dn && lf; 4
      elsif tr && rt && dn && lf; 5
      elsif tl && tr && rt && lf; 16
      elsif tl && rt && lf; 14
      elsif tr && rt && lf; 15
      elsif tr && rt && dn; 24
      elsif tl && dn && lf; 25
      elsif tr && rt; 34
      elsif tl && lf; 35
      elsif rt && dn && lf; 1
      elsif rt && dn; 0
      elsif rt && lf; 31
      elsif dn && lf; 2
      elsif rt; 30
      elsif dn; 3
      elsif lf; 32
      else; 33; end
    @tiles[i][j].back = tile == 11 ? tile : nil
    @tiles[i][j].wall = tile == 11 ? nil : tile
  end

  def set_surrounding_wall_tiles(i, j)
    set_wall_tile(i, j - 1)
    set_wall_tile(i + 1, j)
    set_wall_tile(i, j + 1)
    set_wall_tile(i - 1, j)
    set_wall_tile(i - 1, j + 1)
    set_wall_tile(i + 1, j + 1)
  end

  def wall_ish_tile?(i, j, back_only = false)
    !back_only && @tiles[i][j].wall && @tiles[i][j].wall < 50 || @tiles[i][j].back && @wall_ish_tiles.include?(@tiles[i][j].back)
  end

  def check_fill(type, i, j, ctrl, index)
    queue = [[i, j]]
    queued = { "#{i},#{j}" => true }

    enqueue = ->(i, j) do
      key = "#{i},#{j}"
      if i >= 0 && i < @tiles.size && j >= 0 && j < @tiles[0].size && cell_empty?(type, i, j) && !queued[key]
        queue << [i, j]
        queued[key] = true
      end
    end

    until queue.empty?
      i, j = queue.shift
      if type == :wall
        @tiles[i][j].back = 11
        set_surrounding_wall_tiles(i, j)
      elsif type == :hide
        @tiles[i][j].hide = ctrl ? 99 : 0
      elsif type == :back
        @tiles[i][j].back = index
      else
        @tiles[i][j].fore = index
      end
      enqueue.call(i - 1, j)
      enqueue.call(i + 1, j)
      enqueue.call(i, j - 1)
      enqueue.call(i, j + 1)
    end
  end

  def cell_empty?(type, i, j)
    type == :wall && @tiles[i][j].back.nil? && @tiles[i][j].fore.nil? && @tiles[i][j].obj.nil? && @tiles[i][j].wall.nil? && @tiles[i][j].pass.nil? ||
      type == :hide && @tiles[i][j].hide.nil? ||
      type == :back && @tiles[i][j].back.nil? && @tiles[i][j].wall.nil? && @tiles[i][j].pass.nil? ||
      type == :fore && @tiles[i][j].fore.nil? && @tiles[i][j].wall.nil? && @tiles[i][j].pass.nil?
  end

  def set_object(i, j, code, args, switches)
    type = ELEMENT_TYPES[code]
    args = nil if args.empty?
    @obstacles.delete(@tiles[i][j].obj)
    @inter_elements.delete(@tiles[i][j].obj)
    if type.instance_method(:initialize).parameters.length == 5
      switches << (el = {x: i * C::TILE_SIZE, y: j * C::TILE_SIZE, type: type, args: args, state: :normal, section: self, index: switches.size})
      @tiles[i][j].obj = el[:obj] = ELEMENT_TYPES[code].new(i * C::TILE_SIZE, j * C::TILE_SIZE, args, self, el)
    else
      @tiles[i][j].obj = ELEMENT_TYPES[code].new(i * C::TILE_SIZE, j * C::TILE_SIZE, args, self)
    end
    @tiles[i][j].code = "@#{code}#{args ? ":#{args}" : ''}"
  end

  def set_entrance(i, j, args)
    index = args.to_i
    default = args[-1] == '!'
    x = i * C::TILE_SIZE; y = j * C::TILE_SIZE
    SB.stage.entrances[index] = {x: x, y: y, section: self, index: index}
    @default_entrance = index if default
    @tiles[i][j].obj = Entrance.new(x, y, index)
    @tiles[i][j].code = "!#{index}#{default ? '!' : ''}"
  end

  def set_ramp(i, j, w, h, left, tiles)
    @ramps << EditorRamp.new(i * C::TILE_SIZE, j * C::TILE_SIZE, w * C::TILE_SIZE, h * C::TILE_SIZE, left, "#{left ? 'l' : 'r'}#{w}#{h}:#{i},#{j}")
    tiles.each do |t|
      @tiles[i + t[0]][j + t[1]].obj = nil
      @tiles[i + t[0]][j + t[1]].back = t[2]
    end
  end

  def offset(o_x, o_y, x_range, y_range)
    tiles_x = @tiles.size
    tiles_y = @tiles[0].size
    x_range.each do |i|
      y_range.each do |j|
        ii = i + o_x; jj = j + o_y
        obj = @tiles[i][j].obj
        if obj
          obj.x += o_x * C::TILE_SIZE
          obj.y += o_y * C::TILE_SIZE
          if obj.is_a?(Entrance)
            e = SB.stage.entrances[obj.index]
            e[:x] += o_x * C::TILE_SIZE
            e[:y] += o_y * C::TILE_SIZE
          end
        end
        if ii >= 0 && ii < tiles_x && jj >= 0 && jj < tiles_y
          @tiles[ii][jj] = @tiles[i][j]
        elsif obj.is_a?(Entrance)
          SB.stage.entrances.delete_at(obj.index)
        end
        @tiles[i][j] = Tile.new
      end
    end

    @ramps.each do |r|
      i = r.x / C::TILE_SIZE
      j = r.y / C::TILE_SIZE
      if x_range.include?(i) && y_range.include?(j)
        r.x += o_x * C::TILE_SIZE
        r.y += o_y * C::TILE_SIZE
        r.code.sub!(/:\d+,\d+/, ":#{i + o_x},#{j + o_y}")
      end
    end
  end

  def delete_at(i, j, all)
    if all
      check_delete_entrance(i, j)
      @tiles[i][j] = Tile.new
      delete_ramp(i, j)
      set_surrounding_wall_tiles(i, j)
    elsif !delete_ramp(i, j) && @tiles[i][j].hide
      @tiles[i][j].hide = nil
    elsif @tiles[i][j].fore
      @tiles[i][j].fore = nil
    elsif @tiles[i][j].obj
      check_delete_entrance(i, j)
      @tiles[i][j].obj = nil
    elsif @tiles[i][j].wall
      @tiles[i][j].wall = nil
      set_surrounding_wall_tiles(i, j)
    elsif @tiles[i][j].pass
      @tiles[i][j].pass = nil
    elsif @tiles[i][j].back
      @tiles[i][j].back = nil
    end
  end

  def check_delete_entrance(i, j)
    obj = @tiles[i][j].obj
    SB.stage.entrances.delete_at(obj.index) if obj.is_a?(Entrance)
  end

  def delete_ramp(i, j)
    @ramps.each do |r|
      x = r.x / C::TILE_SIZE
      y = r.y / C::TILE_SIZE
      w = r.w / C::TILE_SIZE
      h = r.h / C::TILE_SIZE
      if i >= x && i < x + w && j >= y && j < y + h
        @ramps.delete(r)
        return true
      end
    end
    false
  end

  def add(element)
    @elements.each do |e|
      if e.class == element.class && e.x == element.x && e.y == element.y
        return
      end
    end
    @elements << element
  end
end

class FloatingPanel
  COLOR = 0x80ffffff

  attr_reader :x, :y, :w, :h, :children
  attr_accessor :visible

  def initialize(element_type, x, y, w, h, children, editor)
    @element_type = element_type
    @x = x
    @y = y
    @w = w
    @h = h
    @visible = false
    @editor = editor
    set_children(children)
  end

  def set_children(children)
    @children = children
    @buttons = children.map.with_index do |c, i|
      Button.new(x: @x + c[:x], y: @y + c[:y], width: c[:img].width * 2, height: c[:img].height * 2, params: c[:index] || i) do |p|
        @editor.cur_element = @element_type
        @editor.cur_index = p
        @editor.toggle_args_panel
        @visible = false
      end
    end
  end

  def update
    return unless @visible
    @buttons.each(&:update)
  end

  def draw
    return unless @visible
    G.window.draw_quad(@x, @y, COLOR,
                       @x + @w, @y, COLOR,
                       @x, @y + @h, COLOR,
                       @x + @w, @y + @h, COLOR, 1)
    @children.each do |c|
      c[:img].draw(@x + c[:x], @y + c[:y], 1, 2, 2)
      if c[:name] && Mouse.over?(@x + c[:x], @y + c[:y], 32, 32)
        SB.text_helper.write_line(c[:name], @x + c[:x], @y + c[:y] - 12, :right, 0xffffff, 255, :border, 0, 2, 255, 2)
      end
    end
  end
end

class Editor
  NULL_COLOR = 0x66ffffff
  HIDE_COLOR = 0x33000099
  RAMP_COLOR = 0x66000000
  RAMP_UP_COLOR = 0x66990099
  SELECTION_COLOR = 0x66ffff00
  BLACK = 0xff000000
  WHITE = 0xffffffff

  attr_reader :text_helper
  attr_writer :cur_element, :cur_index

  def initialize
    SB.init_editor_stage(EditorStage.new)
    @section = EditorSection.new('300,300,0,1,s1#1!##', SB.stage.entrances, SB.stage.switches)

    @cur_element = :inspect
    @cur_index = -1

    bg_files = Dir["#{Res.prefix}img/bg/*"].sort
    @bgs = []
    bg_options = []
    bg_files.each do |f|
      num = f.split('/')[-1].chomp('.png')
      if /^\d+$/ =~ num
        @bgs << Gosu::Image.new(f, tileable: true, retro: true)
        bg_options << num
      end
    end
    bg2_options = ['-'] + bg_options
    @cur_bg = @cur_bg2 = 0

    bgm_options = []
    Dir["#{Res.prefix}song/s*"].sort.select{ |f| !f.include?('-intro') }.each{ |f| bgm_options << f.split('/')[-1].chomp('.ogg') }
    @cur_bgm = 0

    exit_options = %w(/\\ → \\/ ← -)
    @cur_exit = 0

    ts_files = Dir["#{Res.prefix}tileset/*.png"].sort
    @tilesets = []
    ts_options = []
    ts_files.each do |f|
      num = f.split('/')[-1].chomp('.png')
      @tilesets << Gosu::Image.load_tiles(f, 16, 16, tileable: true, retro: true)
      ts_options << num
    end
    @cur_tileset = 0

    el_files = Dir["#{Res.prefix}img/editor/el/*"]
    @elements = {}
    @enemies = {}
    @objs = {}
    names = {}
    el_files.each do |f|
      name = f.split('/')[-1].chomp('.png')
      img = Res.img("editor_el_#{name}")
      index, name = name.split('-')
      index = index.to_i
      @elements[index] = img
      if name.end_with?('!')
        @enemies[index] = img
        names[index] = name.chomp('!')
      else
        @objs[index] = img
        names[index] = name
      end
    end

    @bomb = Res.imgs(:sprite_BombaAzul, 6, 2)
    @entrance = Res.img(:editor_entrance)

    el_args = File.read("#{Res.prefix}editor").split('===')
    @element_args = []
    el_args.each_with_index do |a, i|
      next if a.chomp.empty?

      lines = a.split("\n").delete_if(&:empty?)
      if lines[-1].start_with?('#')
        pattern = lines[-1]
        index = -2
      else
        pattern = :seq
        index = -1
      end
      fields = []
      lines[0..index].each do |l|
        f = l.split('|')
        fields << (field = {
          name: f[0],
          type: f[1]
        })
        case field[:type]
        when 'enum'
          field[:values] = f[2].split(',', -1)
          field[:display_values] = f[3].split(',')
        when 'int'
          values = f[2].split('-')
          field[:min] = values[0].to_i
          field[:max] = values[1].to_i
          field[:format] = f[3]
        when 'bool'
          field[:values] = f[2].split(',', -1)
          field[:default] = f[3] == '1'
        when 'coords'
          field[:limit] = f[2].to_i
        end
      end
      @element_args[i + 1] = {
        pattern: pattern,
        fields: fields
      }
    end
    @args = {
      index: nil,
      value: '',
      active_field: nil
    }

    @panels = [
      ################################## General ##################################
      Panel.new(0, 0, 760, 48, [
        Label.new(x: 8, y: 0, font: SB.font, text: 'W', max_length: 3, scale_x: 2, scale_y: 2, anchor: :left),
        (txt_w = TextField.new(x: 22, y: 0, img: :editor_textField, font: SB.font, text: '300', allowed_chars: '0123456789', margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, anchor: :left)),
        Label.new(x: 70, y: 0, font: SB.font, text: 'H', max_length: 3, scale_x: 2, scale_y: 2, anchor: :left),
        (txt_h = TextField.new(x: 84, y: 0, img: :editor_textField, font: SB.font, text: '300', allowed_chars: '0123456789', margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, anchor: :left)),
        Button.new(x: 130, y: 0, img: :editor_btn1, font: SB.font, text: 'OK', scale_x: 2, scale_y: 2, anchor: :left) do
          @section.change_size(txt_w.text.to_i, txt_h.text.to_i)
        end,
        Label.new(x: 200, y: 0, font: SB.font, text: 'BG', scale_x: 2, scale_y: 2, anchor: :left),
        (@ddl_bg = DropDownList.new(x: 224, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: bg_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_bg = bg_options.index(v)
          @section.change_bg(0, v, @chk_bg_tile.checked)
        end),
        Label.new(x: 268, y: -10, font: SB.font, text: 'tiled', scale_x: 2, scale_y: 2, anchor: :left),
        (@chk_bg_tile = ToggleButton.new(x: 268, y: 10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :left) do |v|
          @section.change_bg(0, bg_options[@cur_bg], v)
        end),
        Label.new(x: 318, y: 0, font: SB.font, text: 'BG2', scale_x: 2, scale_y: 2, anchor: :left),
        (@ddl_bg2 = DropDownList.new(x: 354, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: bg2_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_bg2 = bg_options.index(v)
          @section.change_bg(1, v, @chk_bg2_tile.checked)
        end),
        Label.new(x: 398, y: -10, font: SB.font, text: 'tiled', scale_x: 2, scale_y: 2, anchor: :left),
        (@chk_bg2_tile = ToggleButton.new(x: 398, y: 10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :left) do |v|
          @section.change_bg(1, bg_options[@cur_bg2], v) if ddl_bg2.value != '-'
        end),
        Label.new(x: 450, y: 0, font: SB.font, text: 'BGM', scale_x: 2, scale_y: 2, anchor: :left),
        (@ddl_bgm = DropDownList.new(x: 486, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: bgm_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_bgm = bgm_options.index(v)
        end),
        Label.new(x: 532, y: 0, font: SB.font, text: 'Exit', scale_x: 2, scale_y: 2, anchor: :left),
        (ddl_exit = DropDownList.new(x: 572, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: exit_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_exit = exit_options.index(v)
        end),
        Label.new(x: 94, y: -10, font: SB.font, text: 'Dark', scale_x: 2, scale_y: 2, anchor: :right),
        (@chk_dark = ToggleButton.new(x: 74, y: -10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :right)),
        Label.new(x: 94, y: 10, font: SB.font, text: 'Rain', scale_x: 2, scale_y: 2, anchor: :right),
        (@chk_rain = ToggleButton.new(x: 74, y: 10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :right)),
        Button.new(x: 4, y: 0, font: SB.font, text: 'Help', img: :editor_btn1, scale_x: 2, scale_y: 2, anchor: :right) do
          toggle_aux_panel(8)
        end
      ], :editor_pnl, :tiled, true, 2, 2, :top),
      ###########################################################################

      ################################# Tileset #################################
      Panel.new(0, 0, 68, 320, [
        (@ddl_ts = DropDownList.new(x: 0, y: 4, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: ts_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :top) do |_, v|
          @cur_tileset = ts_options.index(v)
          @floating_panels[0].set_children(@tilesets[@cur_tileset].map.with_index{ |t, i| { img: t, x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33 } })
          @section.change_tileset(v)
          hide_all_panels
        end),
        Button.new(x: 0, y: 38, img: :editor_btn1, font: SB.font, text: 'Wall', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :wall
          hide_all_panels
        end,
        Button.new(x: 0, y: 38 + 44, img: :editor_btn1, font: SB.font, text: 'Pass', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :pass
          hide_all_panels
        end,
        Button.new(x: 0, y: 38 + 88, img: :editor_btn1, font: SB.font, text: 'Hide', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :hide
          hide_all_panels
        end,
        (ramp_btn = Button.new(x: 0, y: 38 + 132, img: :editor_btn1, font: SB.font, text: 'Ramp', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_floating_panel(1)
          toggle_aux_panels
          toggle_args_panel
        end),
        (other_tile_btn = Button.new(x: 0, y: 38, img: :editor_btn1, font: SB.font, text: 'Other', scale_x: 2, scale_y: 2, anchor: :bottom) do
          toggle_floating_panel(0)
          toggle_aux_panels
          toggle_args_panel
        end),
        (@ddl_tile_type = DropDownList.new(x: 0, y: 4, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: %w(w p b f), text_margin: 4, scale_x: 2, scale_y: 2, anchor: :bottom)),
      ], :editor_pnl, :tiled, true, 2, 2, :left),
      ###########################################################################

      ################################### File ##################################
      Panel.new(0, 0, 760, 48, [
        Label.new(x: 7, y: 0, font: SB.font, text: 'Stage', scale_x: 2, scale_y: 2, anchor: :left),
        (@txt_stage = TextField.new(x: 64, y: 0, font: SB.font, img: :editor_textField2, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, text: '1', anchor: :left,
                                    allowed_chars: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?', max_length: 15)),
        Label.new(x: 247, y: 0, font: SB.font, text: 'Section', scale_x: 2, scale_y: 2, anchor: :left),
        (@txt_section = TextField.new(x: 319, y: 0, font: SB.font, img: :editor_textField, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, text: '1', anchor: :left,
                                      allowed_chars: '0123456789', max_length: 2)),
        Button.new(x: 377, y: 0, img: :editor_btn1, font: SB.font, text: 'Clear', scale_x: 2, scale_y: 2, anchor: :left) do
          @section.clear
        end,
        Button.new(x: 441, y: 0, img: :editor_btn1, font: SB.font, text: 'Load', scale_x: 2, scale_y: 2, anchor: :left) do
          path = "#{Res.prefix}/stage/custom/#{@txt_stage.text}-#{@txt_section.text}"
          if File.exist? path
            f = File.open(path)
            all = f.readline.chomp.split('#')
            f.close
            infos = all[0].split(',')
            bg_infos = all[1].split(',')
            txt_w.text = infos[0]; txt_h.text = infos[1]

            @cur_exit = infos[2].to_i
            ddl_exit.value = exit_options[@cur_exit]

            if bg_infos[0].end_with?('!')
              @ddl_bg.value = bg_infos[0][0..-2]
              @chk_bg_tile.checked = false
            else
              @ddl_bg.value = bg_infos[0]
              @chk_bg_tile.checked = true
            end
            @cur_bg = bg_options.index(@ddl_bg.value)
            if bg_infos[1]
              if bg_infos[1].end_with?('!')
                @ddl_bg2.value = bg_infos[1][0..-2]
                @chk_bg2_tile.checked = false
              else
                @ddl_bg2.value = bg_infos[1]
                @chk_bg2_tile.checked = true
              end
              @cur_bg2 = bg_options.index(@ddl_bg2.value)
            else
              @ddl_bg2.value = '-'
              @cur_bg2 = nil
            end
            @ddl_ts.value = infos[3]
            @cur_tileset = ts_options.index(@ddl_ts.value)
            @ddl_bgm.value = infos[4]
            @cur_bgm = bgm_options.index(@ddl_bgm.value)

            @chk_dark.checked = infos[5] && infos[5] == '.'
            @chk_rain.checked = infos[5] && infos[5] == '$'

            @saved_name = @txt_stage.text
            SB.init_editor_stage(EditorStage.new(@saved_name))
            @section = EditorSection.new(path, SB.stage.entrances, SB.stage.switches)
            if SB.stage.bomb_mask != 0
              controls = @panels[7].instance_eval('@controls')
              controls.each_with_index do |c, i|
                c.checked = (SB.stage.bomb_mask & (2**i)) > 0
              end
            end
          end
        end,
        Button.new(x: 505, y: 0, img: :editor_btn1, font: SB.font, text: 'Save', scale_x: 2, scale_y: 2, anchor: :left) do
          @saved_name = @txt_stage.text if save
        end,
        Button.new(x: 132, y: 0, img: :editor_btn1, font: SB.font, text: 'Bombs', scale_x: 2, scale_y: 2, anchor: :right) do
          toggle_aux_panel(7)
        end,
        Button.new(x: 68, y: 0, img: :editor_btn1, font: SB.font, text: 'Test', scale_x: 2, scale_y: 2, anchor: :right) do
          start_test
        end,
        Button.new(x: 4, y: 0, img: :editor_btn1, font: SB.font, text: 'Exit', scale_x: 2, scale_y: 2, anchor: :right) do
          confirm_exit
        end
      ], :editor_pnl, :tiled, true, 2, 2, :bottom),
      ###########################################################################

      ################################# Elements ################################
      Panel.new(0, 0, 68, 320, [
        Button.new(x: 0, y: 4, img: :editor_btn1, font: SB.font, text: 'Bomb', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :bomb
          hide_all_panels
        end,
        Button.new(x: 0, y: 48, img: :editor_btn1, font: SB.font, text: 'entr.', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :entrance
          toggle_args_panel
        end,
        (btn_obj = Button.new(x: 0, y: 92, img: :editor_btn1, font: SB.font, text: 'obj', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_floating_panel(2)
        end),
        (btn_enemy = Button.new(x: 0, y: 136, img: :editor_btn1, font: SB.font, text: 'enmy', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_floating_panel(3)
        end),
        Button.new(x: 0, y: 180, img: :editor_btn1, font: SB.font, text: 'args', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_args_panel
        end,
        Button.new(x: 0, y: 224, img: :editor_btn1, font: SB.font, text: 'insp.', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :inspect
          @cur_index = @args[:index] = -1
          hide_all_panels
        end,
        Button.new(x: 0, y: 4, img: :editor_btn1, font: SB.font, text: 'offst', scale_x: 2, scale_y: 2, anchor: :bottom) do
          toggle_aux_panel(4)
        end
      ], :editor_pnl, :tiled, true, 2, 2, :right),
      ###########################################################################

      ################################## Offset #################################
      Panel.new(0, 0, 200, 70, [
        Label.new(x: 0, y: 4, font: SB.font, text: 'Offset', scale_x: 2, scale_y: 2, anchor: :top),
        Label.new(x: 6, y: 7, font: SB.font, text: 'X', scale_x: 2, scale_y: 2, anchor: :left),
        (@txt_offset_x = TextField.new(x: 22, y: 7, img: :editor_textField, font: SB.font, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, anchor: :left)),
        Label.new(x: 66, y: 7, font: SB.font, text: 'Y', scale_x: 2, scale_y: 2, anchor: :left),
        (@txt_offset_y = TextField.new(x: 82, y: 7, img: :editor_textField, font: SB.font, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, anchor: :left)),
        Button.new(x: 4, y: 7, img: :editor_btn1, font: SB.font, text: 'OK', scale_x: 2, scale_y: 2, anchor: :right) do
          o_x = @txt_offset_x.text.to_i
          o_y = @txt_offset_y.text.to_i
          start_x = @selection ? @selection[0] : 0
          start_y = @selection ? @selection[1] : 0
          tiles_x = @section.tiles.size
          tiles_y = @section.tiles[0].size
          end_x = @selection ? @selection[2] : tiles_x - 1
          end_y = @selection ? @selection[3] : tiles_y - 1
          x_range = o_x > 0 ? end_x.downto(start_x) : start_x.upto(end_x)
          y_range = o_y > 0 ? end_y.downto(start_y) : start_y.upto(end_y)
          @section.offset(o_x, o_y, x_range, y_range)

          if @selection
            @selection[0] += o_x
            @selection[1] += o_y
            @selection[2] += o_x
            @selection[3] += o_y
          end
        end
      ], :editor_pnl, :tiled, true, 2, 2, :center),
      ###########################################################################

      ############################# ENTRANCE WARNING ############################
      Panel.new(0, 0, 360, 120, [
        (@lbl_msg1 = Label.new(x: 0, y: 10, font: SB.font, text: 'The level must have an entrance', scale_x: 2, scale_y: 2, anchor: :top)),
        (@lbl_msg2 = Label.new(x: 0, y: 40, font: SB.font, text: 'or a start point', scale_x: 2, scale_y: 2, anchor: :top)),
        Button.new(x: 0, y: 10, img: :editor_btn1, font: SB.font, text: 'OK', scale_x: 2, scale_y: 2, anchor: :bottom) {
          @panels[5].visible = false
        }
      ], :editor_pnl, :tiled, true, 2, 2, :center),
      ###########################################################################

      ################################ CONFIRMATION #############################
      Panel.new(0, 0, 360, 120, [
        (@lbl_conf = Label.new(x: 0, y: 10, font: SB.font, text: '', scale_x: 2, scale_y: 2, anchor: :top)),
        Button.new(x: -32, y: 10, img: :editor_btn1, font: SB.font, text: 'Yes', scale_x: 2, scale_y: 2, anchor: :bottom) do
          @confirm_action.call if @confirm_action
          @panels[6].visible = false
        end,
        Button.new(x: 32, y: 10, img: :editor_btn1, font: SB.font, text: 'No', scale_x: 2, scale_y: 2, anchor: :bottom) do
          @panels[6].visible = false
        end
      ], :editor_pnl, :tiled, true, 2, 2, :center),
      ###########################################################################

      ################################### BOMBS #################################
      Panel.new(0, 0, 240, 174, [
        ToggleButton.new(x: 10, y: 11, font: SB.font, text: 'Bomba Azul', img: :editor_chk, checked: true, scale_x: 2, scale_y: 2, center_x: false, margin_x: 15) { |v| update_bomb_mask(v, 0) },
        ToggleButton.new(x: 10, y: 45, font: SB.font, text: 'Bomba Vermelha', img: :editor_chk, checked: true, scale_x: 2, scale_y: 2, center_x: false, margin_x: 15) { |v| update_bomb_mask(v, 1) },
        ToggleButton.new(x: 10, y: 79, font: SB.font, text: 'Bomba Amarela', img: :editor_chk, checked: true, scale_x: 2, scale_y: 2, center_x: false, margin_x: 15) { |v| update_bomb_mask(v, 2) },
        ToggleButton.new(x: 10, y: 113, font: SB.font, text: 'Bomba Verde', img: :editor_chk, checked: true, scale_x: 2, scale_y: 2, center_x: false, margin_x: 15) { |v| update_bomb_mask(v, 3) },
        ToggleButton.new(x: 10, y: 147, font: SB.font, text: 'Aldan', img: :editor_chk, checked: true, scale_x: 2, scale_y: 2, center_x: false, margin_x: 15) { |v| update_bomb_mask(v, 4) },
      ], :editor_pnl, :tiled, true, 2, 2, :center),
      ###########################################################################

      ################################### HELP ##################################
      Panel.new(0, 0, 1200, 600, [], :editor_pnl, :tiled, true, 2, 2, :center),
      ###########################################################################

      ########################### EXPERIMENTAL WARNING ##########################
      Panel.new(0, 0, 1200, 180, [
        Label.new(x: 0, y: 10, font: SB.font, text: '--- WARNING ---', scale_x: 2.5, scale_y: 2.5, anchor: :top),
        Label.new(x: 0, y: 50, font: SB.font, text: 'This is an experimental feature. You can expect to find some bugs. If you do, please report them as issues at https://github.com/victords/super-bombinhas', scale_x: 1.5, scale_y: 1.5, anchor: :top),
        Label.new(x: 0, y: 70, font: SB.font, text: "Also, if you haven't completed the game's story mode, there can be spoilers.", scale_x: 1.5, scale_y: 1.5, anchor: :top),
        Label.new(x: 0, y: 90, font: SB.font, text: "For instructions, click the 'Help' button at the top right.", scale_x: 1.5, scale_y: 1.5, anchor: :top),
        Button.new(x: 0, y: 10, font: SB.font, text: 'OK', img: :editor_btn1, scale_x: 2, scale_y: 2, anchor: :bottom) {
          toggle_aux_panel(9)
        }
      ], :editor_pnl, :tiled, true, 2, 2, :center)
      ###########################################################################
    ]

    obj_items = []
    @objs.keys.sort.each_with_index do |k, i|
      obj_items << { img: @objs[k], x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33, name: names[k], index: k }
    end
    enemy_items = []
    @enemies.keys.sort.each_with_index do |k, i|
      enemy_items << { img: @enemies[k], x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33, name: names[k], index: k }
    end
    @floating_panels = [
      FloatingPanel.new(:tile, other_tile_btn.x + 64, other_tile_btn.y - 148, 337, 337, @tilesets[@cur_tileset].map.with_index{ |t, i| { img: t, x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33 } }, self),
      FloatingPanel.new(:ramp, ramp_btn.x + 64, ramp_btn.y, 271, 40, (0..7).map { |i| { img: Res.img("editor_ramp#{i}"), x: 4 + i * 33, y: 4 } }, self),
      FloatingPanel.new(:obj, btn_obj.x - 341, btn_obj.y, 337, 238, obj_items, self),
      FloatingPanel.new(:obj, btn_enemy.x - 341, btn_enemy.y, 337, 205, enemy_items, self),
    ]

    @dropdowns = [@ddl_bg, @ddl_bg2, @ddl_bgm, ddl_exit, @ddl_ts, @ddl_tile_type]

    @ramp_sizes = [[1, 1], [2, 1], [3, 2], [1, 2]]
    @ramp_tiles = [
      [[0, 0, 7]], # l 1x1
      [[0, 0, 46], [1, 0, 47]], # l 2x1
      [[1, 0, 8], [2, 0, 9], [0, 1, 17], [1, 1, 18], [2, 1, 11]], # l 3x2
      [[0, 0, 26], [0, 1, 36]], # l 1x2
      [[0, 0, 37]], # r 1x1
      [[0, 0, 48], [1, 0, 49]], # r 2x1
      [[0, 0, 27], [1, 0, 28], [0, 1, 11], [1, 1, 38], [2, 1, 39]], # r 3x2
      [[0, 0, 19], [0, 1, 29]], # r 1x2
    ]

    @help_text = <<END
-- Top Panel --
Set the width and height of the level (number of tiles) using the 'W' and 'H' fields; Select a background (BG) and optionally a second background (BG2); The 'tiled' checkbox indicates if the BG will be vertically tiled; Select a background music (BGM); Select the type of transition to the next section (if any) in the 'Exit' field ('/\\' for up, '→' for right, '\\/' for down and '←' for left); Select if the section should be dark or have rain (they don't work simultaneously).

-- Left Panel --
Select the tileset; Click 'Wall', 'Pass' or 'Hide' to place walls, passable blocks or 'hide' blocks (blocks that reveal what's behind when the player goes into them); Click 'Ramp' to select a ramp size and place ramps; Click 'Other' to place any tile of the tileset, specify what type of tile it will be in the dropdown below ('w' for wall, 'p' for passable, 'b' for backgroud and 'f' for foreground).

-- Right Panel --
Place the bomb for testing with the 'Bomb' button; Place an entrance for the section with the 'entr.' button (all sections must have an entrance to be saved); Use the 'default' attribute to indicate that this entrance will be used when transitioning from a previous section; Click 'obj' to select an object to place (if the object has parameters, a panel with them will show up, use the Enter key or the 'args' button below to hide it); Click 'enmy' to place an enemy, parameters also apply to some; Click the 'insp.' button and then click on an object/enemy on the map to see its parameters; Click the 'offst' button (or press the Tab key) to offset all objects or a selected area (select by holding Alt and dragging).

-- Bottom Panel --
Set the stage name in the 'Stage' field; Set the section number in the 'Section' field (in order to create a stage with multiple sections, just use the same name in the 'Stage' field, and don't forget to create entrances and use doors or the 'Exit' property to allow the player to enter the other sections); Click 'clear' to remove everything from the map; Click 'Load' to load the stage/section specified in these fields; Click 'Save' to save the current section; Click 'Bombs' to specify which bombs can be used in this level (this only needs to be specified in the first section of the stage); Click 'Test' (or press the space bar) to test the current section; Click 'Exit' to leave the editor.
END

    toggle_aux_panels
    unless SB.editor_warning_shown
      toggle_aux_panel(9)
      SB.editor_warning_shown = true
    end
  end

  def update
    unless @inited
      @inited = true
    end

    confirm_exit if KB.key_pressed?(Gosu::KbEscape)
    toggle_args_panel if KB.key_pressed?(Gosu::KbReturn)
    toggle_aux_panel(4) if KB.key_pressed?(Gosu::KbTab)

    if KB.key_pressed?(Gosu::KB_SPACE)
      start_test
      return
    end

    @over_panel = []
    @dropdowns.each_with_index do |d, i|
      break if i > 5 && !@args_panel.visible
      h = d.instance_eval('@open') ? d.instance_eval('@max_h') : d.h
      @over_panel[i < 4 ? 0 : i < 6 ? 1 : @panels.size] = true if Mouse.over?(d.x, d.y, d.w, h)
    end
    @floating_panels.each_with_index do |p, i|
      p.update
      @over_panel[i < 2 ? 1 : 3] = true if p.visible && Mouse.over?(p.x, p.y, p.w, p.h)
    end
    @panels.each_with_index do |p, i|
      p.update
      @over_panel[i] = true if p.visible && Mouse.over?(p.x, p.y, p.w, p.h)
    end
    if @args_panel
      p = @args_panel
      p.update
      @over_panel[@panels.size] = true if p.visible && Mouse.over?(p.x, p.y, p.w, p.h)
    end

    speed = KB.key_down?(Gosu::KbLeftShift) || KB.key_down?(Gosu::KbRightShift) ? 10 : 20
    @section.map.move_camera 0, -speed if KB.key_down?(Gosu::KbUp) || KB.key_down?(Gosu::KB_W)
    @section.map.move_camera speed, 0 if KB.key_down?(Gosu::KbRight) || KB.key_down?(Gosu::KB_D)
    @section.map.move_camera 0, speed if KB.key_down?(Gosu::KbDown) || KB.key_down?(Gosu::KB_S)
    @section.map.move_camera -speed, 0 if KB.key_down?(Gosu::KbLeft) || KB.key_down?(Gosu::KB_A)

    return if @over_panel.any?

    ctrl = KB.key_down?(Gosu::KbLeftControl) || KB.key_down?(Gosu::KbRightControl)
    alt = KB.key_down?(Gosu::KbLeftAlt) || KB.key_down?(Gosu::KbRightAlt)
    mp = @section.map.get_map_pos(Mouse.x, Mouse.y)
    i = mp.x; j = mp.y
    return if i >= @section.tiles.size || j >= @section.tiles[0].size
    if Mouse.double_click?(:left)
      type = @cur_element == :tile ? (@ddl_tile_type.value == 'b' ? :back : @ddl_tile_type.value == 'f' ? :fore : nil) : @cur_element
      @section.check_fill(type, i, j, ctrl, @cur_index) if type == :wall || type == :hide || type == :back || type == :fore
    elsif Mouse.button_pressed?(:left)
      if ctrl
        case @cur_element
        when :obj
          add_coords(i, j)
        when :pass
          @pass_start = [i, j]
        end
      elsif alt
        @selection = [i, j]
      else
        @selection = nil
        case @cur_element
        when :pass
          @pass_start = [i, j]
        when :ramp
          sz = @ramp_sizes[@cur_index % 4]
          @section.set_ramp(i, j, sz[0], sz[1], @cur_index < 4, @ramp_tiles[@cur_index])
        when :entrance
          @section.set_entrance(i, j, @args[:value])
        when :inspect
          obj = @section.tiles[i][j].obj
          if obj && !obj.is_a?(Entrance)
            @cur_element = :obj
            @cur_index = Section::ELEMENT_TYPES.key(obj.class)
            code = @section.tiles[i][j].code
            toggle_args_panel(code.index(':') ? code[(code.index(':') + 1)..-1] : nil, obj.class)
          end
        end
      end
    elsif !alt && Mouse.button_down?(:left)
      if ctrl
        @section.tiles[i][j].hide = 99 if @cur_element == :hide
      else
        case @cur_element
        when :wall
          @section.set_wall_tile(i, j, true)
          @section.set_surrounding_wall_tiles(i, j)
        when :hide
          @section.tiles[i][j].hide = 0
        when :tile
          t = @ddl_tile_type.value
          prop = t == 'w' ? :wall= : t == 'p' ? :pass= : t == 'b' ? :back= : :fore=
          @section.tiles[i][j].send(prop, @cur_index)
        when :obj
          @section.set_object(i, j, @cur_index, @args[:value], SB.stage.switches)
        when :bomb
          SB.stage.start_pos = [i, j, @txt_section.text]
        end
      end
    elsif Mouse.button_released?(:left)
      if alt
        @selection << i << j
      else
        @selection = nil
        if @cur_element == :pass && @pass_start
          min_x, max_x = i < @pass_start[0] ? [i, @pass_start[0]] : [@pass_start[0], i]
          min_y, max_y = j < @pass_start[1] ? [j, @pass_start[1]] : [@pass_start[1], j]
          (min_y..max_y).each do |l|
            (min_x..max_x).each do |k|
              cell = @section.tiles[k][l]
              next if ctrl && [11, 43, 44, 45].include?(cell.back)
              if l == min_y
                next if ctrl && cell.wall
                cell.pass = k == min_x ? 40 : k == max_x ? 42 : 41
              else
                cell.back = k == min_x ? 43 : k == max_x ? 45 : 44
                cell.pass = nil if cell.pass && !ctrl
              end
            end
          end
          @pass_start = nil
        end
      end
    elsif !ctrl && Mouse.button_down?(:right)
      s_pos = SB.stage.start_pos
      SB.stage.start_pos = nil if s_pos && s_pos[0] == i && s_pos[1] == j
      @section.delete_at(i, j, true)
    elsif ctrl && Mouse.button_pressed?(:right)
      s_pos = SB.stage.start_pos
      deleted = false
      if s_pos && s_pos[0] == i && s_pos[1] == j
        SB.stage.start_pos = nil
        deleted = true
      end
      @section.delete_at(i, j, false) unless deleted
    end
  end

  def confirm_exit
    @confirm_action = Proc.new {
      SB.close_editor
    }
    show_confirm_panel('Exit? Unsaved changes will be lost.')
  end

  def start_test
    toggle_aux_panels
    @args_panel.visible = false if @args_panel
    @floating_panels.each do |p|
      p.visible = false
    end

    @save_confirm = true
    return unless save(@saved_name || '__temp')
    G.window.width = C::SCREEN_WIDTH
    G.window.height = C::SCREEN_HEIGHT
    StageMenu.initialize(true, true)
    SB.state = :main
    SB.stage.start
  end

  def toggle_floating_panel(index)
    toggle_aux_panels
    @args_panel.visible = false if @args_panel
    @floating_panels.each_with_index do |p, i|
      p.visible = i == index ? !p.visible : false
    end
  end

  def toggle_args_panel(args = nil, type = nil)
    unless @cur_element == :obj || @cur_element == :entrance
      @args_panel.visible = false if @args_panel
      return
    end

    @floating_panels.each do |p|
      p.visible = false
    end
    toggle_aux_panels

    if @cur_element == :entrance && @args[:index] != -1
      controls = []
      controls << Label.new(x: 10, y: 10, font: SB.font, text: 'Index', scale_x: 2, scale_y: 2)
      controls << TextField.new(x: 150, y: 10, font: SB.font, img: :editor_textField, allowed_chars: '0123456789', max_length: 2, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2) { |v|
        build_args_value
      }
      controls << Label.new(x: 10, y: 44, font: SB.font, text: 'Default', scale_x: 2, scale_y: 2)
      controls << ToggleButton.new(x: 150, y: 47, img: :editor_chk, scale_x: 2, scale_y: 2) { |v|
        build_args_value
      }
      @args_panel = Panel.new(0, 0, 300, 72, controls, :editor_pnl, :tiled, true, 2, 2, :center)
      @args = {
        index: -1,
        controls: controls,
        active_field: nil
      }
      build_args_value
    elsif @element_args[@cur_index].nil?
      @args_panel.visible = false if @args_panel
      return
    elsif @args[:index] != @cur_index
      element = @element_args[@cur_index]
      fields = element[:fields]
      controls = []
      @dropdowns.slice!(6, @dropdowns.size - 6)
      fields.each_with_index do |f, i|
        y = 4 + i * 34
        controls << Label.new(x: 10, y: y + 4, font: SB.font, text: f[:name], scale_x: 2, scale_y: 2)
        f[:control_index] = controls.size
        case f[:type]
        when 'enum'
          controls << (ddl = DropDownList.new(x: 280, y: y, font: SB.font, img: :editor_ddl2, opt_img: :editor_ddl2Opt, options: f[:display_values], text_margin: 4, scale_x: 2, scale_y: 2) {
            build_args_value
          })
          @dropdowns << ddl
        when 'int'
          controls << TextField.new(x: 280, y: y, font: SB.font, img: :editor_textField, max_length: 3, allowed_chars: '0123456789', margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2) { |v|
            if v.to_i < f[:min] && !v.empty?
              @args[:controls][f[:control_index]].send(:text=, f[:min].to_s, false)
            elsif v.to_i > f[:max]
              @args[:controls][f[:control_index]].send(:text=, f[:max].to_s, false)
            end
            build_args_value
          }
        when 'bool'
          controls << ToggleButton.new(x: 280, y: y + 7, img: :editor_chk, scale_x: 2, scale_y: 2, checked: f[:default]) {
            build_args_value
          }
        when 'entrance'
          entrances = SB.stage.entrances.reject(&:nil?).map{ |e| e[:index].to_s }
          controls << (ddl = DropDownList.new(x: 280, y: y, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: entrances, text_margin: 4, scale_x: 2, scale_y: 2) {
            build_args_value
          })
          @dropdowns << ddl
        when 'coords'
          controls << Label.new(x: 420, y: y, font: SB.font, text: '')
          controls << Button.new(x: 280, y: y, font: SB.font, text: 'Set', img: :editor_btn2, scale_x: 2, scale_y: 2) {
            @args[:active_field] = f
          }
          controls << Button.new(x: 350, y: y, font: SB.font, text: 'Clear', img: :editor_btn2, scale_x: 2, scale_y: 2) {
            @args[:controls][f[:control_index]].text = ''
            build_args_value
          }
          controls << Label.new(x: 420, y: y + 15, font: SB.font, text: '(Use ctrl-click to add points)')
        when 'float'
          controls << TextField.new(x: 280, y: y, font: SB.font, img: :editor_textField2, max_length: 5, allowed_chars: '0123456789.', margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2) {
            build_args_value
          }
        end
      end
      @args_panel = Panel.new(0, 0, 600, 4 + fields.size * 34, controls, :editor_pnl, :tiled, true, 2, 2, :center)
      @args = {
        element: element,
        index: @cur_index,
        controls: controls,
        active_field: nil
      }

      if args
        values = element[:pattern] == :seq ? args.split(',') : type.parse_args(args)
        fields.each_with_index do |f, i|
          next if values[i].nil?
          control = controls[f[:control_index]]
          case f[:type]
          when 'enum'
            control.value = f[:display_values][f[:values].index(values[i])]
          when 'int', 'float'
            control.text = values[i]
          when 'bool'
            control.checked = values[i] == f[:values][1]
          when 'entrance'
            control.value = values[i]
          when 'coords'
            control.text = values[i].split(':').join('  ')
          end
        end
        @args[:value] = args
      else
        build_args_value
      end
    else
      @args_panel.visible = !@args_panel.visible
    end
  end

  def build_args_value
    controls = @args[:controls]
    if @cur_element == :entrance
      @args[:value] = "#{controls[1].text}#{controls[3].checked ? '!' : ''}"
      return
    end

    element = @args[:element]
    values = []
    last_non_empty = nil
    element[:fields].each_with_index do |f, i|
      control = controls[f[:control_index]]
      v = case f[:type]
          when 'enum'
            f[:values][f[:display_values].index(control.value)]
          when 'int'
            if f[:format]
              control.text.empty? ? '' : f[:format].sub('#', control.text)
            else
              control.text
            end
          when 'bool'
            f[:values][control.checked ? 1 : 0]
          when 'entrance'
            control.value || ''
          when 'coords'
            control.text.empty? ? '' : control.text.split('  ').join(':')
          when 'float'
            if control.text.empty?
              ''
            else
              f_value = control.text.to_f
              f_value == 0.0 ? '0' : ('%.2f' % f_value.round(2)).chomp('.00').chomp('.0').chomp('0')
            end
          end
      values << v
      last_non_empty = i unless v.empty?
    end
    pattern = element[:pattern]
    value = if pattern == :seq
              last_non_empty ? values[0..last_non_empty].join(',') : ''
            else
              pattern.gsub(/#(\d\d)/) { |m| values[$1.to_i] }.gsub(/#(\d)/) { |m| values[$1.to_i] }
            end
    @args[:value] = value
  end

  def add_coords(i, j)
    field = @args[:active_field]
    return if field.nil?
    label = @args[:controls][field[:control_index]]
    values = label.text.split('  ')
    values.pop if field[:limit] > 0 && values.size >= field[:limit]
    values << "#{i},#{j}"
    label.text = values.join('  ')
    build_args_value
  end

  def save(stage_name = nil)
    if (stage_name && !SB.stage.start_pos && !SB.stage.entrances[0]) || (!stage_name && !SB.stage.entrances[0])
      @lbl_msg2.text = stage_name ? 'or a start point' : ''
      toggle_aux_panels(5)
      return false
    end

    stage_name ||= @txt_stage.text
    path = "#{Res.prefix}/stage/custom/#{stage_name}-#{@txt_section.text}"
    will_save = if File.exist? path
                  if @save_confirm
                    true
                  else
                    @confirm_action = Proc.new {
                      @save_confirm = true
                      save
                    }
                    show_confirm_panel('Overwrite?')
                    false
                  end
                else
                  true
                end
    if will_save
      @save_confirm = false
      FileUtils.mkdir_p("#{Res.prefix}/stage/custom")

      tiles_x = @section.tiles.size
      tiles_y = @section.tiles[0].size
      code = "#{tiles_x},#{tiles_y},#{@cur_exit},#{@ddl_ts.value},#{@ddl_bgm.value}#{@chk_dark.checked ? ',.' : @chk_rain.checked ? ',$' : ''}#"
      code += "#{@ddl_bg.value}#{@chk_bg_tile.checked ? '' : '!'}"
      code += ",#{@ddl_bg2.value}#{@chk_bg2_tile.checked ? '' : '!'}" if @ddl_bg2.value != '-'
      code += '#'

      count = 1
      last_element = get_cell_string(0, 0)
      (0...tiles_y).each do |j|
        (0...tiles_x).each do |i|
          next if i == 0 && j == 0
          element = get_cell_string i, j
          if element == last_element &&
            (last_element == '' ||
              ((last_element[0] == 'w' ||
                last_element[0] == 'p' ||
                last_element[0] == 'b' ||
                last_element[0] == 'f' ||
                last_element[0] == 'h') && last_element.size == 3))
            count += 1
          else
            if last_element == ''
              code += "_#{count}"
            else
              code += last_element + (count > 1 ? "*#{count}" : '')
            end
            code += ';'
            last_element = element
            count = 1
          end
        end
      end
      if last_element == ''
        code = code.chomp(';') + '#'
      else
        code += last_element + (count > 1 ? "*#{count}" : '') + '#'
      end
      @section.ramps.each { |r| code += "#{r.code};" }
      code.chop! unless @section.ramps.empty?

      code += "##{@bomb_mask}" if @bomb_mask

      File.open(path, 'w') { |f| f.write code }
    end
    true
  end

  def get_cell_string(i, j)
    tile = @section.tiles[i][j]
    str = ''
    str += "b#{'%02d' % tile.back}" if tile.back
    str += "f#{'%02d' % tile.fore}" if tile.fore
    str += "h#{'%02d' % tile.hide}" if tile.hide
    str += "p#{'%02d' % tile.pass}" if tile.pass
    str += "w#{'%02d' % tile.wall}" if tile.wall
    str += tile.code if tile.obj
    str
  end

  def update_bomb_mask(value, index)
    if @bomb_mask
      if value
        @bomb_mask |= (2**index)
        @bomb_mask = nil if @bomb_mask == 31
      else
        @bomb_mask &= ~(2**index)
      end
    elsif !value
      @bomb_mask = 31
      @bomb_mask &= ~(2**index)
    end
  end

  def toggle_aux_panels(show = nil)
    (4..9).each do |i|
      @panels[i].visible = i == show
    end
  end

  def toggle_aux_panel(index)
    @floating_panels.each do |p|
      p.visible = false
    end
    @args_panel.visible = false if @args_panel
    @panels[index].visible = !@panels[index].visible
  end

  def show_confirm_panel(msg)
    @lbl_conf.text = msg
    @floating_panels.each do |p|
      p.visible = false
    end
    @args_panel.visible = false if @args_panel
    toggle_aux_panels(6)
  end

  def hide_all_panels
    @floating_panels.each do |p|
      p.visible = false
    end
    toggle_aux_panels
    @args_panel.visible = false if @args_panel
  end

  def draw
    return unless @inited

    @section.map.foreach do |i, j, x, y|
      G.window.draw_quad x + 1, y + 1, NULL_COLOR,
                         x + 31, y + 1, NULL_COLOR,
                         x + 1, y + 31, NULL_COLOR,
                         x + 31, y + 31, NULL_COLOR, -3
    end
    @section.draw
    @section.tiles.each do |col|
      col.each do |tile|
        if tile.obj && tile.obj.is_visible(@section.map)
          tile.obj.draw(@section.map, @section)
          if tile.obj.is_a?(Entrance)
            x = tile.obj.x + C::TILE_SIZE - @section.map.cam.x
            y = tile.obj.y - @section.map.cam.y
            SB.text_helper.write_line(tile.code[1..-1], x, y, :right, 0, 255, nil, 0, 0, 0, 0, 1, 1)
          end
        end
      end
    end
    @section.map.foreach do |i, j, x, y|
      tile = @section.tiles[i][j]
      if tile.hide
        color = tile.hide == 0 ? HIDE_COLOR : NULL_COLOR
        G.window.draw_quad x, y, color,
                           x + C::TILE_SIZE, y, color,
                           x, y + C::TILE_SIZE, color,
                           x + C::TILE_SIZE, y + C::TILE_SIZE, color, 0
      end
      SB.font.draw_text('b', x, y, 0, 1, 1, 0xff000000) if tile.back
      SB.font.draw_text('f', x, y + 11, 0, 1, 1, 0xff000000) if tile.fore
      SB.font.draw_text('p', x, y + 22, 0, 1, 1, 0xff000000) if tile.pass
      SB.font.draw_text('w', x, y + 22, 0, 1, 1, 0xff000000) if tile.wall
    end

    s_pos = SB.stage.start_pos
    if s_pos
      @bomb[0].draw(s_pos[0] * C::TILE_SIZE - @section.map.cam.x, s_pos[1] * C::TILE_SIZE - @section.map.cam.y, 0, 2, 2)
    end

    if @selection && @selection.size == 4
      (@selection[0]..@selection[2]).each do |x|
        xx = x * 32 - @section.map.cam.x
        (@selection[1]..@selection[3]).each do |y|
          yy = y * 32 - @section.map.cam.y
          G.window.draw_quad xx, yy, SELECTION_COLOR,
                             xx + 32, yy, SELECTION_COLOR,
                             xx, yy + 32, SELECTION_COLOR,
                             xx + 32, yy + 32, SELECTION_COLOR, 2
        end
      end
    end

    @panels.each_with_index do |p, i|
      alpha = @over_panel[i] ? 255 : 153
      p.draw(alpha, 2)
      if p.visible && i == 8
        SB.text_helper.write_breaking(@help_text, (G.window.width - 1200) / 2 + 10, (G.window.height - 600) / 2 + 10, 1180, :justified, 0, alpha, 2, 1.5, 1.5)
      end
    end
    @args_panel.draw(@over_panel[@panels.size] ? 255 : 153, 2) if @args_panel

    @floating_panels.each(&:draw)

    unless @over_panel.any?
      p = @section.map.get_map_pos(Mouse.x, Mouse.y)
      SB.font.draw_text "#{p.x}, #{p.y}", Mouse.x, Mouse.y - 15, 1, 2, 2, BLACK
    end
  end
end
