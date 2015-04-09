require_relative 'global'
require_relative 'options'

class MenuImage < MenuElement
  def initialize(x, y, img)
    @x = x
    @y = y
    @img = Res.img img
  end

  def draw
    @img.draw @x, @y, 0
  end
end

class MenuPanel < MenuElement
  def initialize(x, y, w, h)
    @x = x
    @y = y
    @w = w
    @h = h
  end

  def draw
    G.window.draw_quad @x, @y, C::PANEL_COLOR,
                       @x + @w, @y, C::PANEL_COLOR,
                       @x, @y + @h, C::PANEL_COLOR,
                       @x + @w, @y + @h, C::PANEL_COLOR, 0
  end
end

class BombButton < Button
  include FormElement

  def initialize(x, bomb)
    super(x: x, y: 240, width: 80, height: 80, params: bomb) { |b|
      SB.player.set_bomb(b)
      SB.state = :main
    }
    @bomb = SB.player.bomb(bomb)
    @bomb_img = Res.img "icon_Bomba#{bomb.capitalize}"
  end

  def draw
    G.window.draw_quad @x, @y, C::PANEL_COLOR,
                       @x + @w, @y, C::PANEL_COLOR,
                       @x, @y + @h, C::PANEL_COLOR,
                       @x + @w, @y + @h, C::PANEL_COLOR, 0
    @bomb_img.draw @x + 40 - @bomb_img.width / 2, @y + 30 - @bomb_img.height / 2, 0
    SB.small_text_helper.write_breaking @bomb.name, @x + 40, @y + 52, 64, :center
  end
end

