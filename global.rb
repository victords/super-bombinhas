# require 'joystick'
require 'minigl'
require 'fileutils'

module C
  TILE_SIZE = 32
  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600
  PLAYER_OVER_TOLERANCE = 12
  INVULNERABLE_TIME = 90
  BOUNCE_SPEED_BASE = 5
  BOUNCE_SPEED_INCREMENT = 7
  TOP_MARGIN = -200
  EXIT_MARGIN = 16
  DEATH_PENALTY = 1_000
  GAME_OVER_PENALTY = 10_000
  BONUS_THRESHOLD = 100_000_000
  BONUS_LEVELS = 5
  GAME_LIMIT = 10
  MOVIE_DELAY = 30
  LAST_WORLD = 3
  PANEL_COLOR = 0x80aaaaff
  ARROW_COLOR = 0x80000099
  TILE_ANIM_INTERVAL = 7
  STOP_TIME_COOLDOWN = 3000
  EXPLODE_COOLDOWN = 1800
  LIGHT_RADIUS = 100
  DARK_OPACITY = 254
end

class SB
  class << self
    attr_reader :font, :big_font, :small_font, :text_helper, :big_text_helper, :small_text_helper, :save_dir, :save_data, :lang, :key
    attr_accessor :state, :player, :world, :stage, :movie, :music_volume, :sound_volume

    def initialize(save_dir)
      @state = :presentation

      Res.retro_images = true
      @font = Res.font :minecraftia, 24
      @big_font = Res.font :minecraftia, 32
      @small_font = Res.font :minecraftia, 12
      @text_helper = TextHelper.new(@font, 5)
      @big_text_helper = TextHelper.new(@big_font, 8)
      @small_text_helper = TextHelper.new(@small_font, -4)
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

      @save_dir = save_dir
      options_path = "#{save_dir}/options"
      if File.exist?(options_path)
        File.open(options_path) do |f|
          data = f.readline.chomp.split ','
          @lang = data[0].to_sym
          @sound_volume = data[1].to_i
          @music_volume = data[2].to_i
          @key = {}
          keys = data[3..-1].map { |i| i.to_i }
          keys_keys = [:up, :right, :down, :left, :jump, :item, :next, :ab]
          keys.each_with_index { |k, i| @key[keys_keys[i]] = k }
        end
      else
        @lang = :english
        @sound_volume = 10
        @music_volume = 10
        @key = {
          up:    Gosu::KbUp,
          right: Gosu::KbRight,
          down:  Gosu::KbDown,
          left:  Gosu::KbLeft,
          jump:  Gosu::KbSpace,
          item:  Gosu::KbA,
          next:  Gosu::KbLeftShift,
          ab:    Gosu::KbS
        }
        FileUtils.mkdir_p save_dir
        File.open(options_path, 'w') do |f|
          f.print "#{@lang},#{@sound_volume},#{@music_volume},#{@key.values.join(',')}"
        end
      end

      Options.initialize
      Menu.initialize
    end

    def text(id)
      @texts[@lang].fetch(id.to_sym, '<!>')
    end

    def play_song(song)
      cur_song = Gosu::Song.current_song
      if cur_song
        return if cur_song == song
        Gosu::Song.current_song.stop
      end
      song.volume = @music_volume * 0.1
      song.play true
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
      StageMenu.update_lang if StageMenu.ready
    end

    def change_volume(type, d = 1)
      vol = eval("@#{type}_volume") + d
      vol = 0 if vol < 0
      vol = 10 if vol > 10
      instance_eval("@#{type}_volume = #{vol}")
      Gosu::Song.current_song.volume = vol * 0.1 if Gosu::Song.current_song and type == 'music'
    end

    def save_options(controls)
      @key.keys.each_with_index { |k, i| @key[k] = controls[i] }
      File.open("#{@save_dir}/options", 'w') do |f|
        f.print("#{@lang},#{@sound_volume},#{@music_volume},#{@key.values.join(',')}")
      end
    end

    def new_game(name, index)
      @player = Player.new name
      @world = World.new
      @save_file_name = "#{@save_dir}/#{index}"
      @save_data = Array.new(12)

      # @movie = Movie.new 0
      # @state = :movie
      SB.start_new_game
    end

    def start_new_game
      @world.resume
      StageMenu.initialize
    end

    def load_game(file_name)
      data = IO.readlines(file_name).map { |l| l.chomp }
      world_stage = data[1].split('-')
      last_world_stage = data[2].split('-')
      @player = Player.new(data[0], last_world_stage[0].to_i, last_world_stage[1].to_i, data[3].to_sym, data[8], data[4].to_i, data[5].to_i, data[6])
      @world = World.new(world_stage[0].to_i, world_stage[1].to_i, true)
      @save_file_name = file_name
      @save_data = data
      @world.resume
      StageMenu.initialize
    end

    def play_sound(sound)
      sound.play @sound_volume * 0.1 if @sound_volume > 0
    end

    def set_spec_taken
      @spec_taken = true
    end

    def end_stage
      @player.bomb.celebrate
      if @bonus
        @bonus = nil
        StageMenu.end_stage(false, false, true)
      else
        if @spec_taken
          @player.specs << @stage.id
          @spec_taken = false
        end
        prev_factor = @player.score / C::BONUS_THRESHOLD
        @player.score += @player.stage_score
        factor = @player.score / C::BONUS_THRESHOLD
        @bonus = (factor - 1) % C::BONUS_LEVELS + 1 if factor > prev_factor
        @prev_stage = @stage
        StageMenu.end_stage(@stage.num == @world.stage_count, @bonus)
      end
      @state = :stage_end
    end

    def check_next_stage(continue = true)
      if @bonus
        StageMenu.initialize
        time = IO.read("#{Res.prefix}stage/bonus/times").split[@bonus-1].to_i
        @stage = Stage.new('bonus', @bonus)
        @stage.start(false, time)
        @state = :main
      else
        @stage = @prev_stage if @prev_stage
        next_stage(continue)
      end
    end

    def next_stage(continue = true)
      # Res.clear
      @prev_stage = @bonus = nil
      if @world.num < @player.last_world ||
         @stage.num != @player.last_stage ||
         @stage.num == @world.stage_count && @save_data[11].to_i >= C::LAST_WORLD - 1
        save_and_exit(@stage.num)
        StageMenu.initialize
        return
      end
      @world.open_stage(continue)
      num = @stage.num + 1
      if num <= @world.stage_count
        @player.last_stage = num
        if continue
          save
          @stage = Stage.new(@world.num, num)
          @stage.start
          @state = :main
        else
          save_and_exit(@stage.num)
        end
      else
        if @world.num < C::LAST_WORLD - 1
          @player.last_world = @world.num + 1
          @player.last_stage = 1
          @player.add_bomb
          save
        else
          save(nil, @world.num)
        end
        @movie = Movie.new(@world.num)
        @state = :movie
      end
      StageMenu.initialize
    end

    def next_world
      if @world.num == C::LAST_WORLD - 1
        @state = :game_end
      elsif @world.num == C::LAST_WORLD
        @state = :game_end_2
      else
        @world = World.new(@world.num + 1, 1)
        save(1)
        @world.resume
      end
    end

    def prepare_special_world
      @movie = Movie.new('s')
      @state = :movie
      @player.reset
      StageMenu.initialize
    end

    def open_special_world
      @player.last_world = C::LAST_WORLD
      @player.last_stage = 1
      @world = World.new(C::LAST_WORLD, 1)
      save(1)
      @world.resume
    end

    def game_over
      @player.game_over
      @world = World.new(@player.last_world, 1)
      save(1)
      @world.resume
    end

    def save(stage_num = nil, special_world = nil)
      @save_data[0] = @player.name
      @save_data[1] = "#{@world.num}-#{stage_num || @stage.num}"
      @save_data[2] = "#{@player.last_world}-#{@player.last_stage}"
      @save_data[3] = @player.bomb.type.to_s
      @save_data[4] = @player.lives.to_s
      @save_data[5] = @player.score.to_s
      @save_data[6] = @player.specs.join(',')
      @save_data[7] = stage_num ? '0' : @stage.cur_entrance[:index].to_s
      @save_data[8] = @player.get_bomb_hps
      @save_data[9] = stage_num ? '' : @stage.switches_by_state(:taken).concat(@stage.switches_by_state(:taken_temp_used)).sort.join(',')
      @save_data[10] = stage_num ? '' : @stage.switches_by_state(:used).sort.join(',')
      @save_data[11] = special_world.to_s || ''
      File.open(@save_file_name, 'w') do |f|
        @save_data.each { |s| f.print(s + "\n") }
      end
    end

    def save_and_exit(stage_num = nil)
      if @bonus
        @stage = @prev_stage
        next_stage(false)
      else
        save(stage_num)
        @world.set_loaded @stage.num
        @world.resume
      end
    end
  end
