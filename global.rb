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
  BONUS_THRESHOLD = 5000
  BONUS_LEVELS = 2
  GAME_LIMIT = 10
  MOVIE_DELAY = 30
  LAST_WORLD = 5
  PANEL_COLOR = 0x80aaaaff
  ARROW_COLOR = 0x80000099
  DISABLED_COLOR = 0x80ffffff
  TILE_ANIM_INTERVAL = 7
  LIGHT_RADIUS = 100
  DARK_OPACITY = 254
  LEDGE_JUMP_TOLERANCE = 4
  EARLY_JUMP_TOLERANCE = 9
  CAMERA_HORIZ_SPEED = 1
  CAMERA_VERTICAL_SPEED = 0.03
  CAMERA_VERTICAL_DELAY = 45
  CAMERA_VERTICAL_TOLERANCE = 3 * TILE_SIZE
  CAMERA_VERTICAL_LIMIT = 6 * TILE_SIZE
  STARS_PER_STAGE = 5
end

class SB
  class << self
    attr_reader :font, :text_helper, :save_dir, :save_data, :lang, :full_screen
    attr_accessor :state, :player, :world, :stage, :movie, :music_volume, :sound_volume

    def load_options(save_dir)
      @save_dir = save_dir
      options_path = "#{save_dir}/options"
      if File.exist?(options_path)
        File.open(options_path) do |f|
          content = f.read
          if content.empty?
            create_options
          else
            data = content.chomp.split(',')
            @lang = data[0].to_sym
            @sound_volume = data[1].to_i
            @music_volume = data[2].to_i
            @full_screen = data[3].to_i > 0
          end
        end
      else
        create_options
      end
    end

    def initialize
      @state = :presentation

      Res.retro_images = true
      @font = ImageFont.new(:font_font, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÁÉÍÓÚÀÃÕÂÊÔÑÇáéíóúàãõâêôñç0123456789.,:;!?¡¿/\\()[]+-%'\"←→",
                            [6, 6, 6, 6, 6, 6, 6, 6, 2, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
                             6, 6, 6, 6, 6, 4, 6, 6, 2, 4, 5, 3, 8, 6, 6, 6, 6, 5, 6, 4, 6, 6, 8, 6, 6, 6,
                             6, 6, 2, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 2, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
                             6, 4, 6, 6, 6, 6, 6, 6, 6, 6, 2, 3, 2, 3, 2, 6, 2, 6, 5, 5, 3, 3, 3, 3, 6, 4, 6, 2, 4, 8, 8], 11, 3)
      @text_helper = TextHelper.new(@font, 5, 2, 2)
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

      @key = {
        up:      [Gosu::KB_UP, Gosu::GP_0_UP],
        right:   [Gosu::KB_RIGHT, Gosu::GP_0_RIGHT],
        down:    [Gosu::KB_DOWN, Gosu::GP_0_DOWN],
        left:    [Gosu::KB_LEFT, Gosu::GP_0_LEFT],
        jump:    [Gosu::KB_SPACE, Gosu::GP_0_BUTTON_0],
        item:    [Gosu::KB_X, Gosu::GP_0_BUTTON_1],
        ability: [Gosu::KB_C, Gosu::GP_0_BUTTON_2],
        bomb:    [Gosu::KB_LEFT_SHIFT, Gosu::GP_0_BUTTON_3],
        prev:    [Gosu::KB_Z, Gosu::GP_0_BUTTON_9],
        next:    [Gosu::KB_V, Gosu::GP_0_BUTTON_10],
        confirm: [Gosu::KB_RETURN, Gosu::GP_0_BUTTON_0],
        back:    [Gosu::KB_ESCAPE, Gosu::KB_BACKSPACE, Gosu::GP_0_BUTTON_1],
        pause:   [Gosu::KB_ESCAPE, Gosu::KB_BACKSPACE, Gosu::GP_0_BUTTON_6]
      }

      Menu.initialize
    end

    def create_options
      @lang = :english
      @sound_volume = 10
      @music_volume = 10
      @full_screen = false
      FileUtils.mkdir_p(@save_dir)
      save_options
    end

    def save_options
      File.open("#{@save_dir}/options", 'w') do |f|
        f.print("#{@lang},#{@sound_volume},#{@music_volume},#{@full_screen ? 1 : 0}")
      end
    end

    def toggle_full_screen
      @full_screen = !@full_screen
      G.window.toggle_fullscreen
    end

    def full_screen_toggled
      @full_screen = !@full_screen
    end

    def key_down?(id)
      @key[id].any? { |k| KB.key_down?(k) }
    end

    def key_pressed?(id)
      @key[id].any? { |k| KB.key_pressed?(k) }
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
      @player = Player.new(data[0],
                           last_world_stage[0].to_i,
                           last_world_stage[1].to_i,
                           data[3].to_sym,
                           data[8],
                           data[4].to_i,
                           data[5].to_i,
                           data[6],
                           data[12] && !data[12].empty? ? data[12].to_i : nil,
                           data[13] || '')
      @world = World.new(world_stage[0].to_i, world_stage[1].to_i, true)
      @save_file_name = file_name
      @save_data = data
      @world.resume
      StageMenu.initialize
    end

    def play_sound(sound, volume = 1)
      sound.play @sound_volume * 0.1 * volume if @sound_volume > 0
    end

    def end_stage
      if @bonus
        @bonus = nil
        StageMenu.end_stage(false, false, true)
      else
        if @stage.spec_taken
          @player.specs << @stage.id
        end
        if @stage.star_count == C::STARS_PER_STAGE
          @player.all_stars << @stage.id
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
        config = IO.read("#{Res.prefix}stage/bonus/config").split[@bonus-1].split(',').map(&:to_i)
        @stage = Stage.new('bonus', @bonus)
        @stage.start(false, config[0], config[1], config[2])
        @state = :main
      else
        @stage = @prev_stage if @prev_stage
        next_stage(continue)
      end
    end

    def next_stage(continue = true)
      # Res.clear
      @player.startup_item = @player.temp_startup_item
      @player.temp_startup_item = nil
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
        # @movie = Movie.new(@world.num)
        # @state = :movie
        next_world
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
      @save_data[12] = @player.startup_item.to_s
      @save_data[13] = @player.all_stars.join(',')
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
