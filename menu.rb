require 'minigl'
require_relative 'world'
require_relative 'player'
include MiniGL

class MenuButton < Button
  def initialize(y, text_id, x = 306, &action)
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

class Menu
  def initialize
    @bg = Res.img :bg_start1, true, false, '.jpg'
    @title = Res.img :ui_title, true

    @btns = [[
      MenuButton.new(295, :play) {
        set_button_group 1
      },
      MenuButton.new(345, :options) {
        set_button_group 2
      },
      MenuButton.new(395, :credits) {
        set_button_group 3
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
        puts 'continue'
      },
      MenuButton.new(420, :back) {
        set_button_group 0
      }
    ], [
      MenuButton.new(550, :save, 207) {
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
    @highlight = Sprite.new(0, 0, :ui_highlight1, 1, 3)

    set_button_group 0
  end

  def set_button_group(group)
    @cur_btn_group = group
    @cur_btn = 0
    set_highlight_position
  end

  def set_highlight_position
    @highlight.x = @btns[@cur_btn_group][@cur_btn].instance_eval('@x') + 3
    @highlight.y = @btns[@cur_btn_group][@cur_btn].instance_eval('@y') - 5
  end

  def update
    mouse_moved = (Mouse.x != @mouse_prev_x or Mouse.y != @mouse_prev_y)

    @btns[@cur_btn_group].each_with_index do |b, i|
      b.update
      state = b.instance_eval('@state')
      if state == :down or (mouse_moved and state == :over)
        @cur_btn = i
        set_highlight_position
      end
    end
    @highlight.animate([0, 1, 2, 1], 12)

    if KB.key_pressed? Gosu::KbDown
      @cur_btn += 1
      @cur_btn = 0 if @cur_btn == @btns[@cur_btn_group].length
      set_highlight_position
    elsif KB.key_pressed? Gosu::KbUp
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
    @title.draw 0, 0, 0
    @btns[@cur_btn_group].each do |b|
      b.draw
    end
    @texts[@cur_btn_group].each do |t|
      t.draw
    end
    @highlight.draw
  end
end