end

# class JSHelper
#   attr_reader :is_valid
#
#   def initialize(index)
#     @j = Joystick::Device.new "/dev/input/js#{index}"
#     @axes = {}
#     @axes_prev = {}
#     @btns = {}
#     @btns_prev = {}
#     if @j
#       e = @j.event(true)
#       while e
#         if e.type == :axis
#           @axes[e.number] = @axes_prev[e.number] = 0
#         else
#           @btns[e.number] = @btns_prev[e.number] = 0
#         end
#         e = @j.event(true)
#       end
#       @is_valid = true
#     else
#       @is_valid = false
#     end
#   end
#
#   def update
#     return unless @is_valid
#
#     @axes_prev.keys.each do |k|
#       @axes_prev[k] = 0
#     end
#     @btns_prev.keys.each do |k|
#       @btns_prev[k] = 0
#     end
#
#     e = @j.event(true)
#     while e
#       if e.type == :axis
#         @axes_prev[e.number] = @axes[e.number]
#         @axes[e.number] = e.value
#       else
#         @btns_prev[e.number] = @btns[e.number]
#         @btns[e.number] = e.value
#       end
#       e = @j.event(true)
#     end
#   end
#
#   def button_down(btn)
#     return false unless @is_valid
#     @btns[btn] == 1
#   end
#
#   def button_pressed(btn)
#     return false unless @is_valid
#     @btns[btn] == 1 && @btns_prev[btn] == 0
#   end
#
#   def button_released(btn)
#     return false unless @is_valid
#     @btns[btn] == 0 && @btns_prev[btn] == 1
#   end
#
#   def axis_down(axis, dir)
#     return false unless @is_valid
#     return @axes[axis+1] < 0 if dir == :up
#     return @axes[axis] > 0 if dir == :right
#     return @axes[axis+1] > 0 if dir == :down
#     return @axes[axis] < 0 if dir == :left
#     false
#   end
#
#   def axis_pressed(axis, dir)
#     return false unless @is_valid
#     return @axes[axis+1] < 0 && @axes_prev[axis+1] >= 0 if dir == :up
#     return @axes[axis] > 0 && @axes_prev[axis] <= 0 if dir == :right
#     return @axes[axis+1] > 0 && @axes_prev[axis+1] <= 0 if dir == :down
#     return @axes[axis] < 0 && @axes_prev[axis] >= 0 if dir == :left
#     false
#   end
#
#   def axis_released(axis, dir)
#     return false unless @is_valid
#     return @axes[axis+1] >= 0 && @axes_prev[axis+1] < 0 if dir == :up
#     return @axes[axis] <= 0 && @axes_prev[axis] > 0 if dir == :right
#     return @axes[axis+1] <= 0 && @axes_prev[axis+1] > 0 if dir == :down
#     return @axes[axis] >= 0 && @axes_prev[axis] < 0 if dir == :left
#     false
#   end
#
#   def close
#     @j.close if @is_valid
#   end
# end
