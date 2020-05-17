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

require_relative 'section'

class Stage
  attr_reader :num, :id, :starting, :cur_entrance, :switches, :star_count, :is_bonus, :time, :objective

  def initialize(world, num)
    @world = world
    @num = num
    @id = "#{world}-#{num}"
    @is_bonus = world == 'bonus'
    @world_name = @is_bonus ? "#{SB.text(:bonus)} #{@num}" : SB.text("world_#{@world}")
    @name = @is_bonus ? SB.text("bonus_#{@num}") : "#{@world}-#{@num}: #{SB.text("stage_#{@world}_#{@num}")}"
  end

  def start(loaded = false, time = nil, objective = nil)
    if time
      @time = time
      @counter = 0
      @objective = case objective
                   when 1 then :kill_all
                   when 2 then :get_all_rocks
                   else        :reach_goal
                   end
    end

    @star_count = 0
    @switches = []
    taken_switches = loaded ? SB.save_data[9].split(',').map(&:to_i) : []
    used_switches = loaded ? SB.save_data[10].split(',').map(&:to_i) : []

    @sections = []
    @entrances = []
    sections = Dir["#{Res.prefix}stage/#{@world}/#{@num}-*"]
    sections.sort.each do |s|
      @sections << Section.new(s, @entrances, @switches, taken_switches, used_switches)
    end

    SB.player.reset(loaded)
    @cur_entrance = @entrances[loaded ? SB.save_data[7].to_i : 0]
    @cur_section = @cur_entrance[:section]
    if SB.player.startup_item
      @switches << {
        type: Section::ELEMENT_TYPES[SB.player.startup_item],
        x: 0,
        y: 0,
        section: @cur_section,
        state: used_switches.size > 0 ? :used : :taken,
        index: @switches.length
      }
    end

    reset
  end

  def reset
    @panel_x = -600
    @timer = 0
    @alpha = 255
    @starting = true
    @star_count = 0
    reset_switches
    @cur_section.start @switches, @cur_entrance[:x], @cur_entrance[:y]
  end

  def update
    if @starting
      @timer = 240 if @timer < 240 && SB.key_pressed?(:confirm)
      if @timer < 240
        @alpha -= 5 if @alpha > 125
      else
        @alpha -= 5 if @alpha > 0
      end
      if @panel_x < 50
        speed = (50 - @panel_x) / 8.0
        speed = 1 if speed < 1
        @panel_x += speed
        @panel_x = 50 if (50 - @panel_x).abs < 1
      elsif @timer < 240
        @panel_x += 0.5
      else
        @panel_x += (@timer - 239)
      end
      @timer += 1
      if @timer == 300
        @starting = false
      end
    else
      return :finish if @time == 0
      status = @cur_section.update(@stopped)
      if status == :finish
        SB.play_sound(Res.sound(:victory), SB.music_volume * 0.1)
        Gosu::Song.current_song.stop
        SB.player.temp_startup_item = get_startup_item if @star_count >= C::STARS_PER_STAGE
        return :finish
      elsif status == :next_section
        index = @sections.index @cur_section
        @cur_section = @sections[index + 1]
        entrance = @entrances[@cur_section.default_entrance]
        @cur_section.start @switches, entrance[:x], entrance[:y]
      elsif SB.player.dead? && @is_bonus
        return :finish
      else
        check_reload
        check_entrance
        check_warp
      end
      if @time
        @counter += 1
        if @counter == 60
          @time -= 1
          @counter = 0
        end
      end
      if @stopped
        @stopped_timer += 1
        if @stopped_timer == @stop_time_duration
          @stopped = nil
        end
      end
    end
  end

  def check_reload
    if @cur_section.reload
      if SB.player.lives == 0
        SB.game_over
      else
        @sections.each do |s|
          s.loaded = false
        end
        SB.player.reset
        @cur_section = @cur_entrance[:section]
        reset
      end
    end
  end

  def check_entrance
    if @cur_section.entrance
      @cur_entrance = @entrances[@cur_section.entrance]
      @cur_section.entrance = nil
    end
  end

  def check_warp
    if @cur_section.warp
      entrance = @entrances[@cur_section.warp]
      @cur_section = entrance[:section]
      if @cur_section.loaded
        @cur_section.do_warp entrance[:x], entrance[:y]
      else
        @cur_section.start @switches, entrance[:x], entrance[:y]
      end
    end
  end

  def find_switch(obj)
    @switches.each do |s|
      return s if s[:obj] == obj
    end
    nil
  end

  def set_switch(obj)
    switch = self.find_switch obj
    switch[:state] = :temp_taken
  end

  def reset_switches
    @switches.each do |s|
      if s[:state] == :temp_taken || s[:state] == :temp_taken_used
        s[:state] = :normal
      elsif s[:state] == :temp_used || s[:state] == :taken_temp_used
        s[:state] = :taken
      end
      s[:obj] = s[:type].new(s[:x], s[:y], s[:args], s[:section], s)
    end
  end

  def save_switches
    @switches.each do |s|
      if s[:state] == :temp_taken
        s[:state] = :taken
      elsif s[:state] == :temp_used || s[:state] == :temp_taken_used || s[:state] == :taken_temp_used
        s[:state] = :used
      end
    end
  end

  def switches_by_state(state)
    @switches.select{ |s| s[:state] == state }.map{ |s| s[:index] }
  end

  def stop_time(duration = 1200, all = true)
    @stopped = all ? :all : :enemies
    @stopped_timer = 0
    @stop_time_duration = duration
  end

  def get_star
    @star_count += 1
  end

  def get_startup_item
    w = SB.player.last_world
    possible_items = [
      2,  # Attack1
      8,  # Board
      44, # Key
      65, # Shield
    ]
    possible_items += [
      3,  # Attack2
      71, # Spring
    ] if w >= 2
    possible_items[rand(possible_items.size)]
  end

  def draw
    @cur_section.draw
    if @starting
      c = (@alpha << 24)
      G.window.draw_quad 0, 0, c,
                         800, 0, c,
                         0, 600, c,
                         800, 600, c, 0
      G.window.draw_quad @panel_x, 200, C::PANEL_COLOR,
                         @panel_x + 600, 200, C::PANEL_COLOR,
                         @panel_x, 400, C::PANEL_COLOR,
                         @panel_x + 600, 400, C::PANEL_COLOR, 0
      SB.text_helper.write_line @world_name, @panel_x + 300, 220, :center
      SB.big_text_helper.write_line @name, @panel_x + 300, 300, :center
    end
  end
end
