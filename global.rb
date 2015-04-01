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
  EXIT_MARGIN = 16
  GAME_LIMIT = 10
  PANEL_COLOR = 0x80aaaaff
  ARROW_COLOR = 0x80000099
end

class SB
  class << self
    attr_reader :font, :big_font, :text_helper, :big_text_helper, :save_data, :lang
    attr_accessor :state, :player, :world, :stage, :music_volume, :sound_volume

    def initialize
      @state = :menu

      @font = Res.font :BankGothicMedium, 20
      @big_font = Res.font :BankGothicMedium, 36
      @text_helper = TextHelper.new(@font, 5)
      @big_text_helper = TextHelper.new(@big_font, 8)
      @langs = []
      @texts = {}
      files = Dir["#{Res.prefix}text/*.txt"]
      files.each do |f|
        lang = f.split('/')[-1].chomp('.txt').to_sym
        @langs << lang
        @texts[lang] = {}
        File.open(f).each do |l|
          parts = l.split "\t"
          @texts[lang][parts[0].to_sym] = parts[-1].chomp
        end
      end

      options_path = "#{Res.prefix}save/options"
      unless File.exist?(options_path)
        File.open(options_path, 'w') do |f|
          f.print 'english,10,10'
        end
      end
      File.open(options_path) do |f|
        data = f.readline.chomp.split ','
        @lang = data[0].to_sym
        @sound_volume = data[1].to_i
        @music_volume = data[2].to_i
      end

      Menu.initialize
      StageMenu.initialize
    end

    def text(id)
      @texts[@lang].fetch(id.to_sym, '<!>')
    end

    def change_lang(d = 1)
      ind = @langs.index(@lang) + d
      ind = 0 if ind == @langs.length
      ind = @langs.length - 1 if ind < 0
      @lang = @langs[ind]
      Menu.update_lang
      StageMenu.update_lang
    end

    def lang=(value)
      @lang = value
      Menu.update_lang
      StageMenu.update_lang
    end

    def change_volume(type, d = 1)
      vol = eval("@#{type}_volume") + d
      vol = 0 if vol < 0
      vol = 10 if vol > 10
      instance_eval("@#{type}_volume = #{vol}")
    end

    def save_options
      File.open("#{Res.prefix}save/options", 'w') do |f|
        f.print("#{@lang},#{@sound_volume},#{@music_volume}")
      end
    end

    def new_game(name, index)
      @world = World.new
      @player = Player.new name
      @save_file_name = "#{Res.prefix}save/#{index}"
      @save_data = Array.new(10)
      @state = :map
    end

    def load_game(file_name)
      data = IO.readlines(file_name).map { |l| l.chomp }
      world_stage = data[1].split('-')
      last_world_stage = data[2].split('-')
      @world = World.new(world_stage[0].to_i, world_stage[1].to_i, last_world_stage[1].to_i, true, data[3])
      @player = Player.new(data[0], last_world_stage[0].to_i, last_world_stage[1].to_i, data[3].to_sym, data[4].to_i, data[5].to_i, data[6])
      @save_file_name = file_name
      @save_data = data
      @state = :map
    end

    def end_stage
      @player.bomb.celebrate
      @player.score += @player.stage_score
      StageMenu.end_stage
      @state = :stage_end
    end

    def next_stage
      # Res.clear
      num = @stage.num + 1
      if num <= @world.stage_count
        # deve ter alguma transição, mostrar os pontos, etc.
        @stage = Stage.new(@world.num, num)
        @player.last_stage = @stage.num
        @world.open_stage
        @stage.start
      else
        # a definir...
      end
      StageMenu.reset
      @state = :main
    end

    def save_and_exit
      @save_data[0] = @player.name
      @save_data[1] = "#{@world.num}-#{@stage.num}"
      @save_data[2] = "#{@player.last_world}-#{@player.last_stage}"
      @save_data[3] = @player.bomb.type.to_s
      @save_data[4] = @player.lives.to_s
      @save_data[5] = @player.score.to_s
      @save_data[6] = @player.specs.join(',')
      @save_data[7] = @stage.cur_entrance[:index].to_s
      @save_data[8] = @player.bomb.hp.to_s
      @save_data[9] = @stage.switches_by_state(:taken)
      @save_data[10] = @stage.switches_by_state(:used)
      File.open(@save_file_name, 'w') do |f|
        @save_data.each { |s| f.print(s + "\n") }
      end
      @world.set_loaded @stage.num
      StageMenu.reset
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
