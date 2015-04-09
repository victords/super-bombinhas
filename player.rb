require_relative 'bomb'

class Player
  attr_reader :bomb, :items, :cur_item_type, :specs
  attr_accessor :name, :last_world, :last_stage, :lives, :score, :stage_score

  def initialize(name, last_world = 1, last_stage = 1, bomb = :azul, hps = nil, lives = 5, score = 0, specs = '')
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
  end

  def dead?
    @dead
  end

  def die
    unless @dead
      @lives -= 1
      @dead = true
      @bombs.each { |k, v| v.reset }
    end
  end

  def add_item(item)
    @items[item[:type]] = [] if @items[item[:type]].nil?
    @items[item[:type]] << item
    @cur_item_type = item[:type] if @cur_item_type.nil?
  end

  def use_item(section)
    return if @cur_item_type.nil?
    item_set = @items[@cur_item_type]
    item = item_set[0]
    if item[:obj].use section
      if item[:state] == :temp_taken
        item[:state] = :temp_taken_used
      else
        item[:state] = :temp_used
      end

      item_set.delete item
      if item_set.length == 0
        @items.delete @cur_item_type
        @item_index = 0 if @item_index >= @items.length
        @cur_item_type = @items.keys[@item_index]
      end
    end
  end

  def change_item
    @item_index += 1
    @item_index = 0 if @item_index >= @items.length
    @cur_item_type = @items.keys[@item_index]
  end

  def set_bomb(type)
    bomb = @bombs[type]
    bomb.x = @bomb.x
    bomb.y = @bomb.y
    @bomb = bomb
  end

  def get_bomb_hps
    s =  "#{@bombs[:azul].hp},"
    s += "#{@bombs[:vermelha].hp}," if @bombs[:vermelha]
    s += "#{@bombs[:amarela].hp},"  if @bombs[:amarela]
    s += "#{@bombs[:verde].hp},"    if @bombs[:verde]
    s += "#{@bombs[:branca].hp},"   if @bombs[:branca]
    s
  end

  def reset
    @items.clear
    @bomb.reset
    @cur_item_type = nil
    @item_index = 0
    @stage_score = 0
    @dead = false
  end
end
