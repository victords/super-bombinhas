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
  attr_reader :score, :items, :cur_item_type, :specs
  attr_accessor :name, :last_world, :last_stage, :lives, :stage_score, :startup_item, :temp_startup_item

  def initialize(name, last_world = 1, last_stage = 1, bomb = :azul, hps = nil, lives = 5, score = 0, specs = '', startup_item = nil)
    @name = name
    @last_world = last_world
    @last_stage = last_stage
    @bombs = {}
    hps =
      if hps
        hps.split(',').map{ |s| s.to_i }
      else
        [0, 0, 0, 0, 0]
      end
    @bombs[:azul]     = Bomb.new(:azul,     hps[0])
    @bombs[:vermelha] = Bomb.new(:vermelha, hps[1]) if last_world > 1
    @bombs[:amarela]  = Bomb.new(:amarela,  hps[2]) if last_world > 2
    @bombs[:verde]    = Bomb.new(:verde,    hps[3]) if last_world > 3
    @bombs[:branca]   = Bomb.new(:branca,   hps[4]) if last_world > 4
    @bomb = @bombs[bomb]
    @lives = lives
    @score = score
    @stage_score = 0
    @specs = specs.split(',')
    @items = {}
    @startup_item = startup_item
  end

  def dead?
    @dead
  end

  def die
    unless @dead
      @lives -= 1
      self.score -= C::DEATH_PENALTY
      @dead = true
      @bomb.die
    end
  end

  def add_item(item)
    item_type = item[:extra] || item[:type]
    @items[item_type] = [] if @items[item_type].nil?
    @items[item_type] << item
    @cur_item_type = item_type if @cur_item_type.nil?
  end

  def use_item(section)
    return if @cur_item_type.nil?
    item_set = @items[@cur_item_type]
    item = item_set[0]
    if item[:obj].use section, item
      item_set.delete item
      if item_set.length == 0
        @items.delete @cur_item_type
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

  def score=(value)
    @score = value
    @score = 0 if @score < 0
  end

  def bomb(type = nil)
    return @bombs[type] if type
    @bomb
  end

  def add_bomb
    case @last_world
    when 2 then @bombs[:vermelha] = Bomb.new(:vermelha, 0)
    when 3 then @bombs[:amarela]  = Bomb.new(:amarela,  0)
    when 4 then @bombs[:verde]    = Bomb.new(:verde,    0)
    when 5 then @bombs[:branca]   = Bomb.new(:branca,   0)
    end
  end

  def set_bomb(type)
    bomb = @bombs[type]
    bomb.x = @bomb.x
    bomb.y = @bomb.y
    @bomb = bomb
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

  def reset(loaded = false)
    @items.clear
    @cur_item_type = nil
    @item_index = 0
    @stage_score = 0
    @dead = false
    @bombs.each { |k, v| v.reset(loaded) }
  end

  def game_over
    self.score -= C::GAME_OVER_PENALTY
    @last_stage = 1
    @lives = 5
    @specs.delete_if { |s| s =~ /^#{@last_world}-/ }
    reset
  end
end
