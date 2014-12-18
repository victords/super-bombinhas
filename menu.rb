require 'minigl'
require_relative 'world'
require_relative 'player'
include AGL

class Menu
  def initialize
    @bg = Res.img :bg_start1, true, false, '.jpg'
    @title = Res.img :ui_title, true

    @btns = [
      Button.new(306, 320, G.font, 'Play', :ui_button1, 0, 0x808080, true, false, 0, 7) {
        G.world = World.new
        G.player = Player.new
        G.state = :map
      },
      Button.new(306, 370, G.font, 'Options', :ui_button1, 0, 0x808080, true, false, 0, 7) {
        puts 'options'
      },
      Button.new(306, 420, G.font, 'Exit', :ui_button1, 0, 0x808080, true, false, 0, 7) {
        exit
      }
    ]
    # @btn.enabled = false
    @highlight = Sprite.new(0, 0, :ui_highlight1, 1, 3)
    @cur_btn = 0
    set_highlight_position
  end

  def set_highlight_position
    @highlight.x = @btns[@cur_btn].instance_eval('@x') + 3
    @highlight.y = @btns[@cur_btn].instance_eval('@y') - 5
  end

  def update
    mouse_moved = (Mouse.x != @mouse_prev_x or Mouse.y != @mouse_prev_y)

    @btns.each_with_index do |b, i|
      b.update
      state = b.instance_eval('@state')
      if mouse_moved and (state == :over or state == :down)
        @cur_btn = i
        set_highlight_position
      end
    end
    @highlight.animate([0, 1, 2, 1], 12)

    if KB.key_pressed? Gosu::KbDown
      @cur_btn += 1
      @cur_btn = 0 if @cur_btn == @btns.length
      set_highlight_position
    elsif KB.key_pressed? Gosu::KbUp
      @cur_btn -= 1
      @cur_btn = @btns.length - 1 if @cur_btn < 0
      set_highlight_position
    elsif KB.key_pressed?(Gosu::KbReturn) or KB.key_pressed?(Gosu::KbSpace)
      @btns[@cur_btn].click
    end

    @mouse_prev_x = Mouse.x
    @mouse_prev_y = Mouse.y
  end

  def draw
    @bg.draw 0, 0, 0
    @title.draw 0, 0, 0
    @btns.each do |b|
      b.draw
    end
    @highlight.draw
  end
end
