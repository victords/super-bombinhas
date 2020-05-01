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

require_relative 'form'

class Options
  class << self
    def form=(form)
      @form = form
    end

    def set_temp
      @lang = SB.lang
      @sound_volume = SB.sound_volume
      @music_volume = SB.music_volume
    end

    def get_menu
      @menu = [
        MenuText.new(:language, 20, 200),
        MenuText.new(:lang_name, 590, 200, 320, :center),
        MenuArrowButton.new(400, 192, 'Left') {
          SB.change_lang(-1)
        },
        MenuArrowButton.new(744, 192, 'Right') {
          SB.change_lang
        },
        MenuText.new(:sound_volume, 20, 270),
        (@s_v_text = MenuNumber.new(SB.sound_volume, 590, 270, :center)),
        MenuArrowButton.new(400, 262, 'Left') {
          SB.change_volume('sound', -1)
          @s_v_text.num = SB.sound_volume
        },
        MenuArrowButton.new(744, 262, 'Right') {
          SB.change_volume('sound')
          @s_v_text.num = SB.sound_volume
        },
        MenuText.new(:music_volume, 20, 340),
        (@m_v_text = MenuNumber.new(SB.music_volume, 590, 340, :center)),
        MenuArrowButton.new(400, 332, 'Left') {
          SB.change_volume('music', -1)
          @m_v_text.num = SB.music_volume
        },
        MenuArrowButton.new(744, 332, 'Right') {
          SB.change_volume('music')
          @m_v_text.num = SB.music_volume
        },
        MenuText.new(:full_screen, C::SCREEN_WIDTH / 2, 410, C::SCREEN_WIDTH, :center),
        MenuButton.new(550, :save, false, 219) {
          SB.save_options
          @form.go_to_section 0
        },
        MenuButton.new(550, :cancel, true, 409) {
          SB.lang = @lang
          SB.sound_volume = @s_v_text.num = @sound_volume
          SB.music_volume = @m_v_text.num = @music_volume
          @form.go_to_section 0
        }
      ] if @menu.nil?
      @menu
    end
  end
end
