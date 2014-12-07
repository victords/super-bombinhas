require_relative 'bomb'

class Player
  attr_reader :bomb
  attr_accessor :score, :lives

  def initialize score = 0, stage = 0, bomb = :azul, lives = 5, items = {}
    @score = score
    @stage = stage
    @bomb = Bomb.new bomb
    @lives = lives
    @items = items
  end

  def dead?
    @dead
  end

  def die
    unless @dead
      @lives -= 1
      @dead = true
      @bomb.reset
    end
  end

  def add_item item
    @items[item[:type]] = [] if @items[item[:type]].nil?
    @items[item[:type]] << item
    @cur_item_type = item[:type] if @cur_item_type.nil?
  end

  def use_item section
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

  def draw_stats
    G.window.draw_quad 5, 5, 0x80abcdef,
                       205, 5, 0x80abcdef,
                       205, 55, 0x80abcdef,
                       5, 55, 0x80abcdef, 0
    G.font.draw G.text(:lives), 10, 10, 0, 1, 1, 0xff000000
    G.font.draw @lives, 100, 10, 0, 1, 1, 0xff000000
    G.font.draw G.text(:score), 10, 30, 0, 1, 1, 0xff000000
    G.font.draw @score, 100, 30, 0, 1, 1, 0xff000000

    G.window.draw_quad 690, 5, 0x80abcdef,
                       740, 5, 0x80abcdef,
                       740, 55, 0x80abcdef,
                       690, 55, 0x80abcdef, 0
    G.window.draw_quad 745, 5, 0x80abcdef,
                       795, 5, 0x80abcdef,
                       795, 55, 0x80abcdef,
                       745, 55, 0x80abcdef, 0

    if @cur_item_type
      item_set = @items[@cur_item_type]
      item_set[0][:obj].icon.draw 695, 10, 0
      G.font.draw item_set.length.to_s, 725, 36, 0, 1, 1, 0xff000000
    end
    if @items.length > 1
      G.window.draw_triangle 690, 30, 0x80123456,
                             694, 26, 0x80123456,
                             694, 34, 0x80123456, 0
      G.window.draw_triangle 736, 25, 0x80123456,
                             741, 30, 0x80123456,
                             736, 35, 0x80123456, 0
    end
  end

  def reset
    @items.clear
    @bomb.reset
    @cur_item_type = nil
    @item_index = 0
    @dead = false
  end
end
