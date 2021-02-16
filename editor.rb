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
include MiniGL

Cell = Struct.new(:back, :fore, :obj, :hide)

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
        @editor.txt_args.text = ''
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

  attr_reader :txt_args, :text_helper
  attr_writer :cur_element, :cur_index

  def initialize
    @tiles_x = @tiles_y = 300
    @map = Map.new(32, 32, @tiles_x, @tiles_y, C::EDITOR_SCREEN_WIDTH, C::EDITOR_SCREEN_HEIGHT)
    @objects = Array.new(@tiles_x) {
      Array.new(@tiles_y) {
        Cell.new
      }
    }

    @ramps = []
    @cur_index = -1

    bg_files = Dir["data/img/bg/*"].sort
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
    Dir["data/song/s*"].sort.select{ |f| !f.include?('-intro') }.each{ |f| bgm_options << f.split('/')[-1].chomp('.ogg') }
    @cur_bgm = 0

    exit_options = %w(/\\ → \\/ ← -)

    ts_files = Dir["data/tileset/*.png"].sort
    @tilesets = []
    ts_options = []
    ts_files.each do |f|
      num = f.split('/')[-1].chomp('.png')
      @tilesets << Gosu::Image.load_tiles(f, 16, 16, tileable: true, retro: true)
      ts_options << num
    end
    @cur_tileset = 0

    @cur_exit = 0

    el_files = Dir["data/img/editor/el/*"]
    @elements = {}
    @enemies = {}
    @objs = {}
    names = {}
    el_files.each do |f|
      name = f.split('/')[-1].chomp('.png')
      img = Res.img("editor_el_#{name}")
      index, name = name.split('-')
      index = index.to_i
      @crack_index = index if name == 'Crack'
      @elements[index] = img
      if name.end_with?('!')
        @enemies[index] = img
        names[index] = name.chomp('!')
      else
        @objs[index] = img
        names[index] = name
      end
    end

    @bomb = Res.img(:editor_Bomb)
    @fog = Res.img(:editor_fog)

    save_confirm = false

    @panels = [
      ################################## General ##################################
      Panel.new(0, 0, 720, 48, [
        Label.new(x: 10, y: 0, font: SB.font, text: 'W', scale_x: 2, scale_y: 2, anchor: :left),
        (txt_w = TextField.new(x: 22, y: 0, img: :editor_textField, font: SB.font, text: '300', allowed_chars: '0123456789', margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, anchor: :left)),
        Label.new(x: 70, y: 0, font: SB.font, text: 'H', scale_x: 2, scale_y: 2, anchor: :left),
        (txt_h = TextField.new(x: 84, y: 0, img: :editor_textField, font: SB.font, text: '300', allowed_chars: '0123456789', margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, anchor: :left)),
        Button.new(x: 130, y: 0, img: :editor_btn1, font: SB.font, text: 'OK', scale_x: 2, scale_y: 2, anchor: :left) do
          reset_map(txt_w.text.to_i, txt_h.text.to_i)
        end,
        Label.new(x: 200, y: 0, font: SB.font, text: 'BG', scale_x: 2, scale_y: 2, anchor: :left),
        (ddl_bg = DropDownList.new(x: 224, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: bg_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_bg = bg_options.index(v)
        end),
        Label.new(x: 268, y: -10, font: SB.font, text: 'tiled', scale_x: 2, scale_y: 2, anchor: :left),
        (chk_bg_tile = ToggleButton.new(x: 268, y: 10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :left)),
        Label.new(x: 318, y: 0, font: SB.font, text: 'BG2', scale_x: 2, scale_y: 2, anchor: :left),
        (ddl_bg2 = DropDownList.new(x: 354, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: bg2_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_bg2 = bg_options.index(v)
        end),
        Label.new(x: 398, y: -10, font: SB.font, text: 'tiled', scale_x: 2, scale_y: 2, anchor: :left),
        (chk_bg2_tile = ToggleButton.new(x: 398, y: 10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :left)),
        Label.new(x: 450, y: 0, font: SB.font, text: 'BGM', scale_x: 2, scale_y: 2, anchor: :left),
        (ddl_bgm = DropDownList.new(x: 486, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: bgm_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_bgm = bgm_options.index(v)
        end),
        Label.new(x: 532, y: 0, font: SB.font, text: 'Exit', scale_x: 2, scale_y: 2, anchor: :left),
        (ddl_exit = DropDownList.new(x: 572, y: 0, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: exit_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :left) do |_, v|
          @cur_exit = exit_options.index(v)
        end),
        Label.new(x: 30, y: -10, font: SB.font, text: 'Dark', scale_x: 2, scale_y: 2, anchor: :right),
        (chk_dark = ToggleButton.new(x: 10, y: -10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :right)),
        Label.new(x: 30, y: 10, font: SB.font, text: 'Rain', scale_x: 2, scale_y: 2, anchor: :right),
        (chk_rain = ToggleButton.new(x: 10, y: 10, img: :editor_chk, scale_x: 2, scale_y: 2, anchor: :right))
      ], :editor_pnl, :tiled, true, 2, 2, :top),
      ###########################################################################

      ################################# Tileset #################################
      Panel.new(0, 0, 68, 300, [
        (ddl_ts = DropDownList.new(x: 0, y: 4, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: ts_options, text_margin: 4, scale_x: 2, scale_y: 2, anchor: :top) do |_, v|
          @cur_tileset = ts_options.index(v)
          @floating_panels[0].set_children(@tilesets[@cur_tileset].map.with_index{ |t, i| { img: t, x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33 } })
        end),
        Button.new(x: 0, y: 38, img: :editor_btn1, font: SB.font, text: 'Wall', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :wall
        end,
        Button.new(x: 0, y: 38 + 44, img: :editor_btn1, font: SB.font, text: 'Pass', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :pass
        end,
        Button.new(x: 0, y: 38 + 88, img: :editor_btn1, font: SB.font, text: 'Hide', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :hide
        end,
        (ramp_btn = Button.new(x: 0, y: 38 + 132, img: :editor_btn1, font: SB.font, text: 'Ramp', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_floating_panel(1)
        end),
        (other_tile_btn = Button.new(x: 0, y: 38, img: :editor_btn1, font: SB.font, text: 'Other', scale_x: 2, scale_y: 2, anchor: :bottom) do
          toggle_floating_panel(0)
        end),
        (@ddl_tile_type = DropDownList.new(x: 0, y: 4, font: SB.font, img: :editor_ddl, opt_img: :editor_ddlOpt, options: %w(w p b f), text_margin: 4, scale_x: 2, scale_y: 2, anchor: :bottom)),
      ], :editor_pnl, :tiled, true, 2, 2, :left),
      ###########################################################################

      ################################### File ##################################
      Panel.new(0, 0, 520, 48, [
        Label.new(x: 7, y: 0, font: SB.font, text: 'World', scale_x: 2, scale_y: 2, anchor: :left),
        (txt_world = TextField.new(x: 59, y: 0, font: SB.font, img: :editor_textField, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, text: '1', anchor: :left)),
        Label.new(x: 107, y: 0, font: SB.font, text: 'Stage', scale_x: 2, scale_y: 2, anchor: :left),
        (txt_stage = TextField.new(x: 161, y: 0, font: SB.font, img: :editor_textField, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, text: '1', anchor: :left)),
        Label.new(x: 207, y: 0, font: SB.font, text: 'Section', scale_x: 2, scale_y: 2, anchor: :left),
        (txt_section = TextField.new(x: 279, y: 0, font: SB.font, img: :editor_textField, margin_x: 2, margin_y: 2, scale_x: 2, scale_y: 2, text: '1', anchor: :left)),
        (lbl_conf_save = Label.new(x: 0, y: 50, font: SB.font, text: 'Overwrite?', scale_x: 2, scale_y: 2, anchor: :bottom)),
        Button.new(x: 132, y: 0, img: :editor_btn1, font: SB.font, text: 'Clear', scale_x: 2, scale_y: 2, anchor: :right) do
          @objects = Array.new(@tiles_x) {
            Array.new(@tiles_y) {
              Cell.new
            }
          }
          @ramps.clear
        end,
        Button.new(x: 68, y: 0, img: :editor_btn1, font: SB.font, text: 'Load', scale_x: 2, scale_y: 2, anchor: :right) do
          path = "data/stage/custom/#{txt_stage.text}-#{txt_section.text}"
          if File.exist? path
            f = File.open(path)
            all = f.readline.chomp.split('#'); f.close
            infos = all[0].split(','); bg_infos = all[1].split(','); elms = all[2].split(';')
            @tiles_x = infos[0].to_i; @tiles_y = infos[1].to_i
            @map = Map.new(32, 32, @tiles_x, @tiles_y, C::EDITOR_SCREEN_WIDTH, C::EDITOR_SCREEN_HEIGHT)
            txt_w.text = infos[0]; txt_h.text = infos[1]
            @objects = Array.new(@tiles_x) {
              Array.new(@tiles_y) {
                Cell.new
              }
            }

            @cur_exit = infos[2].to_i
            ddl_exit.value = exit_options[@cur_exit]

            if bg_infos[0].end_with?('!')
              ddl_bg.value = bg_infos[0][0..-2]
              chk_bg_tile.checked = false
            else
              ddl_bg.value = bg_infos[0]
              chk_bg_tile.checked = true
            end
            @cur_bg = bg_options.index(ddl_bg.value)
            if bg_infos[1]
              if bg_infos[1].end_with?('!')
                ddl_bg2.value = bg_infos[1][0..-2]
                chk_bg2_tile.checked = false
              else
                ddl_bg2.value = bg_infos[1]
                chk_bg2_tile.checked = true
              end
              @cur_bg2 = bg_options.index(ddl_bg2.value)
            else
              ddl_bg2.value = '-'
              @cur_bg2 = nil
            end
            ddl_ts.value = infos[3]
            @cur_tileset = ts_options.index(ddl_ts.value)
            ddl_bgm.value = infos[4]
            @cur_bgm = bgm_options.index(ddl_bgm.value)

            chk_dark.checked = infos[5] && infos[5] == '.'
            chk_rain.checked = infos[5] && infos[5] == '$'

            i = 0; j = 0
            elms.each do |e|
              if e[0] == '_'
                i += e[1..-1].to_i
                if i >= @map.size.x
                  j += i / @map.size.x
                  i %= @map.size.x
                end
              elsif e.size > 3 && e[3] == '*'
                amount = e[4..-1].to_i
                tile = e[0..2]
                amount.times do
                  if e[0] == 'b'; @objects[i][j].back = tile
                  elsif e[0] == 'f'; @objects[i][j].fore = tile
                  elsif e[0] == 'h'; @objects[i][j].hide = tile
                  else; @objects[i][j].obj = tile; end
                  i += 1
                  begin i = 0; j += 1 end if i == @tiles_x
                end
              else
                ind = 0
                while ind < e.size
                  if e[ind] == 'b'; @objects[i][j].back = e.slice(ind, 3)
                  elsif e[ind] == 'f'; @objects[i][j].fore = e.slice(ind, 3)
                  elsif e[ind] == 'h'; @objects[i][j].hide = e.slice(ind, 3)
                  elsif e[ind] == 'p' || e[ind] == 'w'
                    @objects[i][j].obj = e.slice(ind, 3)
                  else
                    @objects[i][j].obj = e[ind..-1]
                    ind += 1000
                  end
                  ind += 3
                end
                i += 1
                begin i = 0; j += 1 end if i == @tiles_x
              end
            end
            @ramps.clear
            @ramps = all[3].split(';') if all[3]
          end
        end,
        Button.new(x: 4, y: 0, img: :editor_btn1, font: SB.font, text: 'Save', scale_x: 2, scale_y: 2, anchor: :right) do
          path = "data/stage/custom/#{txt_stage.text}-#{txt_section.text}"
          will_save = if save_confirm
                        save_confirm = lbl_conf_save.visible = false
                        File.delete path
                        true
                      elsif File.exist? path
                        save_confirm = lbl_conf_save.visible = true
                        false
                      else
                        true
                      end
          if will_save
            FileUtils.mkdir_p('data/stage/custom')

            code = "#{@tiles_x},#{@tiles_y},#{@cur_exit},#{ddl_ts.value},#{ddl_bgm.value}#{chk_dark.checked ? ',.' : chk_rain.checked ? ',$' : ''}#"
            code += "#{ddl_bg.value}#{chk_bg_tile.checked ? '' : '!'}"
            code += ",#{ddl_bg2.value}#{chk_bg2_tile.checked ? '' : '!'}" if ddl_bg2.value != '-'
            code += '#'

            count = 1
            last_element = get_cell_string(0, 0)
            (0...@tiles_y).each do |j|
              (0...@tiles_x).each do |i|
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
              code = code.chop + '#'
            else
              code += last_element + (count > 1 ? "*#{count}" : '') + '#'
            end
            @ramps.each { |r| code += "#{r};" }
            code.chop! unless @ramps.empty?

            File.open(path, 'w') { |f| f.write code }
          end
        end,
      ], :editor_pnl, :tiled, true, 2, 2, :bottom),
      ###########################################################################

      ################################# Elements ################################
      Panel.new(0, 0, 68, 300, [
        Button.new(x: 0, y: 4, img: :editor_btn1, font: SB.font, text: 'BOMB', scale_x: 2, scale_y: 2, anchor: :top) do
          @cur_element = :bomb
        end,
        Label.new(x: 0, y: 48, font: SB.font, text: 'Default', scale_x: 1, scale_y: 1, anchor: :top),
        (@chk_default = ToggleButton.new(x: 0, y: 60, img: :editor_chk, checked: true, scale_x: 2, scale_y: 2, anchor: :top)),
        (btn_obj = Button.new(x: 0, y: 100, img: :editor_btn1, font: SB.font, text: 'obj', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_floating_panel(2)
        end),
        (btn_enemy = Button.new(x: 0, y: 144, img: :editor_btn1, font: SB.font, text: 'enmy', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_floating_panel(3)
        end),
        Button.new(x: 0, y: 188, img: :editor_btn1, font: SB.font, text: 'args', scale_x: 2, scale_y: 2, anchor: :top) do
          toggle_args_panel
        end,
        Button.new(x: 0, y: 4, img: :editor_btn1, font: SB.font, text: 'offst', scale_x: 2, scale_y: 2, anchor: :bottom) do
          toggle_offset_panel
        end
      ], :editor_pnl, :tiled, true, 2, 2, :right),
      ###########################################################################

      ################################# Arguments ###############################
      Panel.new(0, 0, 200, 70, [
        Label.new(x: 0, y: 4, font: SB.font, text: 'Arguments:', scale_x: 2, scale_y: 2, anchor: :top),
        (@txt_args = TextField.new(x: 0, y: 30, img: :editor_textField2, font: SB.font, margin_x: 2, margin_y: 3, scale_x: 2, scale_y: 2, anchor: :top, max_length: 500))
      ], :editor_pnl, :tiled, true, 2, 2, :center),
      ###########################################################################

      ################################## Offset #################################
      Panel.new(0, 0, 200, 70, [
        Label.new(x: 0, y: 4, font: SB.font, text: 'Offset', scale_x: 2, scale_y: 2, anchor: :top),
        Label.new(x: 6, y: 7, font: SB.font, text: 'X', scale_x: 2, scale_y: 2, anchor: :left),
        (@txt_offset_x = TextField.new(x: 22, y: 7, img: :editor_textField, font: SB.font, margin_x: 2, margin_y: 3, scale_x: 2, scale_y: 2, anchor: :left)),
        Label.new(x: 66, y: 7, font: SB.font, text: 'Y', scale_x: 2, scale_y: 2, anchor: :left),
        (@txt_offset_y = TextField.new(x: 82, y: 7, img: :editor_textField, font: SB.font, margin_x: 2, margin_y: 3, scale_x: 2, scale_y: 2, anchor: :left)),
        Button.new(x: 4, y: 7, img: :editor_btn1, font: SB.font, text: 'OK', scale_x: 2, scale_y: 2, anchor: :right) do
          o_x = @txt_offset_x.text.to_i
          o_y = @txt_offset_y.text.to_i
          start_x = @selection ? @selection[0] : 0
          start_y = @selection ? @selection[1] : 0
          end_x = @selection ? @selection[2] : @tiles_x - 1
          end_y = @selection ? @selection[3] : @tiles_y - 1
          x_range = o_x > 0 ? end_x.downto(start_x) : start_x.upto(end_x)
          y_range = o_y > 0 ? end_y.downto(start_y) : start_y.upto(end_y)
          x_range.each do |i|
            y_range.each do |j|
              ii = i + o_x; jj = j + o_y
              @objects[ii][jj] = @objects[i][j] if ii >= 0 && ii < @tiles_x && jj >= 0 && jj < @tiles_y
              @objects[i][j] = Cell.new
            end
          end

          @ramps.map! { |r| p = r.split(':'); x, y = p[1].split(',').map(&:to_i); x >= start_x && x <= end_x && y >= start_y && y <= end_y ? "#{p[0]}:#{x + o_x},#{y + o_y}" : r }

          if @selection
            @selection[0] += o_x
            @selection[1] += o_y
            @selection[2] += o_x
            @selection[3] += o_y
          end
        end
      ], :editor_pnl, :tiled, true, 2, 2, :center)
      ###########################################################################
    ]

    @panels[4].visible = @panels[5].visible = lbl_conf_save.visible = false

    obj_items = []
    @objs.keys.sort.each_with_index do |k, i|
      obj_items << { img: @objs[k], x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33, name: names[k], index: k }
    end
    enemy_items = []
    @enemies.keys.sort.each_with_index do |k, i|
      enemy_items << { img: @enemies[k], x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33, name: names[k], index: k }
    end
    @floating_panels = [
      FloatingPanel.new(:tile, other_tile_btn.x + 40, other_tile_btn.y - 148, 337, 337, @tilesets[@cur_tileset].map.with_index{ |t, i| { img: t, x: 4 + (i % 10) * 33, y: 4 + (i / 10) * 33 } }, self),
      FloatingPanel.new(:ramp, ramp_btn.x + 40, ramp_btn.y, 271, 40, (0..7).map { |i| { img: Res.img("editor_ramp#{i}"), x: 4 + i * 33, y: 4 } }, self),
      FloatingPanel.new(:obj, btn_obj.x - 337, btn_obj.y, 337, 300, obj_items, self),
      FloatingPanel.new(:enemy, btn_enemy.x - 337, btn_enemy.y, 337, 300, enemy_items, self),
    ]

    @dropdowns = [ddl_bg, ddl_bgm, ddl_exit, ddl_ts, @ddl_tile_type]

    @ramp_sizes = %w(11 21 32 12)
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
    @wall_ish_tiles = [11, 7, 46, 47, 8, 9, 17, 18, 26, 36, 37, 48, 49, 27, 28, 38, 39, 19, 29]
  end

  def needs_cursor?
    true
  end

  def update
    unless @inited
      @inited = true
    end

    SB.close_editor if KB.key_pressed?(Gosu::KbEscape)
    toggle_args_panel if KB.key_pressed?(Gosu::KbReturn)
    toggle_offset_panel if KB.key_pressed?(Gosu::KbTab)
    @show_codes = !@show_codes if KB.key_pressed?(Gosu::KB_PERIOD)

    @over_panel = [false, false, false, false, false]
    @dropdowns.each_with_index do |d, i|
      h = d.instance_eval('@open') ? d.instance_eval('@max_h') : d.h
      @over_panel[i < 3 ? 0 : 1] = true if Mouse.over?(d.x, d.y, d.w, h)
    end
    @floating_panels.each_with_index do |p, i|
      p.update
      @over_panel[i < 2 ? 1 : 3] = true if p.visible && Mouse.over?(p.x, p.y, p.w, p.h)
    end
    @panels.each_with_index do |p, i|
      p.update
      @over_panel[i] = true if p.visible && Mouse.over?(p.x, p.y, p.w, p.h)
    end

    speed = KB.key_down?(Gosu::KbLeftShift) || KB.key_down?(Gosu::KbRightShift) ? 10 : 20
    @map.move_camera 0, -speed if KB.key_down?(Gosu::KbUp) || KB.key_down?(Gosu::KB_W)
    @map.move_camera speed, 0 if KB.key_down?(Gosu::KbRight) || KB.key_down?(Gosu::KB_D)
    @map.move_camera 0, speed if KB.key_down?(Gosu::KbDown) || KB.key_down?(Gosu::KB_S)
    @map.move_camera -speed, 0 if KB.key_down?(Gosu::KbLeft) || KB.key_down?(Gosu::KB_A)

    return if @over_panel.any?

    ctrl = KB.key_down?(Gosu::KbLeftControl) || KB.key_down?(Gosu::KbRightControl)
    alt = KB.key_down?(Gosu::KbLeftAlt) || KB.key_down?(Gosu::KbRightAlt)
    mp = @map.get_map_pos(Mouse.x, Mouse.y)
    return if mp.x >= @tiles_x || mp.y >= @tiles_y
    if Mouse.double_click?(:left)
      check_fill(mp.x, mp.y, ctrl)
    elsif Mouse.button_pressed?(:left)
      if ctrl
        case @cur_element
        when /(obj|enemy)/
          @txt_args.text += (@txt_args.text.empty? ? '' : ':') + "#{mp.x},#{mp.y}"
        when :pass
          @pass_start = [mp.x, mp.y]
        end
      elsif alt
        @selection = [mp.x, mp.y]
      else
        @selection = nil
        case @cur_element
        when :pass
          @pass_start = [mp.x, mp.y]
        when :ramp
          @ramps << (@cur_index < 4 ? 'l' : 'r') + @ramp_sizes[@cur_index % 4] + ":#{mp.x},#{mp.y}"
          @ramp_tiles[@cur_index].each do |t|
            @objects[mp.x + t[0]][mp.y + t[1]].obj = nil
            @objects[mp.x + t[0]][mp.y + t[1]].back = 'b%02d' % t[2]
          end
        when :bomb
          @objects[mp.x][mp.y].obj = '!' + @txt_args.text + (@chk_default.checked ? '!' : '')
        end
      end
    elsif !alt && Mouse.button_down?(:left)
      if ctrl
        @objects[mp.x][mp.y].hide = 'h99' if @cur_element == :hide
      else
        case @cur_element
        when :wall
          set_wall_tile(mp.x, mp.y, true)
          set_surrounding_wall_tiles(mp.x, mp.y)
        when :hide
          @objects[mp.x][mp.y].hide = 'h00'
        when :tile
          t = @ddl_tile_type.value
          prop = t == 'w' || t == 'p' ? :obj= : t == 'b' ? :back= : :fore=
          @objects[mp.x][mp.y].send(prop, t + '%02d' % @cur_index)
        when :obj
          @objects[mp.x][mp.y].obj = '@' + ('%02d' % @cur_index) + (@txt_args.text.empty? ? '' : ":#{@txt_args.text}")
        when :enemy
          @objects[mp.x][mp.y].obj = '@' + ('%02d' % @cur_index) + (@txt_args.text.empty? ? '' : ":#{@txt_args.text}")
        end
      end
    elsif Mouse.button_released?(:left)
      if alt
        @selection << mp.x << mp.y
      else
        @selection = nil
        if @cur_element == :pass
          min_x, max_x = mp.x < @pass_start[0] ? [mp.x, @pass_start[0]] : [@pass_start[0], mp.x]
          min_y, max_y = mp.y < @pass_start[1] ? [mp.y, @pass_start[1]] : [@pass_start[1], mp.y]
          (min_y..max_y).each do |j|
            (min_x..max_x).each do |i|
              cell = @objects[i][j]
              next if ctrl && %w(b11 b43 b44 b45).include?(cell.back)
              if j == min_y
                next if ctrl && cell.obj && cell.obj[0] == 'w'
                cell.obj = 'p' + (i == min_x ? '40' : i == max_x ? '42' : '41')
              else
                cell.back = 'b' + (i == min_x ? '43' : i == max_x ? '45' : '44')
                cell.obj = nil if cell.obj && cell.obj[0] == 'p' && !ctrl
              end
            end
          end
          @pass_start = nil
        end
      end
    elsif ctrl && Mouse.button_pressed?(:right) || !ctrl && Mouse.button_down?(:right)
      @ramps.each do |ramp|
        coords = ramp.split(':')[1].split(',')
        x = coords[0].to_i; y = coords[1].to_i
        a = ramp[1] == "'" ? 2 : 1
        w = ramp[a].to_i * 32; h = ramp[a + 1].to_i * 32
        pos = @map.get_screen_pos(x, y)
        @ramps.delete(ramp) if Mouse.over?(pos.x, pos.y, w, h)
      end
      obj = @objects[mp.x][mp.y].obj
      if @objects[mp.x][mp.y].hide
        @objects[mp.x][mp.y].hide = nil
      elsif @objects[mp.x][mp.y].fore
        @objects[mp.x][mp.y].fore = nil
      elsif obj
        @objects[mp.x][mp.y].obj = nil
        if obj[0] == 'w' && obj[1..2].to_i < 50
          set_surrounding_wall_tiles(mp.x, mp.y)
        end
      else
        b = @objects[mp.x][mp.y].back
        @objects[mp.x][mp.y].back = nil
        set_surrounding_wall_tiles(mp.x, mp.y) if b && b[1..2].to_i < 50
      end
    end
  end

  def toggle_floating_panel(index)
    @floating_panels.each_with_index do |p, i|
      p.visible = i == index ? !p.visible : false
    end
  end

  def toggle_args_panel
    @panels[4].visible = !@panels[4].visible
    if @panels[4].visible
      @txt_args.focus
    else
      @txt_args.unfocus
    end
  end

  def toggle_offset_panel
    @panels[5].visible = !@panels[5].visible
    if @panels[5].visible
      @txt_offset_x.focus
    else
      @txt_offset_x.unfocus
      @txt_offset_y.unfocus
    end
  end

  def set_wall_tile(i, j, must_set = false)
    @crack = false
    return if i < 0 || j < 0 || i >= @map.size.x || j >= @map.size.y
    return unless must_set || @objects[i][j].obj && @objects[i][j].obj[0] == 'w' && @objects[i][j].obj[1..2].to_i < 50 || @objects[i][j].back == 'b11'
    up = j == 0 || wall_ish_tile?(i, j - 1)
    rt = i == @map.size.x - 1 || wall_ish_tile?(i + 1, j)
    dn = j == @map.size.y - 1 || wall_ish_tile?(i, j + 1)
    lf = i == 0 || wall_ish_tile?(i - 1, j)
    tl = !up && i > 0 && j > 0 && (wall_ish_tile?(i - 1, j - 1) || wall_ish_tile?(i - 1, j, true))
    tr = !up && i < @map.size.x - 1 && j > 0 && (wall_ish_tile?(i + 1, j - 1) || wall_ish_tile?(i + 1, j, true))
    tile =
      if up && rt && dn && lf; @crack ? 'w11' : 'b11'
      elsif up && rt && dn; 'w10'
      elsif up && rt && lf; 'w21'
      elsif up && dn && lf; 'w12'
      elsif up && rt; 'w20'
      elsif up && dn; 'w13'
      elsif up && lf; 'w22'
      elsif up; 'w23'
      elsif tl && tr && rt && dn && lf; 'w06'
      elsif tl && rt && dn && lf; 'w04'
      elsif tr && rt && dn && lf; 'w05'
      elsif tl && tr && rt && lf; 'w16'
      elsif tl && rt && lf; 'w14'
      elsif tr && rt && lf; 'w15'
      elsif tr && rt && dn; 'w24'
      elsif tl && dn && lf; 'w25'
      elsif tr && rt; 'w34'
      elsif tl && lf; 'w35'
      elsif rt && dn && lf; 'w01'
      elsif rt && dn; 'w00'
      elsif rt && lf; 'w31'
      elsif dn && lf; 'w02'
      elsif rt; 'w30'
      elsif dn; 'w03'
      elsif lf; 'w32'
      else; 'w33'; end
    @objects[i][j].back = tile[0] == 'b' ? tile : nil
    @objects[i][j].obj = tile[0] == 'b' ? nil : tile
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
    !back_only && @objects[i][j].obj &&
      (@objects[i][j].obj[0] == 'w' && @objects[i][j].obj[1..2].to_i < 50 || @objects[i][j].obj[1..2].to_i == @crack_index && (@crack = true)) ||
      @objects[i][j].back && @wall_ish_tiles.include?(@objects[i][j].back[1..-1].to_i)
  end

  def reset_map(tiles_x, tiles_y)
    if tiles_x < @tiles_x
      @objects = @objects[0...tiles_x]
    elsif tiles_x > @tiles_x
      min_y = tiles_y < @tiles_y ? tiles_y : @tiles_y
      (@tiles_x...tiles_x).each do |i|
        @objects[i] = []
        (0...min_y).each { |j| @objects[i][j] = Cell.new }
      end
    end
    if tiles_y < @tiles_y
      @objects.map! { |o| o[0...tiles_y] }
    elsif tiles_y > @tiles_y
      @objects.each do |o|
        (@tiles_y...tiles_y).each { |j| o[j] = Cell.new }
      end
    end
    ramps_to_remove = []
    @ramps.each do |r|
      w = r[1].to_i; h = r[2].to_i
      x, y = r.split(':')[1].split(',').map(&:to_i)
      ramps_to_remove << r if x + w > tiles_x || y + h > tiles_y
    end
    @ramps -= ramps_to_remove
    @map = Map.new 32, 32, tiles_x, tiles_y, C::EDITOR_SCREEN_WIDTH, C::EDITOR_SCREEN_HEIGHT
    @tiles_x = tiles_x; @tiles_y = tiles_y
  end

  def check_fill(i, j, ctrl)
    return unless @cur_element == :wall || @cur_element == :hide || @cur_element == :tile && @ddl_tile_type.value == 'b'
    if @cur_element == :wall
      @objects[i][j].back = 'b11'
      set_surrounding_wall_tiles(i, j)
    elsif @cur_element == :hide
      @objects[i][j].hide = ctrl ? 'h99' : 'h00'
    else
      @objects[i][j].back = "b#{@cur_index}"
    end
    check_fill i - 1, j, ctrl if i > 0 and cell_empty?(i - 1, j)
    check_fill i + 1, j, ctrl if i < @tiles_x - 1 and cell_empty?(i + 1, j)
    check_fill i, j - 1, ctrl if j > 0 and cell_empty?(i, j - 1)
    check_fill i, j + 1, ctrl if j < @tiles_y - 1 and cell_empty?(i, j + 1)
  end

  def cell_empty?(i, j)
    @cur_element == :wall && @objects[i][j].back.nil? && @objects[i][j].fore.nil? && @objects[i][j].obj.nil? ||
      @cur_element == :hide && @objects[i][j].hide.nil? ||
      @cur_element == :tile && @objects[i][j].back.nil? && (@objects[i][j].obj.nil? || @objects[i][j].obj[0] != 'w' && @objects[i][j].obj[0] != 'p')
  end

  def get_cell_string(i, j)
    str = ''
    str += @objects[i][j].back if @objects[i][j].back
    str += @objects[i][j].fore if @objects[i][j].fore
    str += @objects[i][j].hide if @objects[i][j].hide
    str += @objects[i][j].obj if @objects[i][j].obj
    str
  end

  def draw
    return unless @inited

    G.window.clear 0x666666

    bg = @bgs[@cur_bg]
    bgx = 0
    while bgx < C::EDITOR_SCREEN_WIDTH
      bgy = 0
      while bgy < C::EDITOR_SCREEN_HEIGHT
        bg.draw(bgx, bgy, 0, 2, 2)
        bgy += 2 * bg.height
      end
      bgx += 2 * bg.width
    end
    if @cur_bg2
      bg = @bgs[@cur_bg2]
      bgx = 0
      while bgx < C::EDITOR_SCREEN_WIDTH
        bgy = 0
        while bgy < C::EDITOR_SCREEN_HEIGHT
          bg.draw(bgx, bgy, 0, 2, 2)
          bgy += 2 * bg.height
        end
        bgx += 2 * bg.width
      end
    end

    @map.foreach do |i, j, x, y|
      G.window.draw_quad x + 1, y + 1, NULL_COLOR,
                         x + 31, y + 1, NULL_COLOR,
                         x + 1, y + 31, NULL_COLOR,
                         x + 31, y + 31, NULL_COLOR, 0
      if @objects[i][j].back
        @tilesets[@cur_tileset][@objects[i][j].back[1..2].to_i].draw x, y, 0, 2, 2
        SB.font.draw_text 'b', x + 20, y + 18, 1, 1, 1, BLACK if @show_codes
      end
      draw_object i, j, x, y
      if @objects[i][j].fore
        @tilesets[@cur_tileset][@objects[i][j].fore[1..2].to_i].draw x, y, 0, 2, 2
        SB.font.draw_text 'f', x + 20, y + 8, 1, 1, 1, BLACK if @show_codes
      end
      if @objects[i][j].hide
        if @objects[i][j].hide == 'h00'
          G.window.draw_quad x, y, HIDE_COLOR,
                             x + 32, y, HIDE_COLOR,
                             x, y + 32, HIDE_COLOR,
                             x + 32, y + 32, HIDE_COLOR, 0
        else
          @fog.draw(x, y, 0, 2, 2)
        end
      end
    end
    @ramps.each do |r|
      p = r.split(':')[1].split(',')
      pos = @map.get_screen_pos(p[0].to_i, p[1].to_i)
      a = r[1] == "'" ? 2 : 1
      w = r[a].to_i * 32; h = r[a + 1].to_i * 32
      draw_ramp pos.x, pos.y, w, h, r[0] == 'l', a == 2
    end

    if @selection && @selection.size == 4
      (@selection[0]..@selection[2]).each do |x|
        xx = x * 32 - @map.cam.x
        (@selection[1]..@selection[3]).each do |y|
          yy = y * 32 - @map.cam.y
          G.window.draw_quad xx, yy, SELECTION_COLOR,
                             xx + 32, yy, SELECTION_COLOR,
                             xx, yy + 32, SELECTION_COLOR,
                             xx + 32, yy + 32, SELECTION_COLOR, 2
        end
      end
    end

    @panels.each_with_index do |p, i|
      p.draw(@over_panel[i] ? 255 : 153, 2)
    end

    @floating_panels.each(&:draw)

    unless @over_panel.any?
      p = @map.get_map_pos(Mouse.x, Mouse.y)
      SB.font.draw_text "#{p.x}, #{p.y}", Mouse.x, Mouse.y - 15, 1, 2, 2, BLACK
    end
  end

  def draw_object(i, j, x, y)
    obj = @objects[i][j].obj
    if obj
      if obj[0] == 'w' || obj[0] == 'p'
        @tilesets[@cur_tileset][obj[1..2].to_i].draw x, y, 0, 2, 2
        SB.font.draw_text obj[0], x + 20, y - 2, 1, 1, 1, BLACK if @show_codes
      elsif obj[0] == '!'
        @bomb.draw x, y, 0, 2, 2
        SB.font.draw_text obj[1..-1], x, y, 0, 1, 1, BLACK if @show_codes
      else
        code = obj[1..-1].split(':')
        @elements[code[0].to_i].draw x, y, 0, 2, 2
        if @show_codes && code.size > 1
          code[1..-1].each_with_index do |c, i|
            SB.font.draw_text c, x, y + i * 9, 0, 1, 1, BLACK
          end
        end
      end
    end
  end

  def draw_ramp(x, y, w, h, left, up)
    G.window.draw_triangle x + (left ? w : 0), y, up ? RAMP_UP_COLOR : RAMP_COLOR,
                  x, y + h, up ? RAMP_UP_COLOR : RAMP_COLOR,
                  x + w, y + h, up ? RAMP_UP_COLOR : RAMP_COLOR, 0
  end
end
