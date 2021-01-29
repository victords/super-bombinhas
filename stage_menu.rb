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

require_relative 'global'
require_relative 'options'

class MenuImage < MenuElement
  def initialize(x, y, img)
    @x = x
    @y = y
    @img = Res.img img
  end

  def draw
    @img.draw @x, @y, 0, 2, 2
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

  def initialize(x, bomb, form)
    super(x: x, y: 240, width: 80, height: 80) {
      SB.player.set_bomb(bomb)
      SB.state = :main
      form.reset
    }
    @bomb = SB.player.bomb(bomb)
    @bomb_img = Res.img "icon_Bomba#{bomb.capitalize}"
  end

  def draw
    G.window.draw_quad @x, @y, C::PANEL_COLOR,
                       @x + @w, @y, C::PANEL_COLOR,
                       @x, @y + @h, C::PANEL_COLOR,
                       @x + @w, @y + @h, C::PANEL_COLOR, 0
    @bomb_img.draw @x + 40 - @bomb_img.width, @y + 25 - @bomb_img.height, 0, 2, 2
    SB.text_helper.write_breaking(@bomb.name, @x + 40, @y + 48, 64, :center, 0, 255, 0, 1.5, 1.5, -3)
  end
end

class ItemEffect
  attr_reader :dead

  def initialize(x, y, target_x, target_y)
    @x = x; @y = y; @target_x = target_x; @target_y = target_y
    @d_x = target_x - x; @d_y = target_y - y
    @time = 0
    @effects = []
  end

  def update
    if @time >= 30
      unless @finished
        @effects << Effect.new(@target_x - 16, @target_y - 16, :fx_glow2, 3, 2)
        @finished = true
      end
    else
      pos_x = @x + (@time / 30.0) * @d_x
      pos_y = @y + (@time / 30.0) * @d_y
      @effects << Effect.new(pos_x - 7, pos_y - 7, :fx_Glow1, 3, 2,7, [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0])

      @time += 1
    end

    @effects.each do |e|
      e.update
      @effects.delete(e) if e.dead
    end

    @dead = true if @finished && @effects.empty?
  end

  def draw(map, scale_x, scale_y)
    @effects.each do |e|
      e.draw(map, scale_x, scale_y)
    end
  end
end

