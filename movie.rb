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

class Movie
  def initialize(id)
    @id = id
    files = Dir["#{Res.prefix}img/movie/#{id}-*"].sort
    @scenes = []
    files.each do |f|
      @scenes << Res.img("movie_#{f.split('/')[-1].chomp('.png')}")
    end
    @scene = @timer = 0
    @alpha = 255
    @changing = 1
    @time_limit = id == 0 ? 890 : 1595
    SB.play_song(Res.song(id == 0 ? :movieSad : :movie))
  end

  def update
    if @changing
      @alpha += @changing == 0 ? 5 : -5
      if @alpha == 255
        @changing = 1
        @timer = 0
        @scene += 1
        @texts = nil
        finish if @scene == @scenes.length
      elsif @alpha == 0
        @texts = SB.text("movie_#{@id}_#{@scene}").split('/')
        @changing = nil
      end
    else
      @timer += 1
      @changing = 0 if SB.key_pressed?(:confirm) || @timer == @time_limit
    end
  end

  def finish
    if @id == 0
      SB.start_new_game
    else
      SB.next_world
    end
  end

  def draw
    @scenes[@scene].draw(80, 20, 0, 2, 2)
    @texts.each_with_index do |text, i|
      next if @timer <= i * 60
      alpha = ((@timer - i * 60).to_f / 60 * 255).round
      alpha = 255 if alpha > 255
      y = 280 + i * 100
      y += 26 if @id == 2 && @scene == 0 && i == 1 && SB.lang == :indonesian
      y -= 26 if @id == 3 && @scene == 0 && i == 1 && SB.lang == :indonesian
      y -= 26 if @id == 5 && @scene == 1 && i == 1 && SB.lang == :indonesian
      SB.text_helper.write_breaking(text, 80, y, 640, :justified, 0xffffff, alpha)
    end if @texts
    if @changing
      c = @alpha << 24
      G.window.draw_quad 0, 0, c,
                         C::SCREEN_WIDTH, 0, c,
                         0, C::SCREEN_HEIGHT, c,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, c, 0
    end
  end
end
