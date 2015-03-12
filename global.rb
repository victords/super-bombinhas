require 'joystick'
require 'minigl'

module C
  TILE_SIZE = 32
  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600
  PLAYER_OVER_TOLERANCE = 10
  INVULNERABLE_TIME = 40
  BOUNCE_FORCE = 10
  TOP_MARGIN = -200
end

class SB
  class << self
    attr_reader :font, :save_data
    attr_accessor :state, :lang, :menu, :player, :world, :stage

    def initialize
      @state = :menu

      @font = Res.font :BankGothicMedium, 20
      @texts = {}
      files = Dir["#{Res.prefix}text/*.txt"]
      files.each do |f|
        lang = f.split('/')[-1].chomp('.txt').to_sym
        @texts[lang] = {}
        File.open(f).each do |l|
          parts = l.split "\t"
          @texts[lang][parts[0].to_sym] = parts[-1].chomp
        end
      end
      @lang = :portuguese

      StageMenu.initialize
    end

    def text(id)
      @texts[@lang][id.to_sym]
    end

    def load_game(name)
      @save_data = IO.readlines("#{Res.prefix}save/#{name}.sbg").map { |l| l.chomp }
      world_stage = @save_data[0].split('-')
      @world = World.new(world_stage[0].to_i, world_stage[1].to_i, true)
      @player = Player.new(name, save_data[1].to_sym, save_data[2].to_i, save_data[3].to_i)
      @state = :map
    end

    def save_and_exit
      name = @player.name || 'default'
      File.open("#{Res.prefix}save/#{name}.sbg", 'w') do |f|
        f.print "#{@world.num}-#{@stage.num}\n"\
                "#{@player.bomb.type}\n"\
                "#{@player.lives}\n"\
                "#{@player.score}\n"\
                "#{@player.specs.join(',')}\n"\
                "#{@stage.cur_entrance[:index]}\n"\
                "#{@player.bomb.hp}\n"
        # TODO: itens pegos, itens usados
      end
      @state = :map
    end
  end
end

class JSHelper
  attr_reader :is_valid

  def initialize(index)
    @j = Joystick::Device.new "/dev/input/js#{index}"
    @axes = {}
    @axes_prev = {}
    @btns = {}
    @btns_prev = {}
    if @j
      e = @j.event(true)
      while e
        if e.type == :axis
          @axes[e.number] = @axes_prev[e.number] = 0
        else
          @btns[e.number] = @btns_prev[e.number] = 0
        end
        e = @j.event(true)
      end
      @is_valid = true
    else
      @is_valid = false
    end
  end

  def update
    return unless @is_valid

    @axes_prev.keys.each do |k|
      @axes_prev[k] = 0
    end
    @btns_prev.keys.each do |k|
      @btns_prev[k] = 0
    end

    e = @j.event(true)
    while e
      if e.type == :axis
        @axes_prev[e.number] = @axes[e.number]
        @axes[e.number] = e.value
      else
        @btns_prev[e.number] = @btns[e.number]
        @btns[e.number] = e.value
      end
      e = @j.event(true)
    end
  end

  def button_down(btn)
    return false unless @is_valid
    @btns[btn] == 1
  end

  def button_pressed(btn)
    return false unless @is_valid
    @btns[btn] == 1 && @btns_prev[btn] == 0
  end

  def button_released(btn)
    return false unless @is_valid
    @btns[btn] == 0 && @btns_prev[btn] == 1
  end

  def axis_down(axis, dir)
    return false unless @is_valid
    return @axes[axis+1] < 0 if dir == :up
    return @axes[axis] > 0 if dir == :right
    return @axes[axis+1] > 0 if dir == :down
    return @axes[axis] < 0 if dir == :left
    false
  end

  def axis_pressed(axis, dir)
    return false unless @is_valid
    return @axes[axis+1] < 0 && @axes_prev[axis+1] >= 0 if dir == :up
    return @axes[axis] > 0 && @axes_prev[axis] <= 0 if dir == :right
    return @axes[axis+1] > 0 && @axes_prev[axis+1] <= 0 if dir == :down
    return @axes[axis] < 0 && @axes_prev[axis] >= 0 if dir == :left
    false
  end

  def axis_released(axis, dir)
    return false unless @is_valid
    return @axes[axis+1] >= 0 && @axes_prev[axis+1] < 0 if dir == :up
    return @axes[axis] <= 0 && @axes_prev[axis] > 0 if dir == :right
    return @axes[axis+1] <= 0 && @axes_prev[axis+1] > 0 if dir == :down
    return @axes[axis] >= 0 && @axes_prev[axis] < 0 if dir == :left
    false
  end

  def close
    @j.close if @is_valid
  end
end
