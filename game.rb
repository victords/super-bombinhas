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

gem 'minigl', '2.3.7'

require 'rbconfig'
require 'gosu'
require_relative 'menu'
require_relative 'stage_menu'
require_relative 'movie'
require_relative 'credits'
require_relative 'editor'

class SBGame < MiniGL::GameWindow
  def initialize
    os = RbConfig::CONFIG['host_os']
    dir =
      if /linux/ =~ os
        "#{Dir.home}/.vds-games/super-bombinhas"
      else
        "#{Dir.home}/AppData/Local/VDS Games/Super Bombinhas"
      end
    SB.load_options(dir)

    super(C::SCREEN_WIDTH, C::SCREEN_HEIGHT, SB.full_screen, Vector.new(0, 0.7))
    self.caption = 'Super Bombinhas'
    G.ramp_slip_threshold = 0.8
    G.ramp_slip_force = 0.8
	  SB.initialize

    @logo = Res.img(:ui_minigl)
    @timer = @state = @alpha = 0
  end

  def needs_cursor?
    SB.state == :menu || SB.state == :paused || SB.state == :stage_end || SB.state == :editor
  end

  def update
    KB.update
    Mouse.update

    SB.toggle_full_screen if KB.key_pressed?(Gosu::KB_F4)
    SB.full_screen_toggled if KB.key_down?(Gosu::KB_LEFT_ALT) && KB.key_pressed?(Gosu::KB_RETURN)

    if SB.state == :presentation
      if SB.key_pressed?(:confirm) || Mouse.button_down?(:left)
        SB.state = :menu
        SB.play_song Res.song(:main)
        return
      end
      @timer += 1
      if @state == 0 || @state == 2
        @alpha += 5 if @alpha < 255
        if @timer == 240
          @state += 1
        end
      elsif @state == 1 || @state == 3
        @alpha -= 5
        if @alpha == 0
          @state += 1
          @timer = 0
          if @state == 4
            SB.play_song Res.song(:main)
            @alpha = 255
          end
        end
      else
        @alpha -= 17 if @alpha > 0
        @alpha = 0 if @alpha < 0
        if @timer == 15
          if @state == 5; SB.state = :menu
          else; @state += 1; @alpha = 255; end
          @timer = 0
        end
      end
    elsif SB.state == :menu
      Menu.update
    elsif SB.state == :map
      SB.world.update
    elsif SB.state == :main
      status = SB.stage.update
      SB.end_stage if status == :finish
      StageMenu.update_main
    elsif SB.state == :stage_end
      StageMenu.update_end
    elsif SB.state == :paused
      SB.check_song
      StageMenu.update_paused
    elsif SB.state == :movie
      SB.movie.update
    elsif SB.state == :game_end
      Credits.update
    elsif SB.state == :game_end_2
      if SB.key_pressed?(:confirm)
        Menu.reset
        SB.state = :menu
      end
    elsif SB.state == :editor
      SB.editor.update
    end
  end

  def draw
    if SB.state == :presentation
      if @state <= 1
        @logo.draw((C::SCREEN_WIDTH - @logo.width) / 2, (C::SCREEN_HEIGHT - @logo.height) / 2, 0, 1, 1, (@alpha << 24) | 0xffffff)
        SB.text_helper.write_line(SB.text(:powered_by), 400, (C::SCREEN_HEIGHT - @logo.height) / 2 - 50, :center, 0xffffff, @alpha)
      elsif @state <= 3
        SB.text_helper.write_line(SB.text(:game_by), 400, C::SCREEN_HEIGHT / 2 - 70, :center, 0xffffff, @alpha)
        SB.text_helper.write_line("Victor David Santos", 400, C::SCREEN_HEIGHT / 2 - 20, :center, 0xffffff, @alpha, nil, 0, 0, 0, 0, 3, 3)
      else
        Menu.draw
        (0..3).each do |i|
          (0..3).each do |j|
            s = (i + j) % 3
            c = @state < s + 4 ? 0xff000000 : @state == s + 4 ? @alpha << 24 : 0
            G.window.draw_quad i * 200, j * 150, c,
                               i * 200 + 200, j * 150, c,
                               i * 200, j * 150 + 150, c,
                               i * 200 + 200, j * 150 + 150, c, 0
          end
        end
      end
    elsif SB.state == :menu
      Menu.draw
    elsif SB.state == :map
      SB.world.draw
    elsif SB.state == :main || SB.state == :paused || SB.state == :stage_end
      SB.stage.draw
      StageMenu.draw
    elsif SB.state == :movie
      SB.movie.draw
    elsif SB.state == :game_end
      Credits.draw
    elsif SB.state == :game_end_2
      clear 0
      SB.text_helper.write_line(text: SB.text(:game_end), x: 400, y: 280, mode: :center, color: 0xffffff, scale_x: 3, scale_y: 3)
      SB.text_helper.write_line(text: SB.text("#{SB.state}_sub"), x: 400, y: 320, mode: :center, color: 0xffffff, alpha: 127, scale_x: 1.5, scale_y: 1.5)
    elsif SB.state == :editor
      SB.editor.draw
    end
  end
end

class MiniGL::GameObject
  def is_visible(map)
    return map.cam.intersect? @active_bounds if @active_bounds
    false
  end

  def dead?
    @dead
  end

  def position
    Vector.new(@x, @y)
  end

  def stop_time_immune?
    false
  end
end

SBGame.new.show
SB.save_options
SB.clear_temp_files