class StageMenu
  class << self
    attr_reader :ready

    def initialize
      if @ready
        @stage_menu.reset
        set_bomb_screen_comps
      else
        @options = Options.new
        options_comps = [MenuPanel.new(10, 90, 780, 450)]
        options_comps.concat(@options.get_menu)

        @stage_menu = Form.new([
          MenuImage.new(275, 180, :ui_stageMenu),
          MenuButton.new(200, :resume, true) {
            SB.state = :main
          },
          MenuButton.new(250, :change_bomb) {
            @stage_menu.go_to_section 1
          },
          MenuButton.new(300, :options) {
            @options.set_temp
            @stage_menu.go_to_section 2
          },
          MenuButton.new(350, :save_exit) {
            SB.save_and_exit
          }
        ], [], options_comps, [
          MenuButton.new(350, :continue, false, 219) {
            SB.next_stage
          },
          MenuButton.new(350, :save_exit, false, 409) {
            SB.next_stage false
          }
        ])
        @options.form = @stage_menu
        set_bomb_screen_comps
        @ready = true
      end
    end

    def set_bomb_screen_comps
      sec = @stage_menu.section(1)
      sec.clear
      sec.add(MenuButton.new(550, :back, true) {
                @stage_menu.go_to_section 0
              })
      case SB.player.last_world
      when 1 then sec.add(BombButton.new(360, :azul))
      when 2 then sec.add(BombButton.new(310, :azul))
                  sec.add(BombButton.new(410, :vermelha))
      when 3 then sec.add(BombButton.new(260, :azul))
                  sec.add(BombButton.new(360, :vermelha))
                  sec.add(BombButton.new(460, :amarela))
      when 4 then sec.add(BombButton.new(210, :azul))
                  sec.add(BombButton.new(310, :vermelha))
                  sec.add(BombButton.new(410, :amarela))
                  sec.add(BombButton.new(510, :verde))
      else        sec.add(BombButton.new(160, :azul))
                  sec.add(BombButton.new(260, :vermelha))
                  sec.add(BombButton.new(360, :amarela))
                  sec.add(BombButton.new(460, :verde))
                  sec.add(BombButton.new(560, :branca))
      end
    end

    def update
      if SB.state == :paused
        @stage_menu.update
      elsif SB.state == :stage_end
        @stage_end_timer += 1 if @stage_end_timer < 30 * @stage_end_comps.length
        @stage_menu.update
        @stage_end_comps.each_with_index do |c, i|
          c.update_movement if @stage_end_timer >= i * 30
        end
      end
    end

    def end_stage
      p = MenuPanel.new(-600, 150, 400, 300)
      p.init_movement
      p.move_to 200, 150
      t1 = MenuText.new(:stage_complete, 1200, 160, 400, :center, true)
      t1.init_movement
      t1.move_to 400, 160
      t2 = MenuText.new(:score, 210, 820)
      t2.init_movement
      t2.move_to 210, 220
      t3 = MenuNumber.new(SB.player.stage_score, 590, 820, :right)
      t3.init_movement
      t3.move_to 590, 220
      t4 = MenuText.new(:total, 210, 860)
      t4.init_movement
      t4.move_to 210, 260
      t5 = MenuNumber.new(SB.player.score, 590, 860, :right)
      t5.init_movement
      t5.move_to 590, 260
      t6 = MenuText.new(:spec_taken, 210, 900)
      t6.init_movement
      t6.move_to 210, 300
      t7 = MenuText.new(SB.player.specs.index(SB.stage.id) ? :yes : :no, 590, 900, 300, :right)
      t7.init_movement
      t7.move_to 590, 300
      @stage_end_comps = [p, t1, t2, t3, t4, t5, t6, t7]
      @stage_end_timer = 0
      @stage_menu.go_to_section 2
    end

    def update_lang
      @stage_menu.update_lang
    end

    def draw
      if SB.state == :main
        draw_player_stats
      elsif SB.state == :paused
        draw_menu
      else # :stage_end
        draw_stage_stats
      end
    end

    def draw_player_stats
      G.window.draw_quad 5, 5, C::PANEL_COLOR,
                         205, 5, C::PANEL_COLOR,
                         205, 55, C::PANEL_COLOR,
                         5, 55, C::PANEL_COLOR, 0
      SB.font.draw SB.text(:lives), 10, 10, 0, 1, 1, 0xff000000
      SB.font.draw SB.player.lives, 100, 10, 0, 1, 1, 0xff000000
      SB.font.draw SB.text(:score), 10, 30, 0, 1, 1, 0xff000000
      SB.font.draw SB.player.stage_score, 100, 30, 0, 1, 1, 0xff000000
      SB.font.draw SB.player.bomb.hp, 200, 10, 0, 1, 1, 0xff000000

      G.window.draw_quad 690, 5, C::PANEL_COLOR,
                         740, 5, C::PANEL_COLOR,
                         740, 55, C::PANEL_COLOR,
                         690, 55, C::PANEL_COLOR, 0
      G.window.draw_quad 745, 5, C::PANEL_COLOR,
                         795, 5, C::PANEL_COLOR,
                         795, 55, C::PANEL_COLOR,
                         745, 55, C::PANEL_COLOR, 0

      if SB.player.cur_item_type
        item_set = SB.player.items[SB.player.cur_item_type]
        item_set[0][:obj].icon.draw 695, 10, 0
        SB.font.draw item_set.length.to_s, 725, 36, 0, 1, 1, 0xff000000
      end
      if SB.player.items.length > 1
        G.window.draw_triangle 690, 30, C::ARROW_COLOR,
                               694, 26, C::ARROW_COLOR,
                               694, 34, C::ARROW_COLOR, 0
        G.window.draw_triangle 736, 25, C::ARROW_COLOR,
                               741, 30, C::ARROW_COLOR,
                               736, 35, C::ARROW_COLOR, 0
      end
    end

    def draw_menu
      G.window.draw_quad 0, 0, 0x80000000,
                         800, 0, 0x80000000,
                         0, 600, 0x80000000,
                         800, 600, 0x80000000, 0
      @stage_menu.draw
    end

    def draw_stage_stats
      @stage_end_comps.each { |c| c.draw }
      @stage_menu.draw if @stage_end_timer >= @stage_end_comps.length * 30
    end
  end
end