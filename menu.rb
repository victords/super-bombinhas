require 'minigl'
require_relative 'world'
require_relative 'player'
require_relative 'form'
include MiniGL

class SavedGameButton < Button
  include FormElement

  def initialize(x, y)
    super(x: x, y: y, width: 370, height: 80)
  end
end

class NewGameButton < Button
  include FormElement

  attr_reader :text_id

  def initialize(index, x, y, menu)
    super(x: x, y: y, width: 370, height: 80) {
      menu.go_to_new_game(@index - 1)
    }
    @index = index
    @img = Res.img(:ui_bgGameSlot)
    @text = SB.text(:new_game)
    @text_id = :new_game
  end

  def draw(alpha = 0xff, z_index = 0)
    @img.draw @x, @y, 0
    SB.font.draw_rel @index.to_s, @x + 365, @y + 40, 0, 1, 0.5, 3, 3, 0x80000000
    SB.text_helper.write_line @text, @x + 185, @y + 30, :center, 0xffffff, 255, :border
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
    @bg = Res.img(:ui_bgGameSlot)
    @bomb = Res.img("icon_Bomba#{bomb.capitalize}")
    @map_icon = Res.img(:icon_map)
    @spec_icon = Res.img(:icon_spec)
    @score_icon = Res.img(:icon_score)
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
    SB.text_helper.write_line @name, @x + 45, @y + 5, :left, 0xffffff, 255, :border
    SB.text_helper.write_line @world_stage, @x + 75, @y + 40
    SB.text_helper.write_line @specs.to_s, @x + 165, @y + 40
    SB.text_helper.write_line @score, @x + 255, @y + 40
  end
end

class Menu
  class << self
    def initialize
      @bg = Res.img :bg_start1, true, false, '.jpg'
      @title = Res.img :ui_title, true

      @form = Form.new([
        MenuButton.new(295, :play) {
          @form.go_to_section 1
        },
        MenuButton.new(345, :options) {
          @lang = SB.lang
          @sound_volume = SB.sound_volume
          @music_volume = SB.music_volume
          @form.go_to_section 5
        },
        MenuButton.new(395, :credits) {
          @form.go_to_section 6
        },
        MenuButton.new(445, :exit, true) {
          exit
        }
      ], [], [
        MenuButton.new(345, :continue) {
          SB.load_game @selected_game
        },
        MenuButton.new(395, :delete) {
          @form.go_to_section 4
        },
        MenuButton.new(445, :back, true) {
          @form.go_to_section 1
        }
      ], [
        (@txt_name = MenuTextField.new(295)),
        MenuText.new(:what_name, 400, 220, 400, :center),
        MenuButton.new(345, :play) {
          SB.new_game(@txt_name.text.downcase, @new_game_index) unless @txt_name.text.empty?
        },
        MenuButton.new(395, :back, true) {
          @form.go_to_section 1
        }
      ], [
        MenuText.new(:delete_confirm, 400, 270, 400, :center),
        MenuButton.new(345, :no, true) {
          @form.go_to_section 1
        },
        MenuButton.new(395, :yes) {
          File.delete(@selected_game)
          add_game_slots
          @form.go_to_section 1
        }
      ], [
        MenuButton.new(550, :save, false, 219) {
          SB.save_options
          @form.go_to_section 0
        },
        MenuButton.new(550, :cancel, true, 409) {
          SB.lang = @lang
          SB.sound_volume = @s_v_text.num = @sound_volume
          SB.music_volume = @m_v_text.num = @music_volume
          @form.go_to_section 0
        },
        MenuText.new(:language, 20, 200),
        MenuText.new(:lang_name, 590, 200, 300, :center),
        MenuArrowButton.new(400, 192, 'Left') {
          SB.change_lang(-1)
        },
        MenuArrowButton.new(744, 192, 'Right') {
          SB.change_lang
        },
        MenuText.new(:sound_volume, 20, 300),
        (@s_v_text = MenuNumber.new(SB.sound_volume, 590, 300, :center)),
        MenuArrowButton.new(400, 292, 'Left') {
          SB.change_volume('sound', -1)
          @s_v_text.num = SB.sound_volume
        },
        MenuArrowButton.new(744, 292, 'Right') {
          SB.change_volume('sound')
          @s_v_text.num = SB.sound_volume
        },
        MenuText.new(:music_volume, 20, 400),
        (@m_v_text = MenuNumber.new(SB.music_volume, 590, 400, :center)),
        MenuArrowButton.new(400, 392, 'Left') {
          SB.change_volume('music', -1)
          @m_v_text.num = SB.music_volume
        },
        MenuArrowButton.new(744, 392, 'Right') {
          SB.change_volume('music')
          @m_v_text.num = SB.music_volume
        }
      ], [
        MenuButton.new(550, :back, true) {
          @form.go_to_section 0
        },
        MenuText.new(
          'Texto dos créditos aqui. Texto bem longo, podendo quebrar linha. '\
          'Texto bem longo, podendo quebrar linha. Pode também ter quebras de '\
          "linha explícitas.\nAqui tem uma quebra de linha explícita.\n\n"\
          'Duas quebras seguidas.', 400, 200, 600, :center)
      ])

      add_game_slots
    end

    def update
      if @form.cur_section_index == 3 && @form.section(3).cur_btn == @txt_name && KB.key_pressed?(Gosu::KbReturn)
        SB.new_game(@txt_name.text.downcase, @new_game_index) unless @txt_name.text.empty?
      end
      @form.update
    end

    def reset
      @form.reset
      @txt_name.text = ''
      add_game_slots
    end

    def update_lang
      @form.update_lang
    end

    def add_game_slots
      components = []
      @saved_games = []
      games = Dir["#{Res.prefix}save/*"].sort
      next_index = 0
      games.each do |g|
        file = g.split('/')[-1]
        next unless /^[0-9]$/ =~ file
        num = file.to_i
        (next_index...num).each do |i|
          components << NewGameButton.new(i + 1, 20 + (i % 2) * 390, 95 + (i / 2) * 90, self)
        end
        next_index = num + 1
        data = IO.readlines(g).map { |l| l.chomp }
        saved_game = SavedGame.new(num + 1, 20 + (num % 2) * 390, 95 + (num / 2) * 90, data[0], data[3], data[2], data[6], data[5])
        @saved_games << saved_game
        components << saved_game
        components <<
          SavedGameButton.new(20 + (num % 2) * 390, 95 + (num / 2) * 90) {
            @selected_game = g
            @form.go_to_section 2
          }
      end
      (next_index...10).each do |i|
        components << NewGameButton.new(i + 1, 20 + (i % 2) * 390, 95 + (i / 2) * 90, self)
      end
      components << MenuButton.new(550, :back, true) {
        @form.go_to_section 0
      }
      components << MenuText.new(:choose_game, 780, 25, 380, :right)
      section = @form.section(1)
      section.clear
      components.each { |c| section.add(c) }
    end

    def go_to_new_game(index)
      @new_game_index = index
      @form.go_to_section 3
    end

    def draw
      @bg.draw 0, 0, 0
      @title.draw 0, 0, 0, @form.cur_section_index == 1 ? 0.5 : 1, @form.cur_section_index == 1 ? 0.5 : 1
      @form.draw
    end
  end
end
