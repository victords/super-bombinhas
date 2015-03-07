require 'minigl'
require_relative 'world'
require_relative 'player'
include MiniGL

class MenuButton < Button
  def initialize(y, text_id, x = 310, &action)
    super(x, y, SB.font, SB.text(text_id), :ui_button1, 0, 0x808080, 0, 0, true, false, 0, 7, 0, 0, 0, &action)
  end
end

class MenuText
  def initialize(text, x, y, width = 760, mode = :justified)
    @text = text
    @x = x
    @y = y
    @width = width
    @mode = mode
    @writer = TextHelper.new SB.font, 5
  end

  def draw
    @writer.write_breaking(@text, @x, @y, @width, @mode)
  end
end

class SavedGame
  def initialize(index, x, y, name, bomb, world_stage, specs, score)
    @index = index
    @x = x
    @y = y
    @name = name
    @world_stage = world_stage
    @specs = specs.split(',').size
    @score = score
    @bg = Res.img(:ui_bgSavedGame)
    @bomb = Res.img("icon_Bomba#{bomb.capitalize}")
    @map_icon = Res.img(:icon_map)
    @spec_icon = Res.img(:icon_spec)
    @score_icon = Res.img(:icon_score)
    @writer = TextHelper.new SB.font
  end

  def draw
    @bg.draw @x, @y, 0
    @bomb.draw @x + 5, @y + 5, 0
    @map_icon.draw @x + 45, @y + 40, 0
    @spec_icon.draw @x + 135, @y + 40, 0
    @score_icon.draw @x + 225, @y + 40, 0
    SB.font.draw_rel @index.to_s, @x + 365, @y + 40, 0, 1, 0.5, 3, 3, 0x80000000
    @writer.write_line @name, @x + 45, @y + 5, :left, 0xffffff, :border
    @writer.write_line @world_stage, @x + 75, @y + 40
    @writer.write_line @specs.to_s, @x + 165, @y + 40
    @writer.write_line @score, @x + 255, @y + 40
  end
end

class Menu
  def initialize
    @bg = Res.img :bg_start1, true, false, '.jpg'
    @title = Res.img :ui_title, true

    continue_screen_buttons = [
      MenuButton.new(550, :back) {
        set_button_group 1
      }
    ]
    @saved_games = []
    games = Dir["#{Res.prefix}save/*"][0..9].map { |x| x.split('/')[-1].chomp('.sbg') }.sort
    games.each_with_index do |g, i|
      save_data = IO.readlines("#{Res.prefix}save/#{g}.sbg").map { |l| l.chomp }
      @saved_games << SavedGame.new((i+1), 20 + (i % 2) * 390, 95 + (i / 2) * 90, g, save_data[1], save_data[0], save_data[4], save_data[3])
      continue_screen_buttons <<
        Button.new(20 + (i % 2) * 390, 95 + (i / 2) * 90, nil, nil, nil, 0, 0, 0x666666, 0x666666, true, true, 0, 0, 370, 80) {
          SB.load_game g
        }
    end

    @btns = [[
      MenuButton.new(295, :play) {
        set_button_group 1
      },
      MenuButton.new(345, :options) {
        set_button_group 3
      },
      MenuButton.new(395, :credits) {
        set_button_group 4
      },
      MenuButton.new(445, :exit) {
        exit
      }
    ], [
      MenuButton.new(320, :new_game) {
        SB.world = World.new
        SB.player = Player.new
        SB.state = :map
      },
      MenuButton.new(370, :continue) {
        set_button_group 2
      },
      MenuButton.new(420, :back) {
        set_button_group 0
      }
    ], continue_screen_buttons, [
      MenuButton.new(550, :save, 215) {
        puts 'save options'
      },
      MenuButton.new(550, :cancel, 405) {
        set_button_group 0
      }
    ], [
      MenuButton.new(550, :back) {
        set_button_group 0
      }
    ]]
    @texts = [[
    ], [
    ], [
      MenuText.new(SB.text(:choose_game), 780, 40, 380, :right)
    ], [
      MenuText.new('Primeira opção', 20, 200),
      MenuText.new('Segunda opção', 20, 250),
      MenuText.new('Mais uma opção aqui', 20, 300),
      MenuText.new('Quarta opção', 20, 350)
    ], [
      MenuText.new(
        'Texto dos créditos aqui. Texto bem longo, podendo quebrar linha. '\
        'Texto bem longo, podendo quebrar linha. Pode também ter quebras de '\
        "linha explícitas.\nAqui tem uma quebra de linha explícita.\n\n"\
        'Duas quebras seguidas.', 400, 200, 600, :center)
    ]]
    @highlight1 = Sprite.new(0, 0, :ui_highlight1, 1, 3)
    @highlight2 = Sprite.new(0, 0, :ui_highlight2, 1, 3)
    @highlight = @highlight1

    set_button_group 0
  end

  def set_button_group(group)
    @cur_btn_group = group
    @cur_btn = 0
    set_highlight_position
  end

  def set_highlight_position
    cur_btn = @btns[@cur_btn_group][@cur_btn]
    x_off = -1
    y_off = -5
    if cur_btn.is_a? MenuButton
      @highlight = @highlight1 if @highlight == @highlight2
    else
      @highlight = @highlight2 if @highlight == @highlight1
      x_off = -7
      y_off = -7
    end
    @highlight.x = cur_btn.x + x_off
    @highlight.y = cur_btn.y + y_off
  end

  def update
    mouse_moved = (Mouse.x != @mouse_prev_x or Mouse.y != @mouse_prev_y)

    @btns[@cur_btn_group].each_with_index do |b, i|
      b.update
      if b.state == :down or (mouse_moved and b.state == :over)
        @cur_btn = i
        set_highlight_position
      end
    end
    @highlight.animate([0, 1, 2, 1], 12)

    if KB.key_pressed? Gosu::KbDown or KB.key_pressed? Gosu::KbRight
      @cur_btn += 1
      @cur_btn = 0 if @cur_btn == @btns[@cur_btn_group].length
      set_highlight_position
    elsif KB.key_pressed? Gosu::KbUp or KB.key_pressed? Gosu::KbLeft
      @cur_btn -= 1
      @cur_btn = @btns[@cur_btn_group].length - 1 if @cur_btn < 0
      set_highlight_position
    elsif KB.key_pressed?(Gosu::KbReturn) or KB.key_pressed?(Gosu::KbSpace)
      @btns[@cur_btn_group][@cur_btn].click
    end

    @mouse_prev_x = Mouse.x
    @mouse_prev_y = Mouse.y
  end

  def draw
    @bg.draw 0, 0, 0
    @title.draw 0, 0, 0, @cur_btn_group == 2 ? 0.5 : 1, @cur_btn_group == 2 ? 0.5 : 1
    @btns[@cur_btn_group].each do |b|
      b.draw
    end
    @texts[@cur_btn_group].each do |t|
      t.draw
    end
    if @cur_btn_group == 2 # continue
      @saved_games.each do |s|
        s.draw
      end
    end
    @highlight.draw
  end
end