class StageMenu
  class << self
    attr_reader :ready

    def initialize
      if @ready
        @stage_menu.reset
        set_bomb_screen_comps
        @alpha = 0
      else
        options_comps = [MenuPanel.new(10, 90, 780, 450)]
        options_comps.concat(Options.get_menu)

        @stage_menu = Form.new([
          MenuImage.new(280, 180, :ui_stageMenu),
          MenuButton.new(207, :resume, true) {
            SB.state = :main
          },
          MenuButton.new(257, :change_bomb) {
            @stage_menu.go_to_section 1
          },
          MenuButton.new(307, :options) {
            Options.set_temp
            @stage_menu.go_to_section 2
          },
          MenuButton.new(357, :exit) {
            SB.save_and_exit
            @stage_menu.reset
          }
        ], [], options_comps, [
          MenuButton.new(400, :continue, false, 219) {
            SB.next_stage
          },
          MenuButton.new(400, :exit, false, 409) {
            SB.next_stage false
          }
        ])
        set_bomb_screen_comps
        @alpha = 0
        @ready = true
        @lives_icon = Res.img :icon_lives
        @hp_icon = Res.img :icon_hp
        @score_icon = Res.img :icon_score
        @star_icon = Res.img :icon_star
        @selected_item = Res.img :ui_startupItem
      end
      Options.form = @stage_menu

      @effects = []
    end

    def set_bomb_screen_comps
      sec = @stage_menu.section(1)
      sec.clear
      p = SB.player
      start_x = 400 - (40 + (p.bomb_count - 1) * 50)
      sec.add(BombButton.new(start_x, :azul, @stage_menu))
      sec.add(BombButton.new(start_x + 100, :vermelha, @stage_menu)) if p.bomb_unlocked?(:vermelha)
      sec.add(BombButton.new(start_x + 200, :amarela, @stage_menu))  if p.bomb_unlocked?(:amarela)
      sec.add(BombButton.new(start_x + 300, :verde, @stage_menu))    if p.bomb_unlocked?(:verde)
      sec.add(BombButton.new(start_x + 400, :branca, @stage_menu))   if p.bomb_unlocked?(:branca)
      sec.add(MenuButton.new(550, :back, true) {
        @stage_menu.go_to_section 0
      })
    end

    def update_main
      @effects.each do |e|
        e.update
        @effects.delete(e) if e.dead
      end
      if SB.player.dead?
        @dead_text = SB.player.lives == 0 ? :game_over : :dead if @dead_text.nil?
        @alpha += 17 if @alpha < 255
      elsif @dead_text
        @dead_text = nil
        @alpha = 0
      end
    end

    def update_end
      if @stage_end_timer < 30 * @stage_end_comps.length
        if SB.key_pressed?(:confirm)
          @stage_end_timer = 30 * @stage_end_comps.length
        else
          @stage_end_timer += 1
        end
      end
      @stage_menu.update if @stage_end_timer >= 30 * @stage_end_comps.length
      @stage_end_comps.each_with_index do |c, i|
        c.update_movement if @stage_end_timer >= i * 30
      end
    end

    def update_paused
      if SB.key_pressed?(:pause)
        SB.state = :main
        @stage_menu.reset
        return
      end
      @stage_menu.update
    end

    def end_stage(unlock_bomb, next_bonus, next_movie, bonus = false)
      p = MenuPanel.new(-600, 150, 400, unlock_bomb ? 350 : 300)
      p.init_movement
      p.move_to 200, 150
      t1 = MenuText.new(SB.player.dead? || SB.stage.time == 0 ? :too_bad : :stage_complete, 1200, 160, 400, :center, true)
      t1.init_movement
      t1.move_to 400, 160
      t2 = MenuText.new(:score, 210, 820)
      t2.init_movement
      t2.move_to 210, 220
      t3 = MenuNumber.new(SB.player.stage_score, 590, 820, :right)
      t3.init_movement
      t3.move_to 590, 220
      @stage_end_comps = [p, t1, t2, t3]

      if bonus
        if SB.stage.won_reward
          t4 = MenuImage.new(372, 905, :icon_lives)
          t4.move_to 372, 305
          t4.init_movement
          t5 = MenuText.new("x #{SB.stage.reward}", 413, 905, 400, :center)
          t5.init_movement
          t5.move_to 413, 305
          @stage_end_comps << t4 << t5
        end
      else
        t4 = MenuText.new(:total, 210, 860)
        t4.init_movement
        t4.move_to 210, 260
        t5 = MenuNumber.new(SB.player.score, 590, 860, :right, next_bonus ? 0xff0000 : 0)
        t5.init_movement
        t5.move_to 590, 260
        t6 = MenuText.new(:stars, 210, 900)
        t6.init_movement
        t6.move_to 210, 300
        t7 = MenuText.new("#{SB.stage.star_count}/#{C::STARS_PER_STAGE}", 590, 900, 300, :right)
        t7.init_movement
        t7.move_to(590, 300)
        @stage_end_comps << t4 << t5 << t6 << t7
        unless SB.world.num == C::LAST_WORLD
          t8 = MenuText.new(:spec_taken, 210, 940)
          t8.init_movement
          t8.move_to 210, 340
          t9 = MenuText.new(SB.player.specs.index(SB.stage.id) ? :yes : :no, 590, 940, 300, :right)
          t9.init_movement
          t9.move_to 590, 340
          @stage_end_comps << t8 << t9
        end

        if SB.stage.star_count >= C::STARS_PER_STAGE
          t10 = MenuText.new(:all_stars_found, 590, 968, 300, :right)
          t10.init_movement
          t10.move_to(590, 368)
          @stage_end_comps << t10
        end
      end

      @stage_end_timer = 0
      if unlock_bomb or next_bonus or next_movie
        @stage_menu.section(3).clear
        @stage_menu.section(3).add(MenuButton.new(unlock_bomb ? 440 : 400, :continue) {
          SB.check_next_stage
        })
        if unlock_bomb
          @stage_menu.section(3).add(MenuText.new(:can_play, 210, 400))
          @stage_menu.section(3).add(MenuImage.new(558, 394, get_next_bomb_icon))
        end
        @continue_only = true
      elsif @continue_only
        @stage_menu.section(3).clear
        @stage_menu.section(3).add(MenuButton.new(400, :continue, false, 219) {
          SB.check_next_stage
        })
        @stage_menu.section(3).add(MenuButton.new(400, :exit, false, 409) {
          SB.check_next_stage false
        })
        @continue_only = false
      end
      @stage_menu.go_to_section 3
    end

    def get_next_bomb_icon
      case SB.player.last_world
      when 1 then :icon_BombaVermelha
      when 2 then :icon_BombaAmarela
      when 3 then :icon_BombaVerde
      else        :icon_BombaBranca
      end
    end

    def update_lang
      @stage_menu.update_lang if StageMenu.ready
    end

    def play_get_item_effect(origin_x, origin_y, type = nil)
      @effects << ItemEffect.new(origin_x, origin_y,
                                 type == :life ? 20 : type == :star ? 372 : type == :health ? 114 : 770,
                                 type.nil? ? 30 : 19)
    end

    def draw
      if SB.state == :main
        st = SB.stage
        unless st.starting > 0
          draw_player_stats
          unless st.is_bonus
            @star_icon.draw(363, 10, 0, 2, 2)
            SB.text_helper.write_line("#{st.star_count}/#{C::STARS_PER_STAGE}", 411, 8, :center, 0xffffff, 255, :border)
          end
          SB.text_helper.write_line(st.time.to_s, 400, 570, :center, 0xffffff, 255, :border) if st.time
        end
        @effects.each do |e|
          e.draw(nil, 2, 2)
        end
        draw_player_dead if SB.player.dead?
      elsif SB.state == :paused
        draw_menu
      else # :stage_end
        draw_stage_stats
      end
    end

    def draw_player_stats
      p = SB.player
      G.window.draw_quad 4, 4, C::PANEL_COLOR,
                         204, 4, C::PANEL_COLOR,
                         204, 60, C::PANEL_COLOR,
                         4, 60, C::PANEL_COLOR, 0
      @lives_icon.draw 12, 9, 0, 2, 2
      SB.font.draw_text p.lives + SB.stage.life_count, 40, 8, 0, 2, 2, 0xff000000
      @hp_icon.draw 105, 9, 0, 2, 2
      SB.font.draw_text p.bomb.hp, 135, 8, 0, 2, 2, 0xff000000
      @score_icon.draw 10, 32, 0, 2, 2
      SB.font.draw_text p.stage_score, 40, 30, 0, 2, 2, 0xff000000

      ########## ITEM ##########
      if p.items.size > 0
        p.items.each_with_index do |(k, v), i|
          x = 754 - 40 * (p.items.size - i - 1)
          @selected_item.draw(x - 8, 6, 0, 2, 2) if k == p.cur_item_type
          v[0][:obj].icon.draw(x, 14, 0, 2, 2, k == p.cur_item_type ? 0xffffffff : C::DISABLED_COLOR)
          SB.text_helper.write_line(v.length.to_s, x + 36, 28, :right, 0xffffff, k == p.cur_item_type ? 255 : 127, :border)
        end
      end
      ##########################

      ######### ABILITY ########
      b = p.bomb
      icon = if b.type == :verde
               'explode'
             elsif b.type == :branca
               'time'
             else
               nil
             end
      if icon
        color = b.can_use_ability ? 0xffffffff : C::DISABLED_COLOR
        G.window.draw_quad 750, 66, color,
                           790, 66, color,
                           790, 106, color,
                           750, 106, color, 0
        @selected_item.draw(746, 62, 0, 2, 2)
        Res.img("icon_#{icon}").draw(754, 70, 0, 2, 2, color)

        SB.text_helper.write_line((b.cooldown.to_f / 60).ceil.to_s, 790, 84, :right, 0xffffff, 255, :border) unless b.can_use_ability
      end
      ##########################
    end

    def draw_player_dead
      c = ((@alpha / 2) << 24)
      G.window.draw_quad 0, 0, c,
                         C::SCREEN_WIDTH, 0, c,
                         0, C::SCREEN_HEIGHT, c,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, c, 0
      SB.text_helper.write_line(SB.text(@dead_text), 400, 250, :center, 0xffffff, @alpha, :border, 0, 1, 255, 1, 3, 3)
      unless SB.stage.is_bonus
        SB.text_helper.write_line SB.text(:restart), 400, 300, :center, 0xffffff, @alpha, :border, 0, 1, 255, 1
      end
    end

    def draw_menu
      G.window.draw_quad 0, 0, 0x80000000,
                         C::SCREEN_WIDTH, 0, 0x80000000,
                         0, C::SCREEN_HEIGHT, 0x80000000,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, 0x80000000, 0
      @stage_menu.draw
    end

    def draw_stage_stats
      @stage_end_comps.each { |c| c.draw }
      @stage_menu.draw if @stage_end_timer >= @stage_end_comps.length * 30
    end
  end
end
