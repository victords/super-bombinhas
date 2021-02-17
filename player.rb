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

require_relative 'bomb'

class Player
  BOMB_TYPES = [:azul, :vermelha, :amarela, :verde, :branca]

  attr_reader :score, :stage_score, :items, :cur_item_type, :specs, :all_stars
  attr_accessor :name, :last_world, :last_stage, :lives, :startup_item, :temp_startup_item

  def initialize(name, last_world = 1, last_stage = 1, bomb = :azul, hps = nil, lives = 5, score = 0, specs = '', startup_item = nil, all_stars = '')
    @name = name
    @last_world = last_world
    @last_stage = last_stage
    @bombs = {}
    hps =
      if hps
        hps.split(',').map{ |s| s.to_i }
      else
        [2, 3, 2, 2, 2]
      end
    BOMB_TYPES.each_with_index do |b, i|
      @bombs[b] = Bomb.new(b, hps[i]) if bomb_unlocked?(b)
    end
    @bomb = @bombs[bomb]
    @lives = lives
    @score = score
    @stage_score = 0
    @specs = specs.split(',')
    @all_stars = all_stars.split(',')
    @items = {}
    @startup_item = startup_item
  end

  def bomb_unlocked?(type)
    case type
    when :vermelha then @last_world > 1
    when :amarela  then @last_world > 2
    when :verde    then @last_world > 3
    when :branca   then @last_world > 6 || @last_world > 5 && @last_stage > 1
    else                true
    end
  end

  def dead?
    @dead
  end

  def die
    unless @dead
      unless SB.stage.is_bonus
        if SB.stage.life_count == 0
          @lives -= 1
        else
          SB.stage.life_count -= 1
        end
        self.stage_score -= C::DEATH_PENALTY
      end
      @dead = true
      @bomb.die
    end
  end

  def add_item(item)
    item_type = "#{item[:type]}#{item[:extra]}"
    @items[item_type] = [] if @items[item_type].nil?
    @items[item_type] << item
    @cur_item_type = item_type
    @item_index = @items.keys.index(item_type)
  end

  def use_item(section, type = nil)
    if type
      @cur_item_type = type
      @item_index = @items.keys.index(type)
    end
    return if @cur_item_type.nil?
    item_type = @cur_item_type
    item_set = @items[item_type]
    item = item_set[0]
    if item[:obj].use(section, item)
      item_set.delete item
      if item_set.length == 0
        @items.delete item_type
        @item_index = 0 if @item_index >= @items.length
        @cur_item_type = @items.keys[@item_index]
      end
    end
  end

  def change_item(delta = 1)
    @item_index += delta
    @item_index = 0 if @item_index >= @items.length
    @item_index = @items.length - 1 if @item_index < 0
    @cur_item_type = @items.keys[@item_index]
  end

  def has_item?(type)
    @items.has_key?(type)
  end

  def score=(value)
    @score = value
    @score = 0 if @score < 0
  end

  def stage_score=(value)
    @stage_score = value
    @stage_score = 0 if @stage_score < 0
  end

  def bomb(type = nil)
    return @bombs[type] if type
    @bomb
  end

  def add_bomb
    case @last_world
    when 1 then @bombs[:vermelha] = Bomb.new(:vermelha, 0)
    when 2 then @bombs[:amarela]  = Bomb.new(:amarela,  0)
    when 3 then @bombs[:verde]    = Bomb.new(:verde,    0)
    when 6 then @bombs[:branca]   = Bomb.new(:branca,   0)
    end
  end

  def set_bomb(type)
    return if SB.stage.stopped == :all

    @bomb.stop
    bomb = @bombs[type]
    bomb.x = @bomb.x
    bomb.y = @bomb.y
    bomb.set_invulnerable(@bomb.invulnerable_time, @bomb.invulnerable_timer) if @bomb.invulnerable
    @bomb = bomb
    SB.stage.update_bomb

    return if @items.empty?
    cur_item = @items[@cur_item_type][0][:obj]
    if cur_item.respond_to?(:bomb_type) && !cur_item.bomb_type.nil? && cur_item.bomb_type != type
      item = @items.keys.find { |k| !@items[k][0][:obj].respond_to?(:bomb_type) || @items[k][0][:obj].bomb_type.nil? || @items[k][0][:obj].bomb_type == type }
      if item
        @item_index = @items.keys.index(item)
        @cur_item_type = item
      end
    end
  end

  def shift_bomb(section)
    return if SB.stage.stopped == :all

    ind = (@bombs.keys.index(@bomb.type) + 1) % @bombs.size
    set_bomb(BOMB_TYPES[ind])
    section.add_effect(Effect.new(@bomb.x + @bomb.w / 2 - 32, @bomb.y + @bomb.h / 2 - 32, :fx_spawn, 2, 2, 6))
  end

  def save_bomb_hps
    @bombs[:azul].save_hp
    @bombs[:vermelha].save_hp if @bombs[:vermelha]
    @bombs[:amarela].save_hp  if @bombs[:amarela]
    @bombs[:verde].save_hp    if @bombs[:verde]
    @bombs[:branca].save_hp   if @bombs[:branca]
  end

  def get_bomb_hps
    s =  "#{@bombs[:azul].saved_hp},"
    s += "#{@bombs[:vermelha].saved_hp}," if @bombs[:vermelha]
    s += "#{@bombs[:amarela].saved_hp},"  if @bombs[:amarela]
    s += "#{@bombs[:verde].saved_hp},"    if @bombs[:verde]
    s += "#{@bombs[:branca].saved_hp},"   if @bombs[:branca]
    s
  end

  def bomb_count
    @bombs.size
  end

  def update_timers
    @bombs.each { |k, v| v.update_timers if v != @bomb }
  end

  def reset(loaded = false)
    @items.clear
    @cur_item_type = nil
    @item_index = 0
    @dead = false
    @bombs.each { |k, v| v.reset(loaded) }
  end

  def game_over(world_num, stage_num)
    self.score -= C::GAME_OVER_PENALTY
    @lives = 5
    @specs.delete("#{world_num}-#{stage_num}")
    @startup_item = nil
    reset
  end
end
