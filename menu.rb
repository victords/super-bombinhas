require 'minigl'
require_relative 'world'
require_relative 'player'
require_relative 'form'
include MiniGL

class MenuButton < Button
  include FormElement

  def initialize(y, text_id, x = 310, &action)
    super(x, y, SB.font, SB.text(text_id), :ui_button1, 0, 0x808080, 0, 0, true, false, 0, 7, 0, 0, 0, &action)
  end
end

class SavedGameButton < Button
  include FormElement

  def initialize(x, y)
    super x, y, nil, nil, nil, 0, 0, 0x666666, 0x666666, true, true, 0, 0, 370, 80
  end
end

class MenuText
  include FormElement

  def initialize(text, x, y, width = 760, mode = :justified)
    @text = text
    @x = x
    @y = y
    @width = width
    @mode = mode
    @writer = TextHelper.new SB.font, 5
  end

  def update; end

  def set_position(x, y)
    @x = x; @y = y
  end

  def draw
    @writer.write_breaking(@text, @x, @y, @width, @mode)
  end
end

class SavedGame
  include FormElement

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

  def update; end

  def set_position(x, y)
    @x = x; @y = y
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

    continue_screen_elements = []
    @saved_games = []
    games = Dir["#{Res.prefix}save/*"][0..9].map { |x| x.split('/')[-1].chomp('.sbg') }.sort
    games.each_with_index do |g, i|
      save_data = IO.readlines("#{Res.prefix}save/#{g}.sbg").map { |l| l.chomp }
      saved_game = SavedGame.new((i+1), 20 + (i % 2) * 390, 95 + (i / 2) * 90, g, save_data[1], save_data[0], save_data[4], save_data[3])
      @saved_games << saved_game
      continue_screen_elements << saved_game
      continue_screen_elements <<
        SavedGameButton.new(20 + (i % 2) * 390, 95 + (i / 2) * 90) {
          SB.load_game g
        }
    end
    continue_screen_elements << MenuButton.new(550, :back) {
      @form.go_to_section 1
    }
    continue_screen_elements << MenuText.new(SB.text(:choose_game), 780, 40, 380, :right)

    @form = Form.new([
      MenuButton.new(295, :play) {
        @form.go_to_section 1
      },
      MenuButton.new(345, :options) {
        @form.go_to_section 3
      },
      MenuButton.new(395, :credits) {
        @form.go_to_section 4
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
        @form.go_to_section 2
      },
      MenuButton.new(420, :back) {
        @form.go_to_section 0
      }
    ], continue_screen_elements, [
      MenuButton.new(550, :save, 215) {
        puts 'save options'
      },
      MenuButton.new(550, :cancel, 405) {
        @form.go_to_section 0
      },
      MenuText.new('Primeira opção', 20, 200),
      MenuText.new('Segunda opção', 20, 250),
      MenuText.new('Mais uma opção aqui', 20, 300),
      MenuText.new('Quarta opção', 20, 350)
    ], [
      MenuButton.new(550, :back) {
        @form.go_to_section 0
      },
      MenuText.new(
          'Texto dos créditos aqui. Texto bem longo, podendo quebrar linha. '\
        'Texto bem longo, podendo quebrar linha. Pode também ter quebras de '\
        "linha explícitas.\nAqui tem uma quebra de linha explícita.\n\n"\
        'Duas quebras seguidas.', 400, 200, 600, :center)
    ])
  end

  def update
    @form.update
  end

  def reset
    @form.go_to_section 0
  end

  def draw
    @bg.draw 0, 0, 0
    @title.draw 0, 0, 0, @form.cur_section_index == 2 ? 0.5 : 1, @form.cur_section_index == 2 ? 0.5 : 1
    @form.draw
    if @form.cur_section_index == 2 # continue
      @saved_games.each do |s|
        s.draw
      end
    end
  end
end
