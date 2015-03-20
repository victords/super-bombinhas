require_relative 'global'
require_relative 'form'

class StageMenu
  class << self
    def initialize
      @stage_menu_bg = Res.img :ui_stageMenu
      @stage_menu = Form.new([
        MenuButton.new(210, :resume) {
          SB.state = :main
        },
        MenuButton.new(280, :options) {
          @stage_menu.go_to_section 1
        },
        MenuButton.new(350, :save_exit) {
          SB.save_and_exit
        }
      ], [
        MenuButton.new(550, :back, true) {
          @stage_menu.go_to_section 0
        }
      ])
    end

    def update
      if SB.state == :paused
        if KB.key_pressed? Gosu::KbEscape
          SB.state = :main
          return
        end
        @stage_menu.update
      end
    end

    def reset
      @stage_menu.reset
    end

    def draw
      if SB.state == :main
        draw_player_stats
      elsif SB.state == :paused
        draw_menu
      end
    end

    def draw_player_stats
      G.window.draw_quad 5, 5, 0x80abcdef,
                         205, 5, 0x80abcdef,
                         205, 55, 0x80abcdef,
                         5, 55, 0x80abcdef, 0
      SB.font.draw SB.text(:lives), 10, 10, 0, 1, 1, 0xff000000
      SB.font.draw SB.player.lives, 100, 10, 0, 1, 1, 0xff000000
      SB.font.draw SB.text(:score), 10, 30, 0, 1, 1, 0xff000000
      SB.font.draw SB.player.score, 100, 30, 0, 1, 1, 0xff000000

      G.window.draw_quad 690, 5, 0x80abcdef,
                         740, 5, 0x80abcdef,
                         740, 55, 0x80abcdef,
                         690, 55, 0x80abcdef, 0
      G.window.draw_quad 745, 5, 0x80abcdef,
                         795, 5, 0x80abcdef,
                         795, 55, 0x80abcdef,
                         745, 55, 0x80abcdef, 0

      if SB.player.cur_item_type
        item_set = SB.player.items[SB.player.cur_item_type]
        item_set[0][:obj].icon.draw 695, 10, 0
        SB.font.draw item_set.length.to_s, 725, 36, 0, 1, 1, 0xff000000
      end
      if SB.player.items.length > 1
        G.window.draw_triangle 690, 30, 0x80123456,
                               694, 26, 0x80123456,
                               694, 34, 0x80123456, 0
        G.window.draw_triangle 736, 25, 0x80123456,
                               741, 30, 0x80123456,
                               736, 35, 0x80123456, 0
      end
    end

    def draw_menu
      G.window.draw_quad 0, 0, 0x80000000,
                         800, 0, 0x80000000,
                         0, 600, 0x80000000,
                         800, 600, 0x80000000, 0
      @stage_menu_bg.draw 275, 180, 0 if @stage_menu.cur_section_index != 1
      @stage_menu.draw
    end
  end
end