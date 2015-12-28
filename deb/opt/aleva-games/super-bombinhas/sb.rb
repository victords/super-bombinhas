require 'minigl'
require 'fileutils'
require 'rbconfig'
include MiniGL
module C
  TILE_SIZE = 32
  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600
  PLAYER_OVER_TOLERANCE = 12
  INVULNERABLE_TIME = 120
  BOUNCE_SPEED = 5
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
  STOP_TIME_DURATION = 1200
  STOP_TIME_COOLDOWN = 3000
  EXPLODE_COOLDOWN = 1800
end
class SB
  class << self
    attr_reader :font, :big_font, :text_helper, :big_text_helper, :small_text_helper, :save_dir, :save_data, :lang
    attr_accessor :state, :player, :world, :stage, :movie, :music_volume, :sound_volume
    def initialize(save_dir)
      @state = :presentation
      @font = Res.font :BankGothicMedium, 20
      @big_font = Res.font :BankGothicMedium, 36
      @text_helper = TextHelper.new(@font, 5)
      @big_text_helper = TextHelper.new(@big_font, 8)
      @small_text_helper = TextHelper.new(Res.font(:BankGothicMedium, 16), -4)
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
      unless File.exist?(save_dir)
        FileUtils.mkdir_p save_dir
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
    def save_options
      File.open("#{@save_dir}/options", 'w') do |f|
        f.print("#{@lang},#{@sound_volume},#{@music_volume}")
      end
    end
    def new_game(name, index)
      @player = Player.new name
      @world = World.new
      @save_file_name = "#{@save_dir}/#{index}"
      @save_data = Array.new(10)
      @movie = Movie.new 0
      @state = :movie
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
        @stage = Stage.new('bonus', @bonus, false, time)
        @stage.start
        @state = :main
      else
        @stage = @prev_stage if @prev_stage
        next_stage(continue)
      end
    end
    def next_stage(continue = true)
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
      @save_data[9] = stage_num ? '' : @stage.switches_by_state(:taken)
      @save_data[10] = stage_num ? '' : @stage.switches_by_state(:used)
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
class Bomb < GameObject
  attr_reader :type, :name, :hp, :facing_right, :can_use_ability, :will_explode
  attr_accessor :active
  def initialize(type, hp)
    case type
    when :azul     then @name = 'Bomba Azul';     def_hp = 1; @max_hp = 1;   l_img_gap = -10; r_img_gap = -10; t_img_gap = -9
    when :vermelha then @name = 'Bomba Vermelha'; def_hp = 2; @max_hp = 999; l_img_gap = -4; r_img_gap = -6;   t_img_gap = -13
    when :amarela  then @name = 'Bomba Amarela';  def_hp = 1; @max_hp = 1;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -13
    when :verde    then @name = 'Bomba Verde';    def_hp = 2; @max_hp = 3;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -13
    else                @name = 'Aldan';          def_hp = 1; @max_hp = 2;   l_img_gap = -6; r_img_gap = -14;  t_img_gap = -29
    end
    super -1000, -1000, 20, 27, "sprite_Bomba#{type.to_s.capitalize}", Vector.new(r_img_gap, t_img_gap), 6, 2
    @hp = hp == 0 ? def_hp : hp
    @max_speed.x = type == :amarela ? 6 : 4
    @max_speed.y = 20
    @jump_speed = type == :amarela ? 0.58 : 0.45
    @indices = [0, 1, 0, 2]
    @facing_right = true
    @active = true
    @type = type
    @explosion = Sprite.new 0, 0, :fx_Explosion, 2, 2
    @explosion_timer = 0
    @explosion_counter = 10
    @can_use_ability = true
  end
  def update(section)
    forces = Vector.new 0, 0
    walking = false
    if @celebrating
      animate @indices, 8 unless @img_index == 7
    elsif @dying
      animate @indices, 8 unless @img_index == 10
    elsif @exploding
      @explosion.animate [0, 1, 2, 3], 5
      @explosion_counter += 1
      @exploding = false if @explosion_counter == 90
      forces.x -= 0.3 * @speed.x if @bottom and @speed.x != 0
    elsif @active
      if @invulnerable
        @invulnerable_timer += 1
        @invulnerable = false if @invulnerable_timer == @invulnerable_time
      end
      if @will_explode
        @explosion_timer += 1
        if @explosion_timer == 60
          @explosion_counter -= 1
          explode if @explosion_counter == 0
          @explosion_timer = 0
        end
      end
      if KB.key_down? Gosu::KbLeft
        @facing_right = false
        forces.x -= @bottom ? 0.3 : 0.2
        walking = true
      end
      if KB.key_down? Gosu::KbRight
        @facing_right = true
        forces.x += @bottom ? 0.3 : 0.2
        walking = true
      end
      if @bottom
        if @speed.x != 0
          animate @indices, 30 / @speed.x.abs
        else
          set_animation 0
        end
        if KB.key_pressed? Gosu::KbSpace
          forces.y -= 12 + @jump_speed * @speed.x.abs
          set_animation 3
        end
      end
      SB.player.change_item if KB.key_pressed? Gosu::KbLeftShift or KB.key_pressed? Gosu::KbRightShift
      SB.player.use_item section if KB.key_pressed? Gosu::KbA
      if @can_use_ability
        if KB.key_pressed? Gosu::KbS
          if @type == :verde
            explode(false); @can_use_ability = false; @cooldown = C::EXPLODE_COOLDOWN
          elsif @type == :branca
            SB.stage.stop_time; @can_use_ability = false; @cooldown = C::STOP_TIME_COOLDOWN
          end
        end
      else
        @cooldown -= 1
        if @cooldown == 0
          @can_use_ability = true
        end
      end
      hit if section.projectile_hit?(self)
    end
    forces.x -= 0.3 * @speed.x if @bottom and not walking
    move forces, section.get_obstacles(@x, @y), section.ramps if @active
  end
  def do_warp(x, y)
    @speed.x = @speed.y = 0
    @x = x + C::TILE_SIZE / 2 - @w / 2; @y = y + C::TILE_SIZE - @h
    @facing_right = true
    @indices = [0, 1, 0, 2]
    set_animation 0
  end
  def set_exploding
    @will_explode = true
    @explosion_timer = 0
    @explosion_counter = 10
  end
  def explode(gun_powder = true)
    @will_explode = false
    @exploding = true
    @explosion_timer = 0
    @explosion_radius = if gun_powder
                          @type == :verde ? 135 : 90
                        else
                          90
                        end
    @explosion.x = @x + @w / 2 - @explosion_radius
    @explosion.y = @y + @h / 2 - @explosion_radius
    set_animation 4
  end
  def explode?(obj)
    return false unless @exploding
    c_x = @x + @w / 2; c_y = @y + @h / 2
    o_c_x = obj.x + obj.w / 2; o_c_y = obj.y + obj.h / 2
    sq_dist = (o_c_x - c_x)**2 + (o_c_y - c_y)**2
    sq_dist <= @explosion_radius**2
  end
  def collide?(obj)
    bounds.intersect? obj.bounds
  end
  def over?(obj)
    @x + @w > obj.x and obj.x + obj.w > @x and
      @y + @h > obj.y and @y + @h <= obj.y + C::PLAYER_OVER_TOLERANCE
  end
  def hit(damage = 1)
    unless @invulnerable
      @hp -= damage
      @hp = 0 if @hp < 0
      if @hp == 0
        SB.player.die
        return
      end
      set_invulnerable
    end
  end
  def hp=(value)
    @hp = value
    @hp = @max_hp if @hp > @max_hp
  end
  def set_invulnerable(time = nil)
    @invulnerable = true
    @invulnerable_timer = 0
    @invulnerable_time = time || C::INVULNERABLE_TIME
  end
  def reset
    @will_explode = @exploding = @celebrating = @dying = false
    @speed.x = @speed.y = @stored_forces.x = @stored_forces.y = 0
    @hp = @max_hp
    @active = @facing_right = true
  end
  def celebrate
    @celebrating = true
    @indices = [5, 6, 7]
    set_animation 5
  end
  def die
    @dying = true
    @indices = [8, 9, 10]
    set_animation 8
    stop
  end
  def stop
    @speed.x = @speed.y = @stored_forces.x = @stored_forces.y = 0
  end
  def is_visible(map)
    true
  end
  def draw(map)
    super map, 1, 1, 255, 0xffffff, nil, @facing_right ? nil : :horiz
    if @will_explode
      SB.font.draw_rel SB.text(:count_down), 400, 200, 0, 0.5, 0.5, 1, 1, 0xff000000 if @explosion_counter > 6
      SB.font.draw_rel @explosion_counter.to_s, 400, 220, 0, 0.5, 0.5, 1, 1, 0xff000000
    end
    @explosion.draw map, @explosion_radius.to_f / 90, @explosion_radius.to_f / 90 if @exploding
  end
end
class TwoStateObject < GameObject
  def initialize(x, y, w, h, img, img_gap, sprite_cols, sprite_rows,
    change_interval, anim_interval, change_anim_interval, s1_indices, s2_indices, s1_s2_indices, s2_s1_indices, s2_first = false)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
    @timer = 0
    @changing = false
    @change_interval = change_interval
    @anim_interval = anim_interval
    @change_anim_interval = change_anim_interval
    @s1_indices = s1_indices
    @s2_indices = s2_indices
    @s1_s2_indices = s1_s2_indices
    @s2_s1_indices = s2_s1_indices
    @state2 = s2_first
    set_animation s2_indices[0] if s2_first
  end
  def update(section)
    @timer += 1
    if @timer == @change_interval
      @state2 = (not @state2)
      if @state2
        s1_to_s2 section
        set_animation @s1_s2_indices[0]
      else
        s2_to_s1 section
        set_animation @s2_s1_indices[0]
      end
      @changing = true
      @timer = 0
    end
    if @changing
      if @state2
        animate @s1_s2_indices, @change_anim_interval
        if @img_index == @s1_s2_indices[-1]
          set_animation @s1_s2_indices[-2]
          @changing = false
        end
      else
        animate @s2_s1_indices, @change_anim_interval
        if @img_index == @s2_s1_indices[-1]
          set_animation @s2_s1_indices[-2]
          @changing = false
        end
      end
    elsif @state2
      animate @s2_indices, @anim_interval if @anim_interval > 0
    else
      animate @s1_indices, @anim_interval if @anim_interval > 0
    end
  end
end
class Goal < GameObject
  def initialize(x, y, args, section)
    super x - 4, y - 118, 40, 150, :sprite_goal1, nil, 2, 2
    @active_bounds = Rectangle.new x - 4, y - 118, 40, 150
  end
  def update(section)
    animate [0, 1, 2, 3], 7
    section.finish if SB.player.bomb.collide? self
  end
end
class Bombie < GameObject
  def initialize(x, y, args, section)
    super x - 16, y, 64, 32, :sprite_Bombie, Vector.new(17, -2), 6, 1
    @msg_id = "msg#{args.to_i}".to_sym
    @pages = SB.text(@msg_id).split('/').size
    @balloon = Res.img :fx_Balloon1
    @facing_right = false
    @active = false
    @speaking = false
    @interval = 8
    @active_bounds = Rectangle.new x - 16, y, 64, 32
  end
  def update(section)
    if SB.player.bomb.collide? self
      if not @facing_right and SB.player.bomb.bounds.x > @x + @w / 2
        @facing_right = true
        @indices = [3, 4, 5]
        set_animation 3
      elsif @facing_right and SB.player.bomb.bounds.x < @x + @w / 2
        @facing_right = false
        @indices = [0, 1, 2]
        set_animation 0
      end
      if KB.key_pressed? Gosu::KbUp
        @speaking = (not @speaking)
        if @speaking
          if @facing_right; @indices = [3, 4, 5]
          else; @indices = [0, 1, 2]; end
          @active = false
        else
          @page = 0
          if @facing_right; set_animation 3
          else; set_animation 0; end
        end
      elsif @speaking and KB.key_pressed? Gosu::KbDown
        if @page < @pages - 1
          @page += 1
        else
          @page = 0
          @speaking = false
          if @facing_right; set_animation 3
          else; set_animation 0; end
        end
      end
      @active = (not @speaking)
    else
      @page = 0
      @active = false
      @speaking = false
      if @facing_right; set_animation 3
      else; set_animation 0; end
    end
    animate @indices, @interval if @speaking
  end
  def draw(map)
    super map
    @balloon.draw @x - map.cam.x + 16, @y - map.cam.y - 32, 0 if @active
    speak(@msg_id, @page) if @speaking
  end
end
class Door < GameObject
  attr_reader :locked
  def initialize(x, y, args, section, switch)
    super x + 15, y + 63, 2, 1, :sprite_Door, Vector.new(-15, -63), 5, 1
    args = args.split(',')
    @entrance = args[0].to_i
    @locked = (switch[:state] != :taken and args[1])
    @open = false
    @active_bounds = Rectangle.new x, y, 32, 64
    @lock = Res.img(:sprite_Lock) if @locked
  end
  def update(section)
    collide = SB.player.bomb.collide? self
    if @locked and collide
      section.active_object = self
    elsif section.active_object == self
      section.active_object = nil
    end
    if not @locked and not @opening and collide
      if KB.key_pressed? Gosu::KbUp
        set_animation 1
        @opening = true
      end
    end
    if @opening
      animate [1, 2, 3, 4, 0], 5
      if @img_index == 0
        section.warp = @entrance
        @opening = false
      end
    end
  end
  def unlock(section)
    @locked = false
    @lock = nil
    section.active_object = nil
    SB.stage.set_switch self
  end
  def draw(map)
    super map
    @lock.draw(@x + 4 - map.cam.x, @y - 38 - map.cam.y, 0) if @lock
  end
end
class GunPowder < GameObject
  def initialize(x, y, args, section, switch)
    return if switch && switch[:state] == :taken
    super x + 3, y + 19, 26, 13, :sprite_GunPowder, Vector.new(-2, -2)
    @switch = !switch.nil?
    @life = 10
    @counter = 0
    @active_bounds = Rectangle.new x + 1, y + 17, 30, 15
  end
  def update(section)
    b = SB.player.bomb
    if b.collide? self and not b.will_explode
      b.set_exploding
      SB.stage.set_switch self if @switch
      @dead = true
    end
  end
end
class Crack < GameObject
  def initialize(x, y, args, section, switch)
    super x + 32, y, 32, 32, :sprite_Crack
    @active_bounds = Rectangle.new x + 32, y, 32, 32
    @broken = switch[:state] == :taken
  end
  def update(section)
    if @broken or SB.player.bomb.explode? self
      i = (@x / C::TILE_SIZE).floor
      j = (@y / C::TILE_SIZE).floor
      section.tiles[i][j].broken = true
      SB.stage.set_switch self
      @dead = true
    end
  end
end
class Elevator < GameObject
  def initialize(x, y, args, section)
    a = args.split(':')
    type = a[0].to_i
    open = a[0][-1] == '!'
    case type
      when 1 then w = 32; cols = rows = nil
      when 2 then w = 64; cols = 4; rows = 1
      when 3 then w = 64; cols = rows = nil
    end
    super x, y, w, 1, "sprite_Elevator#{type}", Vector.new(0, 0), cols, rows
    @passable = true
    @speed_m = a[1].to_i
    @moving = false
    @points = []
    min_x = x; min_y = y
    max_x = x; max_y = y
    ps = a[2..-1]
    ps.each do |p|
      coords = p.split ','
      p_x = coords[0].to_i * C::TILE_SIZE; p_y = coords[1].to_i * C::TILE_SIZE
      min_x = p_x if p_x < min_x
      min_y = p_y if p_y < min_y
      max_x = p_x if p_x > max_x
      max_y = p_y if p_y > max_y
      @points << Vector.new(p_x, p_y)
    end
    if open
      (@points.length - 2).downto(0) do |i|
        @points << @points[i]
      end
    end
    @points << Vector.new(x, y)
    @indices = *(0...@img.size)
    @active_bounds = Rectangle.new min_x, min_y, (max_x - min_x + w), (max_y - min_y + @img[0].height)
    section.obstacles << self
  end
  def update(section)
    b = SB.player.bomb
    cycle @points, @speed_m, section.passengers, section.get_obstacles(b.x, b.y), section.ramps
    animate @indices, 8
  end
  def is_visible(map)
    true
  end
end
class SaveBombie < GameObject
  def initialize(x, y, args, section, switch)
    super x - 16, y, 64, 32, :sprite_Bombie2, Vector.new(-16, -26), 4, 2
    @id = args.to_i
    @active_bounds = Rectangle.new x - 32, y - 26, 96, 58
    @saved = switch[:state] == :taken
    @indices = [1, 2, 3]
    set_animation 1 if @saved
  end
  def update(section)
    if not @saved and SB.player.bomb.collide? self
      section.save_check_point @id, self
      @saved = true
    end
    if @saved
      animate @indices, 8
    end
  end
end
class Pin < TwoStateObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_Pin, Vector.new(0, 0), 5, 1,
      60, 0, 3, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4], (not args.nil?)
    @active_bounds = Rectangle.new x, y, 32, 32
    @obst = Block.new(x, y, 32, 32, true)
    section.obstacles << @obst if args
  end
  def s1_to_s2(section)
    section.obstacles << @obst
  end
  def s2_to_s1(section)
    section.obstacles.delete @obst
  end
  def is_visible(map)
    true
  end
end
class Spikes < TwoStateObject
  def initialize(x, y, args, section)
    @dir = args.to_i
    if @dir % 2 == 0
      x += 2; w = 28; h = 32
    else
      y += 2; w = 32; h = 28
    end
    super x, y, w, h, :sprite_Spikes, Vector.new(0, 0), 5, 1, 120, 0, 2, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4]
    @active_bounds = Rectangle.new x, y, 32, 32
    @obst = Block.new(x + 2, y + 2, 28, 28)
  end
  def s1_to_s2(section)
    if SB.player.bomb.collide? @obst
      SB.player.bomb.hit
    else
      section.obstacles << @obst
    end
  end
  def s2_to_s1(section)
    section.obstacles.delete @obst
  end
  def update(section)
    super section
    b = SB.player.bomb
    if @state2 and b.collide? self
      if (@dir == 0 and b.y + b.h <= @y + 2) or
         (@dir == 1 and b.x >= @x + @w - 2) or
         (@dir == 2 and b.y >= @y + @h - 2) or
         (@dir == 3 and b.x + b.w <= @x + 2)
        SB.player.bomb.hit
      end
    end
  end
  def draw(map)
    angle = case @dir
              when 0 then 0
              when 1 then 90
              when 2 then 180
              when 3 then 270
            end
    @img[@img_index].draw_rot @x + @w/2 - map.cam.x, @y + @h/2 - map.cam.y, 0, angle
  end
end
class FixedSpikes < GameObject
  def initialize(x, y, args, section)
    @dir = args.to_i
    if @dir % 2 == 0
      super x + 2, y, 28, 32, :sprite_Spikes, Vector.new(0, 0), 5, 1
    else
      super x, y + 2, 32, 28, :sprite_Spikes, Vector.new(0, 0), 5, 1
    end
    @active_bounds = Rectangle.new x, y, 32, 32
    section.obstacles << Block.new(x + 2, y + 2, 28, 28)
  end
  def update(section)
    b = SB.player.bomb
    if b.collide? self
      if (@dir == 0 and b.y + b.h <= @y + 2) or
         (@dir == 1 and b.x >= @x + @w - 2) or
         (@dir == 2 and b.y >= @y + @h - 2) or
         (@dir == 3 and b.x + b.w <= @x + 2)
        SB.player.bomb.hit
      end
    end
  end
  def draw(map)
    angle = case @dir
              when 0 then 0
              when 1 then 90
              when 2 then 180
              when 3 then 270
            end
    @img[4].draw_rot @x + @w/2 - map.cam.x, @y + @h/2 - map.cam.y, 0, angle
  end
end
class MovingWall < GameObject
  attr_reader :id
  def initialize(x, y, args, section)
    super x + 2, y + C::TILE_SIZE, 28, 0, :sprite_MovingWall, Vector.new(0, 0), 1, 2
    args = args.split ','
    @id = args[0].to_i
    @closed = args[1].nil?
    if @closed
      until section.obstacle_at? @x, @y - 1
        @y -= C::TILE_SIZE
        @h += C::TILE_SIZE
      end
    else
      @max_size = C::TILE_SIZE * args[1].to_i
    end
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.obstacles << self
  end
  def update(section)
    if @active
      @timer += 1
      if @timer == 30
        @y += @closed ? 16 : -16
        @h += @closed ? -16 : 16
        @active_bounds = Rectangle.new @x, @y, @w, @h
        @timer = 0
        if @closed and @h == 0
          @dead = true
        elsif not @closed and @h == @max_size
          @active = false
        end
      end
    end
  end
  def activate
    @active = true
    @timer = 0
  end
  def draw(map)
    @img[0].draw @x - map.cam.x, @y - map.cam.y, 0 if @h > 0
    y = 16
    while y < @h
      @img[1].draw @x - map.cam.x, @y + y - map.cam.y, 0
      y += 16
    end
  end
end
class Ball < GameObject
  def initialize(x, y, args, section, switch)
    super x, y, 32, 32, :sprite_Ball
    @set = switch[:state] == :taken
    @start_x = x
    @rotation = 0
    @active_bounds = Rectangle.new @x, @y, @w, @h
    section.passengers << self
  end
  def update(section)
    if @set
      if @rec.nil?
        @rec = section.get_next_ball_receptor
        @x = @active_bounds.x = @rec.x
        @y = @active_bounds.y = @rec.y - 31
      end
      @x += (0.1 * (@rec.x - @x)) if @x.round(2) != @rec.x
    else
      forces = Vector.new 0, 0
      if SB.player.bomb.collide? self
        if SB.player.bomb.x <= @x; forces.x = (SB.player.bomb.x + SB.player.bomb.w - @x) * 0.15
        else; forces.x = -(@x + @w - SB.player.bomb.x) * 0.15; end
      end
      if @bottom
        if @speed.x != 0
          forces.x -= 0.15 * @speed.x
        end
        SB.stage.switches.each do |s|
          if s[:type] == BallReceptor and bounds.intersect? s[:obj].bounds
            next if s[:obj].is_set
            s[:obj].set section
            s2 = SB.stage.find_switch self
            s2[:extra] = @rec = s[:obj]
            s2[:state] = :temp_taken
            @active_bounds.x = @rec.x
            @active_bounds.y = @rec.y - 31
            @set = true
            return
          end
        end
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
      @active_bounds = Rectangle.new @x, @y, @w, @h
      @rotation = 3 * (@x - @start_x)
    end
  end
  def draw(map)
    @img[0].draw_rot @x + (@w / 2) - map.cam.x, @y + (@h / 2) - map.cam.y, 0, @rotation
  end
end
class BallReceptor < GameObject
  attr_reader :id, :is_set
  def initialize(x, y, args, section, switch)
    super x, y + 31, 32, 1, :sprite_BallReceptor, Vector.new(0, -8), 1, 2
    @id = args.to_i
    @will_set = switch[:state] == :taken
    @active_bounds = Rectangle.new x, y + 23, 32, 13
  end
  def update(section)
    if @will_set
      section.activate_wall @id
      @is_set = true
      @img_index = 1
      @will_set = false
    end
  end
  def set(section)
    SB.stage.set_switch self
    section.activate_wall @id
    @is_set = true
    @img_index = 1
  end
end
class HideTile
  def initialize(i, j, group, tiles, num)
    @state = 0
    @alpha = 0xff
    @color = 0xffffffff
    @group = group
    @points = []
    check_tile i, j, tiles, 4
    @img = Res.imgs "sprite_ForeWall#{num}".to_sym, 5, 1
  end
  def check_tile(i, j, tiles, dir)
    return -1 if tiles[i].nil? or tiles[i][j].nil?
    return tiles[i][j].wall if tiles[i][j].hide < 0
    return 0 if tiles[i][j].hide == @group
    tiles[i][j].hide = @group
    t = 0; r = 0; b = 0; l = 0
    t = check_tile i, j-1, tiles, 0 if dir != 2
    r = check_tile i+1, j, tiles, 1 if dir != 3
    b = check_tile i, j+1, tiles, 2 if dir != 0
    l = check_tile i-1, j, tiles, 3 if dir != 1
    if t < 0 and r >= 0 and b >= 0 and l >= 0; img = 1
    elsif t >= 0 and r < 0 and b >= 0 and l >= 0; img = 2
    elsif t >= 0 and r >= 0 and b < 0 and l >= 0; img = 3
    elsif t >= 0 and r >= 0 and b >= 0 and l < 0; img = 4
    else; img = 0; end
    @points << {x: i * C::TILE_SIZE, y: j * C::TILE_SIZE, img: img}
    0
  end
  def update(section)
    will_show = false
    @points.each do |p|
      rect = Rectangle.new p[:x], p[:y], C::TILE_SIZE, C::TILE_SIZE
      if SB.player.bomb.bounds.intersect? rect
        will_show = true
        break
      end
    end
    if will_show; show
    else; hide; end
  end
  def show
    if @state != 2
      @alpha -= 17
      if @alpha == 51
        @state = 2
      else
        @state = 1
      end
      @color = 0x00ffffff | (@alpha << 24)
    end
  end
  def hide
    if @state != 0
      @alpha += 17
      if @alpha == 0xff
        @state = 0
      else
        @state = 1
      end
      @color = 0x00ffffff | (@alpha << 24)
    end
  end
  def is_visible(map)
    true
  end
  def draw(map)
    @points.each do |p|
      @img[p[:img]].draw p[:x] - map.cam.x, p[:y] - map.cam.y, 0, 1, 1, @color
    end
  end
end
class Projectile < GameObject
  attr_reader :owner
  def initialize(x, y, type, angle, owner)
    case type
    when 1 then w = 20; h = 12; x_g = -2; y_g = -2; cols = 3; rows = 1; indices = [0, 1, 0, 2]; @speed_m = 3
    when 2 then w = 8; h = 8; x_g = -2; y_g = -2; cols = 4; rows = 2; indices = [0, 1, 2, 3, 4, 5, 6, 7]; @speed_m = 2.5
    when 3 then w = 4; h = 40; x_g = 0; y_g = 0; cols = 1; rows = 1; indices = [0]; @speed_m = 6
    when 4 then w = 16; h = 22; x_g = -2; y_g = 0; cols = 1; rows = 1; indices = [0]; @speed_m = 5
    end
    super x - x_g, y - y_g, w, h, "sprite_Projectile#{type}", Vector.new(x_g, y_g), cols, rows
    rads = angle * Math::PI / 180
    @aim = Vector.new @x + (1000000 * Math.cos(rads)), @y + (1000000 * Math.sin(rads))
    @active_bounds = Rectangle.new @x + @img_gap.x, @y + @img_gap.y, @img[0].width, @img[0].height
    @angle = angle
    @owner = owner
    @indices = indices
  end
  def update(section)
    move_free @aim, @speed_m
    animate @indices, 5
    t = (@y + @img_gap.y).floor
    r = (@x + @img_gap.x + @img[0].width).ceil
    b = (@y + @img_gap.y + @img[0].height).ceil
    l = (@x + @img_gap.x).floor
    if t > section.size.y; @dead = true
    elsif r < 0; @dead = true
    elsif b < C::TOP_MARGIN; @dead = true
    elsif l > section.size.x; @dead = true
    end
  end
  def draw(map)
    @img[@img_index].draw_rot @x + (@w / 2) - map.cam.x, @y + (@h / 2) - map.cam.y, 0, @angle
  end
end
class Poison < GameObject
  def initialize(x, y, args, section)
    super x, y + 31, 32, 1, :sprite_poison, Vector.new(0, -19), 3, 1
    @active_bounds = Rectangle.new(x, y - 19, 32, 28)
  end
  def update(section)
    animate [0, 1, 2], 8
    if SB.player.bomb.collide? self
      SB.player.bomb.hit
    end
  end
end
class Vortex < GameObject
  def initialize(x, y, args, section)
    super x - 11, y - 11, 54, 54, :sprite_vortex, Vector.new(-5, -5), 2, 2
    @active_bounds = Rectangle.new(@x, @y, @w, @h)
    @angle = 0
    @entrance = args.to_i
  end
  def update(section)
    animate [0, 1, 2, 3, 2, 1], 5
    @angle += 5
    @angle = 0 if @angle == 360
    b = SB.player.bomb
    if @transporting
      b.move_free @aim, 1.5
      @timer += 1
      if @timer == 32
        section.add_effect(Effect.new(@x - 3, @y - 3, :fx_transport, 2, 2, 7, [0, 1, 2, 3], 28))
      elsif @timer == 60
        section.warp = @entrance
        @transporting = false
        b.active = true
      end
    else
      if b.collide? self
        b.active = false
        @aim = Vector.new(@x + (@w - b.w) / 2, @y + (@h - b.h) / 2 + 3)
        @transporting = true
        @timer = 0
      end
    end
  end
  def draw(map)
    @img[@img_index].draw_rot @x + @w / 2 - map.cam.x, @y + @h/2 - map.cam.y, 0, @angle
  end
end
class AirMattress < GameObject
  def initialize(x, y, args, section)
    super x + 2, y + 16, 60, 1, :sprite_airMattress, Vector.new(-2, -2), 1, 3
    @active_bounds = Rectangle.new(x, y + 15, 64, 32)
    @color = (args || 'ffffff').to_i(16)
    @timer = 0
    @points = [
      Vector.new(@x, @y),
      Vector.new(@x, @y + 16)
    ]
    @speed_m = 0.16
    @passable = true
    @state = :normal
    section.obstacles << self
  end
  def update(section)
    b = SB.player.bomb
    if @state == :normal
      if b.bottom == self
        @state = :down
        @timer = 0
        set_animation 0
      else
        x = @timer + 0.5
        @speed_m = -0.0001875 * x**2 + 0.015 * x
        cycle @points, @speed_m, [b]
        @timer += 1
        if @timer == 80
          @timer = 0
        end
      end
    elsif @state == :down
      animate [0, 1, 2], 8 if @img_index != 2
      if b.bottom == self
        move_carrying Vector.new(@x, @y + 1), 0.3, [b], section.get_obstacles(b.x, b.y), section.ramps
      else
        @state = :up
        set_animation 2
      end
    elsif @state == :up
      animate [2, 1, 0], 8 if @img_index != 0
      move_carrying Vector.new(@x, @y - 1), 0.3, [b], section.get_obstacles(b.x, b.y), section.ramps
      if SB.player.bomb.bottom == self
        @state = :down
      elsif @y.round == @points[0].y
        @y = @points[0].y
        @state = :normal
      end
    end
  end
  def draw(map)
    super map, 1, 1, 255, @color
  end
end
class Water
  attr_reader :x, :y, :w, :h, :bounds
  def initialize(x, y, args, section)
    a = args.split ':'
    @x = x
    @y = y + 5
    @w = C::TILE_SIZE * a[0].to_i
    @h = C::TILE_SIZE * a[1].to_i - 5
    @bounds = Rectangle.new(@x, @y, @w, @h)
    section.add_interacting_element(self)
  end
  def update(section)
    b = SB.player.bomb
    if b.collide? self
      b.stored_forces.y -= 1
      unless SB.player.dead?
        SB.player.die
        section.add_effect(Effect.new(b.x + b.w / 2 - 32, @y - 19, :fx_water, 1, 4, 8))
      end
    end
  end
  def dead?
    false
  end
  def is_visible(map)
    map.cam.intersect? @bounds
  end
  def draw(map); end
end
class ForceField < GameObject
  def initialize(x, y, args, section, switch)
    return if switch[:state] == :taken
    super x, y, 32, 32, :sprite_ForceField, Vector.new(-14, -14), 3, 1
    @active_bounds = Rectangle.new(x - 14, y - 14, 60, 60)
    @alpha = 255
  end
  def update(section)
    animate [0, 1, 2, 1], 10
    b = SB.player.bomb
    if @taken
      @x = b.x + b.w / 2 - 16; @y = b.y + b.h / 2 - 16
      @timer += 1
      @dead = true if @timer == 1200
      if @timer >= 1080
        if @timer % 5 == 0
          @alpha = @alpha == 0 ? 255 : 0
        end
      end
    elsif b.collide? self
      b.set_invulnerable 1200
      SB.stage.set_switch self
      @taken = true
      @timer = 0
    end
  end
  def draw(map)
    super map, 1, 1, @alpha
  end
end
class Stalactite < GameObject
  def initialize(x, y, args, section)
    super x + 11, y - 16, 10, 48, :sprite_stalactite, Vector.new(-9, 0), 3, 2
    @active_bounds = Rectangle.new(x + 2, y, 28, 48)
    @normal = args.nil?
  end
  def update(section)
    if @dying
      animate [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 5], 5
      @timer += 1
      @dead = true if @timer == 60
    elsif @moving
      move Vector.new(0, 0), section.get_obstacles(@x, @y), section.ramps
      SB.player.bomb.hit if SB.player.bomb.collide?(self)
      obj = section.active_object
      if obj.is_a? Sahiss and obj.bounds.intersect?(self)
        obj.hit(section)
      end
      if @bottom
        @dying = true
        @moving = false
        @timer = 0
      end
    elsif @will_move
      if @timer % 4 == 0
        if @x % 2 == 0; @x += 1
        else; @x -= 1; end
      end
      @timer += 1
      @moving = true if @timer == 30
    else
      b = SB.player.bomb
      if (@normal && b.x + b.w > @x - 80 && b.x < @x + 90 && b.y > @y && b.y < @y + 256) ||
         (!@normal && b.x + b.w > @x && b.x < @x + @w && b.y + b.h > @y - C::TILE_SIZE && b.y + b.h < @y)
        @will_move = true
        @timer = 0
      end
    end
  end
end
class Board < GameObject
  def initialize(x, y, facing_right, section, switch)
    super x, y, 50, 4, :sprite_board, Vector.new(0, -1)
    @facing_right = facing_right
    @passable = true
    @active_bounds = Rectangle.new(x, y - 1, 50, 5)
    section.obstacles << self
    @switch = switch
  end
  def update(section)
    b = SB.player.bomb
    if b.collide? self and b.y + b.h <= @y + @h
      b.y = @y - b.h
    elsif b.bottom == self
      section.active_object = self
    elsif section.active_object == self
      section.active_object = nil
    end
  end
  def take(section)
    SB.player.add_item @switch
    @switch[:state] = :temp_taken
    section.obstacles.delete self
    section.active_object = nil
    @dead = true
  end
  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? nil : :horiz)
  end
end
class Rock < GameObject
  def initialize(x, y, args, section)
    case args
      when '1' then
        objs = [['l', 0, 0, 26, 96], [26, 0, 32, 96], [58, 27, 31, 69], ['r', 89, 27, 18, 35], [89, 62, 30, 34]]
        w = 120; h = 96; x -= 44; y -= 64
      else
        objs = []; w = h = 0
    end
    objs.each do |o|
      if o[0].is_a? String
        section.ramps << Ramp.new(x + o[1], y + o[2], o[3], o[4], o[0] == 'l')
      else
        section.obstacles << Block.new(x + o[0], y + o[1], o[2], o[3])
      end
    end
    super x, y, w, h, "sprite_rock#{args}", Vector.new(0, 0)
    @active_bounds = Rectangle.new(x, y, w, h)
  end
  def update(section); end
end
class Monep < GameObject
  def initialize(x, y, args, section, switch)
    super x, y, 62, 224, :sprite_monep, Vector.new(0, 0), 3, 2
    @active_bounds = Rectangle.new(x, y, 62, 224)
    @blocking = switch[:state] != :taken
    @state = :normal
    @balloon = Res.img :fx_Balloon3
  end
  def update(section)
    if @blocking
      b = SB.player.bomb
      if b.collide? self
        if @state == :normal
          section.set_fixed_camera(@x + @w / 2 - C::SCREEN_WIDTH / 2, @y + 50 - C::SCREEN_HEIGHT / 2)
          section.active_object = self
          set_animation 3
          @state = :speaking
          @timer = 0
        elsif @state == :speaking
          @timer += 1
          if @timer == 600 or KB.key_pressed? Gosu::KbReturn or KB.key_pressed? Gosu::KbUp
            section.unset_fixed_camera
            set_animation 0
            @state = :waiting
          end
        elsif b.x > @x + @w / 2 - b.w / 2
          b.x = @x + @w / 2 - b.w / 2
        end
      else
        if section.active_object == self
          section.active_object = nil
          @state = :normal
        end
      end
    end
    if @state == :speaking; animate [3, 4, 5, 4, 5, 3, 5], 10
    else; animate [0, 1, 0, 2], 10; end
  end
  def activate(section)
    @blocking = false
    @state = :normal
    section.active_object = nil
    SB.stage.set_switch(self)
  end
  def draw(map)
    super map
    @balloon.draw @x - map.cam.x, @y + 30 - map.cam.y, 0 if @state == :waiting
    speak(:msg_monep) if @state == :speaking
  end
end
class StalactiteGenerator < GameObject
  def initialize(x, y, args, section)
    super x, y, 96, 32, :sprite_stalacGen, Vector.new(0, 0)
    @active_bounds = Rectangle.new(@x, @y, @w, @h)
    @active = true
    @limit = args.to_i * C::TILE_SIZE
  end
  def update(section)
    if @active and SB.player.bomb.collide?(self)
      section.add(Stalactite.new(@x + 96 + rand(@limit), @y + C::TILE_SIZE, '!', section))
      @active = false
      @timer = 0
    elsif not @active
      @timer += 1
      if @timer == 60
        @active = true
      end
    end
  end
end
class SpecGate < GameObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_SpecGate
    @active_bounds = Rectangle.new(x, y, 32, 32)
  end
  def update(section)
    if SB.player.bomb.collide? self
      SB.prepare_special_world
    end
  end
end
class Enemy < GameObject
  def initialize(x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
    @indices = indices
    @interval = interval
    @score = score
    @hp = hp
    @control_timer = 0
    @active_bounds = Rectangle.new x + img_gap.x, y + img_gap.y, @img[0].width, @img[0].height
  end
  def set_active_bounds(section)
    t = (@y + @img_gap.y).floor
    r = (@x + @img_gap.x + @img[0].width).ceil
    b = (@y + @img_gap.y + @img[0].height).ceil
    l = (@x + @img_gap.x).floor
    if t > section.size.y
      @dead = true
    elsif r < 0; @dead = true
    elsif b < C::TOP_MARGIN; @dead = true
    elsif l > section.size.x; @dead = true
    else
      if t < @active_bounds.y
        @active_bounds.h += @active_bounds.y - t
        @active_bounds.y = t
      end
      @active_bounds.w = r - @active_bounds.x if r > @active_bounds.x + @active_bounds.w
      @active_bounds.h = b - @active_bounds.y if b > @active_bounds.y + @active_bounds.h
      if l < @active_bounds.x
        @active_bounds.w += @active_bounds.x - l
        @active_bounds.x = l
      end
    end
  end
  def update(section)
    if @dying
      @control_timer += 1
      @dead = true if @control_timer == 150
      return if @img_index == @indices[-1]
      animate @indices, @interval
      return
    end
    unless @invulnerable or SB.player.dead?
      b = SB.player.bomb
      if b.over? self
        b.speed.y = -C::BOUNCE_SPEED
        hit_by_bomb(section)
      elsif b.explode? self
        hit_by_explosion(section)
      elsif section.projectile_hit? self
        hit_by_projectile(section)
      elsif b.collide? self
        b.hit
      end
    end
    return if @dying
    if @invulnerable
      @control_timer += 1
      return_vulnerable if @control_timer == C::INVULNERABLE_TIME
    end
    yield if block_given?
    set_active_bounds section
    animate @indices, @interval
  end
  def hit_by_bomb(section)
    hit(section)
  end
  def hit_by_explosion(section)
    @hp = 1
    hit(section)
  end
  def hit_by_projectile(section)
    hit(section)
  end
  def hit(section)
    @hp -= 1
    if @hp == 0
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      @dying = true
    else
      get_invulnerable
    end
  end
  def get_invulnerable
    @invulnerable = true
  end
  def return_vulnerable
    @invulnerable = false
    @control_timer = 0
  end
end
class FloorEnemy < Enemy
  def initialize(x, y, args, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1, speed = 3)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp
    @dont_fall = args.nil?
    @speed_m = speed
    @forces = Vector.new -@speed_m, 0
    @facing_right = false
  end
  def update(section)
    if @invulnerable
      super section
    else
      super section do
        move @forces, section.get_obstacles(@x, @y, @w, @h), section.ramps
        @forces.x = 0
        if @left
          set_direction :right
        elsif @right
          set_direction :left
        elsif @dont_fall
          if @facing_right
            set_direction :left unless section.obstacle_at? @x + @w, @y + @h
          elsif not section.obstacle_at? @x - 1, @y + @h
            set_direction :right
          end
        end
      end
    end
  end
  def hit(section)
    super
    if @dying
      @indices = [2, 3, 4]
      set_animation 2
      @interval = 5
    end
  end
  def set_direction(dir)
    @speed.x = 0
    if dir == :left
      @forces.x = -@speed_m
      @facing_right = false
    else
      @forces.x = @speed_m
      @facing_right = true
    end
  end
  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end
class Wheeliam < FloorEnemy
  def initialize(x, y, args, section)
    super x, y, args, 32, 32, :sprite_Wheeliam, Vector.new(-4, -3), 5, 2, [0, 1], 8, 100
    @max_speed.y = 10
  end
end
class Sprinny < Enemy
  def initialize(x, y, args, section)
    super x + 3, y - 4, 26, 36, :sprite_Sprinny, Vector.new(-2, -5), 6, 1, [0], 5, 350
    @leaps = 1000
    @max_leaps = args.to_i
    @facing_right = true
  end
  def update(section)
    super section do
      forces = Vector.new 0, 0
      if @bottom
        @leaps += 1
        if @leaps > @max_leaps
          @leaps = 1
          if @facing_right
            @facing_right = false
            @indices = [0, 1, 2, 1]
            set_animation 0
          else
            @facing_right = true
            @indices = [3, 4, 5, 4]
            set_animation 3
          end
        end
        @speed.x = 0
        if @facing_right; forces.x = 4
        else; forces.x = -4; end
        forces.y = -11.5
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
    end
  end
end
class Fureel < FloorEnemy
  def initialize(x, y, args, section)
    super x - 4, y - 7, args, 40, 39, :sprite_Fureel, Vector.new(-10, 0), 5, 2, [0, 1], 8, 300, 2, 4
  end
  def get_invulnerable
    @invulnerable = true
    @indices = [2]
    set_animation 2
  end
  def return_vulnerable
    @invulnerable = false
    @timer = 0
    @indices = [0, 1]
    set_animation 0
  end
end
class Yaw < Enemy
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_Yaw, Vector.new(-4, -4), 8, 1, [0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 6, 7], 6, 500
    @moving_eye = false
    @eye_timer = 0
    @points = [
      Vector.new(x + 64, y),
      Vector.new(x + 96, y + 32),
      Vector.new(x + 96, y + 96),
      Vector.new(x + 64, y + 128),
      Vector.new(x, y + 128),
      Vector.new(x - 32, y + 96),
      Vector.new(x - 32, y + 32),
      Vector.new(x, y)
    ]
  end
  def update(section)
    super section do
      cycle @points, 3
    end
  end
  def hit_by_bomb(section)
    SB.player.bomb.hit
  end
end
class Ekips < GameObject
  def initialize(x, y, args, section)
    super x + 5, y - 10, 22, 25, :sprite_Ekips, Vector.new(-37, -8), 2, 3
    @act_timer = 0
    @active_bounds = Rectangle.new x - 32, y - 18, 96, 50
    @attack_bounds = Rectangle.new x - 32, y + 10, 96, 12
    @score = 240
  end
  def update(section)
    if SB.player.bomb.explode?(self) || section.projectile_hit?(self) && !@attacking
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      @dead = true
      return
    end
    if SB.player.bomb.over? self
      if @attacking
        SB.player.stage_score += @score
        section.add_score_effect(@x + @w / 2, @y, @score)
        @dead = true
        return
      else
        SB.player.bomb.hit
      end
    elsif @attacking and SB.player.bomb.bounds.intersect? @attack_bounds
      SB.player.bomb.hit
    elsif SB.player.bomb.collide? self
      SB.player.bomb.hit
    end
    @act_timer += 1
    if @preparing and @act_timer >= 60
      animate [2, 3, 4, 5], 5
      if @img_index == 5
        @attacking = true
        @preparing = false
        set_animation 5
        @act_timer = 0
      end
    elsif @attacking and @act_timer >= 150
      animate [4, 3, 2, 1, 0], 5
      if @img_index == 0
        @attacking = false
        set_animation 0
        @act_timer = 0
      end
    elsif @act_timer >= 150
      @preparing = true
      set_animation 1
      @act_timer = 0
    end
  end
end
class Faller < GameObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_Faller1, Vector.new(0, 0), 4, 1
    @range = args.to_i
    @start = Vector.new x, y
    @up = Vector.new x, y - @range * 32
    @active_bounds = Rectangle.new x, @up.y, 32, (@range + 1) * 32
    @passable = true
    section.obstacles << self
    @bottom = Block.new x, y + 20, 32, 12, false
    @bottom_img = Res.img :sprite_Faller2
    section.obstacles << @bottom
    @indices = [0, 1, 2, 3, 2, 1]
    @interval = 8
    @step = 0
    @act_timer = 0
    @score = 300
  end
  def update(section)
    b = SB.player.bomb
    if b.explode? self
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      section.obstacles.delete self
      section.obstacles.delete @bottom
      @dead = true
      return
    elsif b.bottom == @bottom
      b.hit
    elsif b.collide? self
      b.hit
    end
    animate @indices, @interval
    if @step == 0 or @step == 2
      @act_timer += 1
      if @act_timer >= 90
        @step += 1
        @act_timer = 0
      end
    elsif @step == 1
      move_carrying @up, 2, [b], section.get_obstacles(b.x, b.y), section.ramps
      @step += 1 if @speed.y == 0
    else
      diff = ((@start.y - @y) / 5).ceil
      move_carrying @start, diff, [b], section.get_obstacles(b.x, b.y), section.ramps
      @step = 0 if @speed.y == 0
    end
  end
  def draw(map)
    @img[@img_index].draw @x - map.cam.x, @y - map.cam.y, 0
    @bottom_img.draw @x - map.cam.x, @start.y + 15 - map.cam.y, 0
  end
end
class Turner < Enemy
  def initialize(x, y, args, section)
    super x + 2, y - 7, 60, 39, :sprite_Turner, Vector.new(-2, -25), 3, 2, [0, 1, 2, 1], 8, 300
    @harmful = true
    @passable = true
    @aim1 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim1.x - 3, @aim1.y and
      not section.obstacle_at? @aim1.x - 3, @aim1.y + 8 and
      section.obstacle_at? @aim1.x - 3, @y + @h
      @aim1.x -= C::TILE_SIZE
    end
    @aim2 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim2.x + 63, @aim2.y and
      not section.obstacle_at? @aim2.x + 63, @aim2.y + 8 and
      section.obstacle_at? @aim2.x + 63, @y + @h
      @aim2.x += C::TILE_SIZE
    end
    @obst = section.obstacles
  end
  def update(section)
    @harm_bounds = Rectangle.new @x, @y - 23, 60, 62
    super section do
      if @harmful
        SB.player.bomb.hit if SB.player.bomb.bounds.intersect? @harm_bounds
        move_free @aim1, 2
        if @speed.x == 0 and @speed.y == 0
          @harmful = false
          @indices = [3, 4, 5, 4]
          set_animation 3
          @obst << self
        end
      else
        b = SB.player.bomb
        move_carrying @aim2, 2, [b], section.get_obstacles(b.x, b.y), section.ramps
        if @speed.x == 0 and @speed.y == 0
          @harmful = true
          @indices = [0, 1, 2, 1]
          set_animation 0
          @obst.delete self
        end
      end
    end
  end
  def hit_by_bomb(section); end
  def hit_by_explosion
    SB.player.stage_score += @score
    @obst.delete self unless @harmful
    @dead = true
  end
end
class Chamal < Enemy
  X_OFFSET = 320
  MAX_MOVEMENT = 160
  def initialize(x, y, args, section)
    super x - 25, y - 74, 82, 106, :sprite_chamal, Vector.new(-16, -8), 3, 1, [0, 1, 0, 2], 7, 5000, 3
    @left_limit = @x - X_OFFSET
    @right_limit = @x + X_OFFSET
    @activation_x = @x + @w / 2 - C::SCREEN_WIDTH / 2
    @spawn_points = [
      Vector.new(@x + @w / 2 - 120, 0),
      Vector.new(@x + @w / 2, -20),
      Vector.new(@x + @w / 2 + 120, 0)
    ]
    @spawns = []
    @speed_m = 4
    @timer = 0
    @turn = 0
    @facing_right = false
    @state = :waiting
  end
  def update(section)
    if @state == :waiting
      if SB.player.bomb.x >= @activation_x
        section.set_fixed_camera(@x + @w / 2 - C::SCREEN_WIDTH / 2, @y + @h / 2 - C::SCREEN_HEIGHT / 2)
        @state = :speaking
      end
    elsif @state == :speaking
      @timer += 1
      if @timer >= 300 or KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
        section.unset_fixed_camera
        @state = :acting
        @timer = 119
      end
    else
      if @dying
        @timer += 1
        if @timer >= 300 or KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
          section.unset_fixed_camera
          section.finish
          @dead = true
        end
        return
      end
      super(section) do
        if @moving
          move_free @aim, @speed_m
          if @speed.x == 0 and @speed.y == 0
            @moving = false
            @timer = 0
          end
        else
          @timer += 1
          if @timer == 120
            x = rand @left_limit..@right_limit
            x = @x - MAX_MOVEMENT if @x - x > MAX_MOVEMENT
            x = @x + MAX_MOVEMENT if x - @x > MAX_MOVEMENT
            @aim = Vector.new x, @y
            if x < @x; @facing_right = false
            else; @facing_right = true; end
            @moving = true
            if @turn % 5 == 0 and @spawns.size < 4
              @spawn_points.each do |p|
                @spawns << Wheeliam.new(p.x, p.y, nil, section)
                section.add(@spawns[-1])
              end
              @respawned = true
            end
            @turn += 1
          end
        end
        spawns_dead = true
        @spawns.each do |s|
          if s.dead?; @spawns.delete s
          else; spawns_dead = false; end
        end
        if spawns_dead and @respawned and @gun_powder.nil?
          @gun_powder = GunPowder.new(@x, @y, nil, section, nil)
          section.add(@gun_powder)
          @respawned = false
        end
        @gun_powder = nil if @gun_powder && @gun_powder.dead?
      end
      if @dying
        set_animation 0
        section.set_fixed_camera(@x + @w / 2 - C::SCREEN_WIDTH / 2, @y + @h / 2 - C::SCREEN_HEIGHT / 2)
        @timer = 0
      end
    end
  end
  def hit_by_bomb(section); end
  def hit_by_explosion(section)
    hit(section)
    @moving = false
    @timer = -C::INVULNERABLE_TIME
  end
  def get_invulnerable
    super
    @indices = [0]
    set_animation 0
  end
  def return_vulnerable
    super
    @indices = [0, 1, 0, 2]
    set_animation 0
  end
  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    if @state == :speaking or (@dying and not @dead)
      G.window.draw_quad 5, 495, C::PANEL_COLOR,
                         795, 495, C::PANEL_COLOR,
                         5, 595, C::PANEL_COLOR,
                         795, 595, C::PANEL_COLOR, 1
      SB.text_helper.write_breaking SB.text(@state == :speaking ? :chamal_speech : :chamal_death), 10, 500, 790, :justified, 0, 255, 1
    end
  end
end
class Electong < Enemy
  def initialize(x, y, args, section)
    super x - 12, y - 11, 56, 43, :sprite_electong, Vector.new(-4, -91), 4, 2, [0, 1, 2, 1], 7, 500, 1
    @timer = 0
    @tongue_y = @y
  end
  def hit_by_bomb(section)
    SB.player.bomb.hit
  end
  def update(section)
    super(section) do
      b = SB.player.bomb
      if @will_attack
        @tongue_y -= 91 / 14.0
        if @img_index == 5
          @indices = [5, 6, 7, 6]
          @attacking = true
          @will_attack = false
          @tongue_y = @y - 91
        end
      elsif @attacking
        @timer += 1
        if @timer == 150
          @indices = [4, 3, 0]
          set_animation 4
          @attacking = false
        end
      elsif @timer > 0
        @tongue_y += 91 / 14.0
        if @img_index == 0
          @indices = [0, 1, 2, 1]
          @timer = -30
          @tongue_y = @y
        end
      else
        @timer += 1 if @timer < 0
        if @timer == 0 and b.x + b.w > @x - 20 and b.x < @x + @w + 20
          @indices = [3, 4, 5]
          set_animation 3
          @will_attack = true
        end
      end
      if b.bounds.intersect? Rectangle.new(@x + 22, @tongue_y, 12, @y + @h - @tongue_y)
        b.hit
      end
    end
  end
end
class Chrazer < Enemy
  def initialize(x, y, args, section)
    super x + 1, y - 11, 30, 43, :sprite_chrazer, Vector.new(-21, -20), 2, 2, [0, 1, 0, 2], 7, 600, 2
    @facing_right = false
  end
  def update(section)
    super(section) do
      forces = Vector.new(0, 0)
      unless @invulnerable
        d = SB.player.bomb.x - @x
        d = 150 if d > 150
        d = -150 if d < -150
        if @bottom
          forces.x = d * 0.01666667
          forces.y = -12.5
          if d > 0 and not @facing_right
            @facing_right = true
          elsif d < 0 and @facing_right
            @facing_right = false
          end
          @speed.x = 0
        else
          forces.x = d * 0.001
        end
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
    end
  end
  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end
class Robort < FloorEnemy
  def initialize(x, y, args, section)
    super x - 12, y - 31, args, 56, 63, :sprite_robort, Vector.new(-14, -9), 3, 2, [0, 1, 2, 1], 6, 450, 3
  end
  def update(section)
    if @attacking
      @timer += 1
      set_direction @next_dir if @timer == 150
      animate @indices, @interval
      if SB.player.bomb.explode? self
        hit_by_explosion(section)
      elsif SB.player.bomb.collide? self
        SB.player.bomb.hit
      end
    else
      super(section)
    end
  end
  def set_direction(dir)
    if @attacking
      super(dir)
      @attacking = false
      @indices = [0, 1, 2, 1]
      @interval = 7
    else
      @speed.x = 0
      @next_dir = dir
      @attacking = true
      @indices = [3, 4, 5, 4]
      @interval = 4
      @timer = 0
    end
  end
end
class Shep < FloorEnemy
  def initialize(x, y, args, section)
    super x, y - 2, args, 42, 34, :sprite_shep, Vector.new(-5, 0), 3, 2, [0, 1, 0, 2], 7, 200, 1, 2
  end
  def update(section)
    if @attacking
      @timer += 1
      if @timer == 35
        section.add(Projectile.new(@facing_right ? @x + @w - 4 : @x - 4, @y + 10, 2, @facing_right ? 0 : 180, self))
        set_direction @next_dir
      end
      animate @indices, @interval
      if SB.player.bomb.over? self
        hit_by_bomb(section)
        SB.player.bomb.stored_forces.y -= C::BOUNCE_FORCE
      elsif SB.player.bomb.explode? self
        hit_by_explosion(section)
      elsif section.projectile_hit? self
        hit(section)
      elsif SB.player.bomb.collide? self
        SB.player.bomb.hit
      end
    else
      super(section)
    end
  end
  def set_direction(dir)
    if @attacking
      super(dir)
      @attacking = false
      @indices = [0, 1, 0, 2]
    else
      @speed.x = 0
      @next_dir = dir
      @attacking = true
      @indices = [0, 3, 4, 5, 5]
      @timer = 0
    end
    set_animation @indices[0]
  end
end
class Flep < Enemy
  def initialize(x, y, args, section)
    super x, y, 64, 20, :sprite_flep, Vector.new(0, 0), 1, 3, [0, 1, 2], 6, 300, 2
    @movement = C::TILE_SIZE * args.to_i
    @aim = Vector.new(@x - @movement, @y)
    @facing_right = false
  end
  def update(section)
    super(section) do
      move_free @aim, 4
      if @speed.x == 0 and @speed.y == 0
        @aim = Vector.new(@x + (@facing_right ? -@movement : @movement), @y)
        @facing_right = !@facing_right
      end
    end
  end
  def draw(map)
    super map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil
  end
end
class Jellep < Enemy
  def initialize(x, y, args, section)
    super x, section.size.y - 1, 32, 110, :sprite_jellep, Vector.new(-5, 0), 3, 1, [0, 1, 0, 2], 5, 500
    @max_y = y
    @state = 0
    @timer = 0
    @active_bounds.y = y
    @water = true
  end
  def update(section)
    super(section) do
      if @state == 0
        @timer += 1
        if @timer == 120
          @stored_forces.y = -14
          @state = 1
          @timer = 0
        end
      else
        force = @y - @max_y <= 100 ? 0 : -G.gravity.y
        move Vector.new(0, force), [], []
        if @state == 1 and @speed.y >= 0
          @state = 2
        elsif @state == 2 and @y >= section.size.y
          @speed.y = 0
          @y = section.size.y - 1
          @state = 0
        end
        @prev_water = @water
        @water = section.element_at(Water, @x, @y)
        if @water && !@prev_water || @prev_water && !@water
          section.add_effect(Effect.new(@x - 16, (@water || @prev_water).y - 19, :fx_water, 1, 4, 8))
        end
      end
    end
  end
  def hit_by_bomb(section)
    SB.player.bomb.hit
  end
  def draw(map)
    super map, 1, 1, 255, 0xffffff, nil, @state == 2 ? :vert : nil
  end
end
class Snep < Enemy
  def initialize(x, y, args, section)
    super x, y - 24, 32, 56, :sprite_snep, Vector.new(0, 4), 5, 2, [0, 1, 0, 2], 12, 200
    @facing_right = args.nil?
  end
  def update(section)
    super(section) do
      b = SB.player.bomb
      if b.y + b.h > @y && b.y + b.h <= @y + @h &&
         (@facing_right && b.x > @x && b.x < @x + @w + 16 || !@facing_right && b.x < @x && b.x + b.w > @x - 16)
        if @attacking
          @hurting = true if @img_index == 8
          b.hit if @hurting
        else
          @attacking = true
          @indices = [6, 7, 8, 7, 6, 0]
          @interval = 4
          set_animation 6
        end
      end
      if @attacking && @img_index == 0
        @attacking = @hurting = false
        @indices = [0, 1, 0, 2]
        @interval = 12
        set_animation 0
      end
    end
  end
  def hit_by_bomb(section)
    SB.player.bomb.hit
    @attacking = true
    @indices = [3, 4, 5, 4, 3, 0]
    @interval = 4
    set_animation 3
  end
  def hit(section)
    super
    if @dying
      @indices = [9]
      set_animation 9
    end
  end
  def draw(map)
    super map, 1, 1, 255, 0xffffff, nil, @facing_right ? nil : :horiz
  end
end
class Vamep < Enemy
  def initialize(x, y, args, section)
    super x, y, 29, 22, :sprite_vamep, Vector.new(-24, -18), 2, 2, [0, 1, 2, 3, 2, 1], 6, 300
    @angle = 0
    if args
      args = args.split ','
      @radius = args[0].to_i
      @speed = (args[1] || '3').to_i
    else
      @radius = 32
      @speed = 3
    end
    @start_x = x
    @start_y = y
  end
  def update(section)
    super(section) do
      radians = @angle * Math::PI / 180
      @x = @start_x + Math.cos(radians) * @radius
      @y = @start_y + Math.sin(radians) * @radius
      @angle += @speed
      @angle %= 360 if @angle >= 360
    end
  end
end
class Armep < FloorEnemy
  def initialize(x, y, args, section)
    super(x, y + 12, args, 41, 20, :sprite_armep, Vector.new(-21, -3), 1, 5, [0, 1, 0, 2], 8, 290, 1, 1.3)
  end
  def hit_by_bomb(section)
    SB.player.bomb.hit
  end
  def hit_by_projectile(section); end
end
class Owlep < Enemy
  def initialize(x, y, args, section)
    super x - 3, y - 34, 38, 55, :sprite_owlep, Vector.new(-3, 0), 4, 1, [0, 0, 1, 0, 0, 0, 2], 60, 250, 2
  end
  def update(section)
    super(section) do
      b = SB.player.bomb
      if !@attacking && b.x + b.w > @x && b.x < @x + @w && b.y > @y + @h && b.y < @y + C::SCREEN_HEIGHT
        section.add(Projectile.new(@x + 10, @y + 10, 3, 270, self))
        section.add(Projectile.new(@x + 20, @y + 10, 3, 270, self))
        @indices = [0]
        set_animation 0
        @attacking = true
        @timer = 0
      elsif @attacking
        @timer += 1
        if @timer == 120
          @indices = [0, 0, 1, 0, 0, 0, 2]
          set_animation 0
          @attacking = false
        end
      end
    end
  end
  def hit(section)
    super
    if @dying
      @indices = [3]
      set_animation 3
    end
  end
end
class Zep < Enemy
  def initialize(x, y, args, section)
    super x, y - 18, 60, 50, :sprite_zep, Vector.new(-24, -30), 2, 3, [0, 1, 2, 3, 4], 5, 500, 3
    @passable = true
    @aim1 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim1.x - 3, @aim1.y and
        not section.obstacle_at? @aim1.x - 3, @aim1.y + 20
      @aim1.x -= C::TILE_SIZE
    end
    @aim2 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim2.x + 65, @aim2.y and
        not section.obstacle_at? @aim2.x + 65, @aim2.y + 20
      @aim2.x += C::TILE_SIZE
    end
    @aim2.x += 4
    @aim = @aim1
    section.obstacles << self
  end
  def update(section)
    super section do
      b = SB.player.bomb
      move_carrying @aim, 4, [b], section.get_obstacles(b.x, b.y), section.ramps
      if @speed.x == 0 and @speed.y == 0
        @aim = @aim == @aim1 ? @aim2 : @aim1
        @img_gap.x = @aim == @aim2 ? -16 : -24
      end
    end
  end
  def hit_by_bomb(section); end
  def hit(section)
    super
    if @dying
      section.obstacles.delete self
      @indices = [5]
      set_animation 5
    end
  end
  def draw(map)
    super map, 1, 1, 255, 0xffffff, nil, @aim == @aim1 ? nil : :horiz
  end
end
class Sahiss < FloorEnemy
  def initialize(x, y, args, section)
    super x - 54, y - 148, args, 148, 180, :sprite_sahiss, Vector.new(-139, -3), 2, 3, [0, 1, 0, 2], 7, 2000, 3
    @timer = 0
    @time = 180 + rand(240)
    section.active_object = self
  end
  def update(section)
    if @attacking
      move_free @aim, 6
      b = SB.player.bomb
      if b.over? self
        b.stored_forces.y -= C::BOUNCE_FORCE
      elsif b.collide? self
        b.hit
      elsif @img_index == 5
        r = Rectangle.new(@x + 170, @y, 1, 120)
        b.hit if b.bounds.intersect? r
      end
      if @speed.x == 0
        if @img_index == 5
          set_bounds 3
          @img_index = 4
        end
        @timer += 1
        if @timer == 5
          set_bounds 4
          @img_index = 0
        elsif @timer == 60
          @img_index = 0
          @stored_forces.x = -3
          @attacking = false
          @timer = 0
          @time = 180 + rand(240)
        end
      elsif @img_index == 4
        @timer += 1
        if @timer == 5
          set_bounds 2
          @img_index = 5
          @timer = 0
        end
      end
    else
      prev = @facing_right
      super(section)
      if @dead
        section.finish
      elsif @aim
        @timer += 1
        if @timer == @time
          if @facing_right
            @timer = @time - 1
          else
            set_bounds 1
            @attacking = true
            @img_index = 4
            @timer = 0
          end
        end
      elsif @facing_right and not prev
        @aim = Vector.new(@x, @y)
      end
    end
  end
  def set_bounds(step)
    @x += case step; when 1 then -55; when 2 then -74; else 0; end
    @y += case step; when 1 then 16; when 2 then 60; when 3 then -60; else -16; end
    @aim.y += case step; when 1 then 16; when 2 then 60; when 3 then -60; else -16; end
    @w = case step; when 1 then 137; when 2 then 170; when 3 then 137; else 148; end
    @h = case step; when 1 then 164; when 2 then 70; when 3 then 164; else 180; end
    @img_gap.x = case step; when 1 then -84; when 2 then -10; when 3 then -84; else -139; end
    @img_gap.y = case step; when 1 then -19; when 2 then -64; when 3 then -19; else -3; end
  end
  def hit_by_bomb(section); end
  def hit_by_projectile(section); end
  def hit(section)
    unless @invulnerable
      super
      if @img_index == 5
        set_bounds 3; set_bounds 4
      elsif @img_index == 4
        set_bounds 4
      end
      @indices = [3]
      set_animation 3
      @attacking = false
      @timer = 0
      @time = 180 + rand(240)
    end
  end
  def return_vulnerable
    super
    @indices = [0, 1, 0, 2]
    set_animation 0
  end
end
module FormElement
  attr_reader :x, :y, :start_x, :start_y, :initialized
  def init_movement
    @start_x = @x
    @start_y = @y
    @initialized = true
  end
  def move_to(x, y)
    @aim_x = x
    @aim_y = y
  end
  def update_movement
    if @aim_x
      dist_x = @aim_x - @x
      dist_y = @aim_y - @y
      if dist_x.round == 0 and dist_y.round == 0
        @x = @aim_x
        @y = @aim_y
        @aim_x = @aim_y = nil
      else
        set_position(@x + dist_x / 5.0, @y + dist_y / 5.0)
      end
    end
  end
end
class MenuElement
  include FormElement
  def update; end
  def set_position(x, y)
    @x = x; @y = y
  end
end
class MenuText < MenuElement
  attr_reader :text_id
  attr_writer :text
  def initialize(text_id, x, y, width = 760, mode = :justified, big = false)
    @text_id = text_id
    @text = SB.text(text_id).gsub("\\n", "\n")
    @x = x
    @y = y
    @width = width
    @mode = mode
    @big = big
  end
  def draw
    helper = @big ? SB.big_text_helper : SB.text_helper
    helper.write_breaking(@text, @x, @y, @width, @mode)
  end
end
class MenuNumber < MenuElement
  attr_accessor :num
  def initialize(num, x, y, mode, color = 0)
    @num = num
    @x = x
    @y = y
    @mode = mode
    @color = color
  end
  def draw
    SB.text_helper.write_line(@num.to_s, @x, @y, @mode, @color)
  end
end
class MenuButton < Button
  include FormElement
  attr_reader :back, :text_id
  def initialize(y, text_id, back = false, x = 314, &action)
    super(x, y, SB.font, SB.text(text_id), :ui_button1, 0, 0x808080, 0, 0, true, false, 0, 7, 0, 0, 0, &action)
    @text_id = text_id
    @back = back
    @sound = Res.sound(back ? :btn2 : :btn1)
  end
  def click
    @action.call @params
    SB.play_sound @sound
  end
end
class MenuArrowButton < Button
  include FormElement
  def initialize(x, y, type, &action)
    super(x, y, nil, nil, "ui_button#{type}", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, &action)
    @sound = Res.sound :btn3
  end
  def click
    @action.call @params
    SB.play_sound @sound
  end
end
class MenuTextField < TextField
  include FormElement
  def initialize(y, x = 314)
    super x: x, y: y, font: SB.font, img: :ui_textField, margin_x: 10, margin_y: 8, locale: (SB.lang == :portuguese ? 'pt-br' : 'en-us')
  end
end
class FormSection
  attr_reader :cur_btn, :changing
  def initialize(components, visible = false)
    @components = components
    @buttons = []
    @components.each do |c|
      if c.is_a? Button or c.is_a? TextField
        @buttons << c
        @back_btn = c if c.respond_to?(:back) && c.back
      end
      unless c.initialized
        c.init_movement
        c.set_position(c.x - C::SCREEN_WIDTH, c.y) unless visible
      end
    end
    @visible = visible
    @changing = nil
    @cur_btn = @buttons[@cur_btn_index = 0]
    @cur_btn.focus if @cur_btn.respond_to? :focus
  end
  def update(mouse_moved)
    if @changing
      @components.each do |c|
        if c.update_movement.nil?
          @visible = false if @changing == 0
          @changing = nil
        end
      end
    elsif @visible
      @components.each { |c| c.update }
      @buttons.each_with_index do |b, i|
        next unless b.is_a? Button
        if b.state == :down || mouse_moved && b.state == :over
          @cur_btn_index = i
          break
        end
      end
      if KB.key_pressed? Gosu::KbDown or (KB.key_pressed? Gosu::KbRight and @cur_btn.is_a? Button)
        @cur_btn_index += 1
        @cur_btn_index = 0 if @cur_btn_index == @buttons.length
        @cur_btn.unfocus if @cur_btn.respond_to? :unfocus
      elsif KB.key_pressed? Gosu::KbUp or (KB.key_pressed? Gosu::KbLeft and @cur_btn.is_a? Button)
        @cur_btn_index -= 1
        @cur_btn_index = @buttons.length - 1 if @cur_btn_index < 0
        @cur_btn.unfocus if @cur_btn.respond_to? :unfocus
      elsif KB.key_pressed? Gosu::KbReturn or (KB.key_pressed? Gosu::KbSpace and @cur_btn.is_a? Button)
        @cur_btn.click if @cur_btn.respond_to? :click
      elsif @back_btn && (KB.key_pressed?(Gosu::KbEscape) || (KB.key_pressed?(Gosu::KbBackspace) && !@cur_btn.is_a?(TextField)))
        @back_btn.click
      end
      @cur_btn = @buttons[@cur_btn_index]
      @cur_btn.focus if @cur_btn.respond_to? :focus
    end
  end
  def show
    @visible = true
    @changing = 1
    @components.each { |c| c.move_to(c.start_x, c.y) }
  end
  def hide
    @changing = 0
    @components.each { |c| c.move_to(c.x - C::SCREEN_WIDTH, c.y) }
  end
  def clear
    @components.clear
    @buttons.clear
    @cur_btn = nil
  end
  def reset
    @cur_btn = @buttons[@cur_btn_index = 0]
  end
  def update_lang
    @components.each do |c|
      c.text = SB.text(c.text_id).gsub("\\n", "\n") if c.respond_to? :text_id
      c.locale = (SB.lang == :portuguese ? 'pt-br' : 'en-us') if c.respond_to? :locale=
    end
  end
  def add(component)
    @components << component
    if component.is_a? Button
      @buttons << component
      @cur_btn = @buttons[@cur_btn_index = 0] if @cur_btn.nil?
      @back_btn = component if component.respond_to?(:back) && component.back
    end
    component.init_movement
    component.set_position(component.x - C::SCREEN_WIDTH, component.y) unless @visible
  end
  def draw
    @components.each { |c| c.draw } if @visible
  end
end
class Form
  attr_reader :cur_section_index
  def initialize(*section_components)
    @sections = [FormSection.new(section_components.shift, true)]
    section_components.each do |c|
      @sections << FormSection.new(c)
    end
    @highlight_alpha = 102
    @highlight_state = 0
    @cur_section = @sections[@cur_section_index = 0]
  end
  def update
    mouse_moved = Mouse.x != @mouse_prev_x || Mouse.y != @mouse_prev_y
    @mouse_prev_x = Mouse.x
    @mouse_prev_y = Mouse.y
    @sections.each { |s| s.update(mouse_moved) }
    update_highlight unless @cur_section.changing
  end
  def update_highlight
    if @highlight_state == 0
      @highlight_alpha += 3
      @highlight_state = 1 if @highlight_alpha == 255
    else
      @highlight_alpha -= 3
      @highlight_state = 0 if @highlight_alpha == 102
    end
  end
  def go_to_section(index)
    @cur_section.hide
    @cur_section = @sections[@cur_section_index = index]
    @cur_section.show
  end
  def section(index)
    @sections[index]
  end
  def reset
    @sections.each { |s| s.reset }
    go_to_section 0
  end
  def update_lang
    @sections.each { |s| s.update_lang }
  end
  def draw
    @sections.each { |s| s.draw }
    draw_highlight unless @cur_section.changing
  end
  def draw_highlight
    btn = @cur_section.cur_btn
    x = btn.x; y = btn.y; w = btn.w; h = btn.h
    (1..4).each do |n|
      color = ((@highlight_alpha * (1 - (n-1) * 0.25)).round) << 24 | 0xffff00
      G.window.draw_line x - n, y - n + 1, color, x + w + n - 1, y - n + 1, color
      G.window.draw_line x - n, y + h + n, color, x + w + n, y + h + n, color
      G.window.draw_line x - n + 1, y - n + 1, color, x - n + 1, y + h + n - 1, color
      G.window.draw_line x + w + n, y - n, color, x + w + n - 1, y + h + n - 1, color
    end
  end
end
module Item
  attr_reader :icon
  def check(switch)
    if switch[:state] == :taken
      SB.player.add_item switch
      switch[:obj] = self
      return true
    elsif switch[:state] == :used
      return true
    end
    false
  end
  def set_icon(type)
    @icon = Res.img "icon_#{type}"
  end
  def take(section, store)
    info = SB.stage.find_switch self
    if store
      SB.player.add_item info
      info[:state] = :temp_taken
    else
      use section, info
      info[:state] = :temp_taken_used
    end
  end
  def set_switch(switch)
    if switch[:state] == :temp_taken
      switch[:state] = :temp_taken_used
    else
      switch[:state] = :temp_used
    end
  end
end
class FloatingItem < GameObject
  def initialize(x, y, w, h, img, img_gap = nil, sprite_cols = nil, sprite_rows = nil, indices = nil, interval = nil, type = nil)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
    img_gap = Vector.new(0, 0) if img_gap.nil?
    @active_bounds = Rectangle.new x + img_gap.x, y + img_gap.y, @img[0].width, @img[0].height
    @state = 3
    @counter = 0
    @indices = indices
    @interval = interval
    @type = type
  end
  def update(section)
    if SB.player.bomb.collide?(self) and (@type.nil? or SB.player.bomb.type == @type)
      yield
      @dead = true
      return
    end
    @counter += 1
    if @counter == 10
      if @state == 0 or @state == 1; @y -= 1
      else; @y += 1; end
      @state += 1
      @state = 0 if @state == 4
      @counter = 0
    end
    animate @indices, @interval if @indices
  end
end
class FireRock < FloatingItem
  def initialize(x, y, args, section)
    super x + 6, y + 7, 20, 20, :sprite_FireRock, Vector.new(-2, -17), 4, 1, [0, 1, 2, 3], 5
  end
  def update(section)
    super(section) do
      SB.player.stage_score += 10
    end
  end
end
class Life < FloatingItem
  include Item
  def initialize(x, y, args, section, switch)
    return if check switch
    super x + 2, y + 2, 28, 28, :sprite_Life, nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
  end
  def update(section)
    super(section) do
      take section, false
    end
  end
  def use(section, switch)
    SB.player.lives += 1
    set_switch(switch)
    true
  end
end
class Key < FloatingItem
  include Item
  def initialize(x, y, args, section, switch)
    set_icon :Key
    return if check switch
    super x + 3, y + 3, 26, 26, :sprite_Key, Vector.new(-3, -3)
  end
  def update(section)
    super(section) do
      take section, true
    end
  end
  def use(section, switch)
    obj = section.active_object
    if obj.is_a? Door and obj.locked
      obj.unlock(section)
      set_switch(switch)
    end
  end
end
class Attack1 < FloatingItem
  include Item
  def initialize(x, y, args, section, switch)
    set_icon :Attack1
    if check switch
      @type = :azul
      return
    end
    super x + 2, y + 2, 28, 28, :sprite_Attack1, nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, :azul
  end
  def update(section)
    super(section) do
      take section, true
    end
  end
  def use(section, switch)
    b = SB.player.bomb
    return false if b.type != @type
    if b.facing_right; angle = 0
    else; angle = 180; end
    section.add Projectile.new(b.x, b.y, 1, angle, b)
    set_switch(switch)
    true
  end
end
class Heart < FloatingItem
  def initialize(x, y, args, section)
    args = (args || '1').to_i
    bomb = case args
           when 1 then :vermelha
           when 2 then :verde
           when 3 then :branca
           end
    super x + 2, y + 2, 28, 28, "sprite_heart#{args}", nil, 8, 1,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, bomb
  end
  def update(section)
    super(section) do
      SB.player.bomb.hp += 1
    end
  end
end
class BoardItem < FloatingItem
  include Item
  def initialize(x, y, args, section, switch)
    set_icon :board
    return if check switch
    super x + 6, y + 3, 20, 26, :sprite_boardItem, Vector.new(-6, -3)
    @item = true
  end
  def update(section)
    super(section) do
      take section, true
    end
  end
  def use(section, switch)
    b = SB.player.bomb
    @board = Board.new(b.x + (b.facing_right ? 0 : b.w - 50), b.y + b.h - 2, b.facing_right, section, switch)
    section.add(@board)
    switch[:state] = :normal
  end
end
class Hammer < FloatingItem
  include Item
  def initialize(x, y, args, section, switch)
    set_icon :hammer
    return if check(switch)
    super x + 7, y + 1, 18, 30, :sprite_hammer, Vector.new(-7, -1)
  end
  def update(section)
    super(section) do
      take section, true
    end
  end
  def use(section, switch)
    obj = section.active_object
    if obj.is_a? Board
      obj.take(section)
      set_switch(switch)
    end
  end
end
class Spring < GameObject
  include Item
  def initialize(x, y, args, section, switch)
    @switch = switch
    set_icon :spring
    return if check(switch)
    super x, y, 32, 32, :sprite_Spring, Vector.new(-2, -16), 3, 2
    @active_bounds = Rectangle.new x, y - 16, 32, 48
    @start_y = y
    @state = 0
    @timer = 0
    @indices = [0, 4, 4, 5, 0, 5, 0, 5, 0, 5]
    @passable = true
    @ready = false
  end
  def update(section)
    unless @ready
      section.obstacles << self
      @ready = true
    end
    if SB.player.bomb.bottom == self
      reset if @state == 4
      @timer += 1
      if @timer == 10
        case @state
          when 0 then @y += 8; @img_gap.y -= 8; SB.player.bomb.y += 8
          when 1 then @y += 6; @img_gap.y -= 6; SB.player.bomb.y += 6
          when 2 then @y += 4; @img_gap.y -= 4; SB.player.bomb.y += 4
        end
        @state += 1
        if @state == 4
          SB.player.bomb.stored_forces.y = -18
        else
          set_animation @state
        end
        @timer = 0
      end
    elsif SB.player.bomb.collide?(self) and KB.key_pressed?(Gosu::KbUp)
      take(section, true)
      @dead = true
      section.obstacles.delete self
    elsif @state > 0 and @state < 4
      reset
    end
    if @state == 4
      animate @indices, 7
      @timer += 1
      if @timer == 70
        reset
      elsif @timer == 7
        @y = @start_y
        @img_gap.y = -16
      end
    end
  end
  def reset
    set_animation 0
    @state = @timer = 0
    @y = @start_y
    @img_gap.y = -16
  end
  def use(section, switch)
    b = SB.player.bomb
    x = b.facing_right ? b.x + b.w : b.x - @w
    return false if section.obstacle_at?(x, b.y)
    switch[:state] = :normal
    spring = Spring.new(x, b.y, nil, section, @switch)
    switch[:obj] = spring
    section.add spring
  end
end
class Attack2 < FloatingItem
  include Item
  def initialize(x, y, args, section, switch)
    set_icon :attack2
    if check switch
      @type = :vermelha
      return
    end
    super x + 2, y + 2, 28, 28, :sprite_attack2, nil, 8, 1,
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6, :vermelha
  end
  def update(section)
    super(section) do
      take section, true
    end
  end
  def use(section, switch)
    b = SB.player.bomb
    return false if b.type != @type
    section.add Projectile.new(b.x, b.y, 4, 270, b)
    set_switch(switch)
    true
  end
end
class Herb < GameObject
  include Item
  def initialize(x, y, args, section, switch)
    set_icon :herb
    return if check(switch)
    super x, y - 4, 30, 36, :sprite_herb, Vector.new(-3, -4)
    @active_bounds = Rectangle.new(x - 3, y - 8, 36, 40)
  end
  def update(section)
    if SB.player.bomb.collide?(self)
      take(section, true)
      @dead = true
    end
  end
  def use(section, switch)
    obj = section.active_object
    if obj.is_a? Monep
      obj.activate(section)
      set_switch(switch)
    end
  end
end
class Spec < FloatingItem
  def initialize(x, y, args, section)
    return if SB.player.specs.index(SB.stage.id)
    super x - 1, y - 1, 34, 34, :sprite_Spec, Vector.new(-12, -12), 2, 2, [0,1,2,3], 5
  end
  def update(section)
    super(section) do
      SB.player.stage_score += 1000
      SB.set_spec_taken
    end
    if rand < 0.05
      x = @x + rand(@w) - 7
      y = @y + rand(@h) - 7
      section.add_effect(Effect.new(x, y, :fx_Glow1, 3, 2, 6, [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0], 66))
    end
  end
end
class MovieElement < GameObject
  attr_reader :finished
  def initialize(x, y, img, sprite_cols, sprite_rows, actions)
    super x.to_i, y.to_i, 0, 0, img, nil, sprite_cols.to_i, sprite_rows.to_i
    @actions = []
    actions.each do |a|
      d = a.split
      pos = d[1][0] == ':' ? nil : d[1].split(',')
      @actions << {
        delay: d[0].to_i,
        x: pos ? pos[0].to_i : nil,
        y: pos ? pos[1].to_i : nil,
        text: pos ? nil : SB.text(eval(d[1])).gsub("\\n", "\n"),
        indices: eval(d[2]),
        last_index: d[3].to_i,
        interval: d[4].to_i,
        duration: d[5].to_i
      }
    end
    @finished = @actions.length == 0
    @action_index = 0
    @timer = 0
  end
  def update
    return if @finished
    animate @cur_action[:indices], @cur_action[:interval] if @cur_action
    move_free @aim, @speed_m if @aim
    @timer += 16.666667
    if @cur_action && @timer >= @cur_action[:duration]
      set_animation @cur_action[:last_index]
      @cur_action = @aim = nil
      @action_index += 1
      @timer = 0
      @finished = @action_index == @actions.length
    elsif !@cur_action && @timer >= @actions[@action_index][:delay]
      a = @actions[@action_index]
      if a[:x]
        @aim = Vector.new(a[:x], a[:y])
        @speed_m = Math.sqrt((a[:x] - @x)**2 + (a[:y] - @y)**2) * 16.666667 / a[:duration]
      end
      set_animation a[:indices][0]
      @cur_action = a
      @timer = 0
    end
  end
  def draw(x_off, y_off)
    @img[@img_index].draw @x - x_off, @y - y_off, 0
    if @cur_action && @cur_action[:text]
      G.window.draw_quad 5, 495, C::PANEL_COLOR,
                         795, 495, C::PANEL_COLOR,
                         5, 595, C::PANEL_COLOR,
                         795, 595, C::PANEL_COLOR, 0
      SB.text_helper.write_breaking @cur_action[:text], 10, 495, 780, :justified
    end
  end
end
class MovieScene
  def initialize(file_name)
    @bg = Res.img "movie_#{file_name.split('/')[-1]}", false, false, '.jpg'
    f = File.open(file_name)
    es = f.read.split "\n\n"
    f.close
    movie = es[0].split("\n")
    cam_pos = movie[0].split(',')
    @cam_x = cam_pos[0].to_i
    @cam_y = cam_pos[1].to_i
    @cam_moves = []
    @texts = []
    movie[1..-1].each do |c|
      d = c.split
      if d[1][0] == ':'
        @texts << {
          delay: d[0].to_i,
          text: SB.text(eval(d[1])).gsub("\\n", "\n"),
          duration: d[2].to_i
        }
      else
        pos = d[1].split(',')
        @cam_moves << {
          delay: d[0].to_i,
          x: pos[0].to_i,
          y: pos[1].to_i,
          duration: d[2].to_i
        }
      end
    end
    @cam_timer = 0
    @text_timer = 0
    @elements = []
    es[1..-1].each do |e|
      lines = e.split("\n")
      d = lines[0].split(',')
      @elements << MovieElement.new(d[3], d[4], d[0], d[1], d[2], lines[1..-1])
    end
  end
  def update
    if @finished and @elements_finished
      @cam_timer += 1
      return :finish if @cam_timer == C::MOVIE_DELAY
    else
      unless @finished
        if @speed_x
          @cam_x += @speed_x
          @cam_y += @speed_y
        end
        
        unless @cam_moves.empty?
          @cam_timer += 16.666667
          if @cur_cam && @cam_timer >= @cur_cam[:duration]
            @cur_cam = @speed_x = nil
            @cam_timer = 0
            @cam_moves.shift
          elsif !@cur_cam && @cam_timer >= @cam_moves[0][:delay]
            a = @cam_moves[0]
            if a[:x]
              @speed_x = (a[:x] - @cam_x) * 16.666667 / a[:duration]
              @speed_y = (a[:y] - @cam_y) * 16.666667 / a[:duration]
            end
            @cur_cam = a
            @cam_timer = 0
          end
        end
        
        unless @texts.empty?
          @text_timer += 16.666667
          if @cur_text && @text_timer >= @cur_text[:duration]
            @cur_text = nil
            @text_timer = 0
            @texts.shift
          elsif !@cur_text && @text_timer >= @texts[0][:delay]
            @cur_text = @texts[0]
            @text_timer = 0
          end
        end
        @finished = @cam_moves.empty? && @texts.empty?
      end
      @elements_finished = true
      @elements.each_with_index { |e|
        e.update
        @elements_finished = false unless e.finished
      }
    end
  end
  def draw
    @bg.draw -@cam_x, -@cam_y, 0
    @elements.each { |e| e.draw(@cam_x, @cam_y) }
    if @cur_text
      G.window.draw_quad 5, 495, C::PANEL_COLOR,
                         795, 495, C::PANEL_COLOR,
                         5, 595, C::PANEL_COLOR,
                         795, 595, C::PANEL_COLOR, 0
      SB.text_helper.write_breaking @cur_text[:text], 10, 495, 780, :justified
    end
  end
end
class Movie
  def initialize(id)
    @id = id
    files = Dir["#{Res.prefix}movie/#{id}-*"].sort
    @scenes = []
    files.each do |f|
      @scenes << MovieScene.new(f)
    end
    @scene = 0
    @alpha = 0
    Gosu::Song.current_song.stop
  end
  def update
    if @changing
      @alpha += @changing == 0 ? 17 : -17
      if @alpha == 255
        @changing = 1
        @scene += 1
        finish if @scene == @scenes.length
      elsif @alpha == 0
        @changing = nil
      end
    else
      status = @scenes[@scene].update
      @changing = 0 if status == :finish or KB.key_pressed? Gosu::KbReturn or KB.key_pressed? Gosu::KbSpace
    end
  end
  def finish
    if @id == 's'; SB.open_special_world
    elsif @id == 0; SB.start_new_game
    else; SB.next_world; end
  end
  def draw
    @scenes[@scene].draw
    if @changing
      c = @alpha << 24
      G.window.draw_quad 0, 0, c,
                         C::SCREEN_WIDTH, 0, c,
                         0, C::SCREEN_HEIGHT, c,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, c, 0
    end
  end
end
class Options
  class << self
    def form=(form)
      @form = form
    end
    def set_temp
      @lang = SB.lang
      @sound_volume = SB.sound_volume
      @music_volume = SB.music_volume
    end
    def get_menu
      @menu = [
        MenuButton.new(550, :save, false, 219) {
          SB.save_options
          @form.go_to_section 0
        },
        MenuButton.new(550, :cancel, true, 409) {
          SB.lang = @lang
          SB.sound_volume = @s_v_text.num = @sound_volume
          SB.music_volume = @m_v_text.num = @music_volume
          @form.go_to_section 0
        },
        MenuText.new(:language, 20, 200),
        MenuText.new(:lang_name, 590, 200, 300, :center),
        MenuArrowButton.new(400, 192, 'Left') {
          SB.change_lang(-1)
        },
        MenuArrowButton.new(744, 192, 'Right') {
          SB.change_lang
        },
        MenuText.new(:sound_volume, 20, 300),
        (@s_v_text = MenuNumber.new(SB.sound_volume, 590, 300, :center)),
        MenuArrowButton.new(400, 292, 'Left') {
          SB.change_volume('sound', -1)
          @s_v_text.num = SB.sound_volume
        },
        MenuArrowButton.new(744, 292, 'Right') {
          SB.change_volume('sound')
          @s_v_text.num = SB.sound_volume
        },
        MenuText.new(:music_volume, 20, 400),
        (@m_v_text = MenuNumber.new(SB.music_volume, 590, 400, :center)),
        MenuArrowButton.new(400, 392, 'Left') {
          SB.change_volume('music', -1)
          @m_v_text.num = SB.music_volume
        },
        MenuArrowButton.new(744, 392, 'Right') {
          SB.change_volume('music')
          @m_v_text.num = SB.music_volume
        }
      ] if @menu.nil?
      @menu
    end
  end
end
class Player
  attr_reader :score, :items, :cur_item_type, :specs
  attr_accessor :name, :last_world, :last_stage, :lives, :stage_score
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
      self.score -= C::DEATH_PENALTY
      @dead = true
      @bomb.die
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
    if item[:obj].use section, item
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
  def get_bomb_hps
    s =  "#{@bombs[:azul].hp},"
    s += "#{@bombs[:vermelha].hp}," if @bombs[:vermelha]
    s += "#{@bombs[:amarela].hp},"  if @bombs[:amarela]
    s += "#{@bombs[:verde].hp},"    if @bombs[:verde]
    s += "#{@bombs[:branca].hp},"   if @bombs[:branca]
    s
  end
  def reset(loaded = false)
    @items.clear
    @cur_item_type = nil
    @item_index = 0
    @stage_score = 0
    @dead = false
    @bombs.each { |k, v| v.reset } unless loaded
  end
  def game_over
    self.score -= C::GAME_OVER_PENALTY
    @last_stage = 1
    @lives = 5
    @specs.delete_if { |s| s =~ /^#{@last_world}-/ }
    reset
  end
end
Tile = Struct.new :back, :fore, :pass, :wall, :hide, :broken
class ScoreEffect
  attr_reader :dead
  def initialize(x, y, score)
    @x = x
    @y = y
    @text = score
    @alpha = 0
    @timer = 0
  end
  def update
    if @timer < 15
      @alpha += 17
    elsif @timer > 135
      @alpha -= 17
      @dead = true if @alpha == 0
    end
    @y -= 0.5
    @timer += 1
  end
  def draw(map)
    SB.small_text_helper.write_line @text, @x - map.cam.x, @y - map.cam.y, :center, 0xffffff, @alpha, :border, 0, 1, @alpha
  end
end
class Section
  ELEMENT_TYPES = [
    AirMattress,
    Armep,
    Attack1,
    Attack2,
    Ball,
    BallReceptor,
    BoardItem,
    Bombie,
    Chamal,
    Chrazer,
    Crack,
    Door,
    Ekips,
    Electong,
    Elevator,
    Faller,
    FireRock,
    FixedSpikes,
    Flep,
    ForceField,
    Fureel,
    Goal,
    GunPowder,
    Hammer,
    Heart,
    Herb,
    Jellep,
    Key,
    Life,
    Monep,
    MovingWall,
    Owlep,
    Pin,
    Poison,
    Robort,
    Rock,
    Sahiss,
    SaveBombie,
    Shep,
    Snep,
    Spec,
    SpecGate,
    Spikes,
    Spring,
    Sprinny,
    Stalactite,
    StalactiteGenerator,
    Turner,
    Vamep,
    Vortex,
    Water,
    Wheeliam,
    Yaw,
    Zep
  ]
  attr_reader :reload, :tiles, :obstacles, :ramps, :passengers, :size, :default_entrance
  attr_accessor :entrance, :warp, :loaded, :active_object
  def initialize(file, entrances, switches, taken_switches, used_switches)
    parts = File.read(file).chomp.split('#', -1)
    set_map_tileset parts[0].split ','
    set_bgs parts[1].split ','
    set_elements parts[2].split(';'), entrances, switches, taken_switches, used_switches
    set_ramps parts[3].split ';'
    @passengers = [SB.player.bomb]
  end
  def set_map_tileset(s)
    t_x_count = s[0].to_i; t_y_count = s[1].to_i
    @tiles = Array.new(t_x_count) {
      Array.new(t_y_count) {
        Tile.new -1, -1, -1, -1, -1, false
      }
    }
    @border_exit = s[2].to_i
    @tileset_num = s[3].to_i
    @tileset = Res.tileset s[3]
    @bgm = Res.song "s#{s[4]}"
    @map = Map.new C::TILE_SIZE, C::TILE_SIZE, t_x_count, t_y_count
    @size = @map.get_absolute_size
  end
  def set_bgs(s)
    @bgs = []
    s.each do |bg|
      if File.exist?("#{Res.prefix}img/bg/#{bg}.png")
        @bgs << Res.img("bg_#{bg}", false, true)
      else
        @bgs << Res.img("bg_#{bg}", false, true, '.jpg')
      end
    end
  end
  def set_elements(s, entrances, switches, taken_switches, used_switches)
    x = 0; y = 0; s_index = switches.length
    @element_info = []
    @hide_tiles = []
    s.each do |e|
      if e[0] == '_'; x, y = set_spaces e[1..-1].to_i, x, y
      elsif e[3] == '*'; x, y = set_tiles e[4..-1].to_i, x, y, tile_type(e[0]), e[1, 2]
      else
        i = 0
        begin
          t = tile_type e[i]
          if t != :none
            set_tile x, y, t, e[i+1, 2]
          else
            if e[i] == '!'
              index = e[(i+1)..-1].to_i
              entrances[index] = {x: x * C::TILE_SIZE, y: y * C::TILE_SIZE, section: self, index: index}
              @default_entrance = index if e[-1] == '!'
            else
              t, a = element_type e[(i+1)..-1]
              if t != :none
                el = {x: x * C::TILE_SIZE, y: y * C::TILE_SIZE, type: t, args: a}
                if e[i] == '$'
                  if s_index == used_switches[0]
                    used_switches.shift
                    el[:state] = :used
                  elsif s_index == taken_switches[0]
                    taken_switches.shift
                    el[:state] = :taken
                  else
                    el[:state] = :normal
                  end
                  el[:section] = self
                  el[:index] = s_index
                  switches << el
                  s_index += 1
                else
                  @element_info << el
                end
              end
            end
            i += 1000
          end
          i += 3
        end until e[i].nil?
        x += 1
        begin y += 1; x = 0 end if x == @tiles.length
      end
    end
  end
  def tile_type(c)
    case c
      when 'b' then :back
      when 'f' then :fore
      when 'p' then :pass
      when 'w' then :wall
      when 'h' then :hide
      else :none
    end
  end
  def element_type(s)
    i = s.index ':'
    if i
      n = s[0..i].to_i
      args = s[(i+1)..-1]
    else
      n = s.to_i
      args = nil
    end
    type = ELEMENT_TYPES[n - 1]
    [type, args]
  end
  def set_spaces(amount, x, y)
    x += amount
    if x >= @tiles.length
      y += x / @tiles.length
      x %= @tiles.length
    end
    [x, y]
  end
  def set_tiles(amount, x, y, type, s)
    amount.times do
      set_tile x, y, type, s
      x += 1
      begin y += 1; x = 0 end if x == @tiles.length
    end
    [x, y]
  end
  def set_tile(x, y, type, s)
    @tiles[x][y].send "#{type}=", s.to_i
  end
  def set_ramps(s)
    @ramps = []
    s.each do |r|
      left = r[0] == 'l'
      a = r[1] == "'" ? 2 : 1
      w = r[a].to_i * C::TILE_SIZE
      h = r[a + 1].to_i * C::TILE_SIZE
      h -= 1 if r[1] == "'"
      coords = r.split(':')[1].split(',')
      x = coords[0].to_i * C::TILE_SIZE
      y = coords[1].to_i * C::TILE_SIZE
      @ramps << Ramp.new(x, y, w, h, left)
    end
  end
  def start(switches, bomb_x, bomb_y)
    @elements = []
    @inter_elements = []
    @obstacles = []
    @effects = []
    @locked_door = nil
    @reload = false
    @loaded = true
    @ball_receptors = []
    switches.each do |s|
      if s[:section] == self
        @elements << s[:obj]
      end
    end
    @element_info.each do |e|
      @elements << e[:type].new(e[:x], e[:y], e[:args], self)
    end
    index = 1
    @tiles.each_with_index do |v, i|
      v.each_with_index do |t, j|
        if t.hide == 0
          @hide_tiles << HideTile.new(i, j, index, @tiles, @tileset_num)
          index += 1
        elsif t.broken
          t.broken = false
        end
      end
    end
    @tile_timer = 0
    @tile_3_index = 0
    @tile_4_index = 0
    @margin = MiniGL::Vector.new((C::SCREEN_WIDTH - SB.player.bomb.w) / 2, (C::SCREEN_HEIGHT - SB.player.bomb.h) / 2)
    do_warp bomb_x, bomb_y
    SB.play_song @bgm
  end
  def do_warp(x, y)
    SB.player.bomb.do_warp x, y
    @map.set_camera SB.player.bomb.x - @margin.x, SB.player.bomb.y - @margin.y
    @warp = nil
  end
  def get_obstacles(x, y, w = 0, h = 0)
    obstacles = []
    if x > @size.x - 4 * C::TILE_SIZE and @border_exit != 1
      obstacles << Block.new(@size.x, 0, 1, @size.y, false)
    end
    if x < 4 * C::TILE_SIZE and @border_exit != 3
      obstacles << Block.new(-1, 0, 1, @size.y, false)
    end
    offset_x = offset_y = 2
    if w > 0
      x += w / 2
      offset_x = w / 64 + 2
    end
    if h > 0
      y += h / 2
      offset_y = h / 64 + 2
    end
    i = (x / C::TILE_SIZE).round
    j = (y / C::TILE_SIZE).round
    ((i-offset_x)..(i+offset_x)).each do |k|
      ((j-offset_y)..(j+offset_y)).each do |l|
        if @tiles[k] and @tiles[k][l]
          if @tiles[k][l].pass >= 0
            obstacles << Block.new(k * C::TILE_SIZE, l * C::TILE_SIZE, C::TILE_SIZE, C::TILE_SIZE, true)
          elsif not @tiles[k][l].broken and @tiles[k][l].wall >= 0
            obstacles << Block.new(k * C::TILE_SIZE, l * C::TILE_SIZE, C::TILE_SIZE, C::TILE_SIZE, false)
          end
        end
      end
    end
    @obstacles.each do |o|
      obstacles << o
    end
    obstacles
  end
  def obstacle_at?(x, y)
    i = x / C::TILE_SIZE
    j = y / C::TILE_SIZE
    @tiles[i] and @tiles[i][j] and (@tiles[i][j].pass >= 0 or @tiles[i][j].wall >= 0) and not @tiles[i][j].broken
  end
  def add_interacting_element(el)
    @inter_elements << el
  end
  def element_at(type, x, y)
    @inter_elements.each do |e|
      if e.is_a? type and x >= e.x and x <= e.x + e.w and y >= e.y and y <= e.y + e.h
        return e
      end
    end
    nil
  end
  def get_next_ball_receptor
    SB.stage.switches.each do |s|
      if s[:section] == self && s[:type] == BallReceptor && s[:state] == :taken && !@ball_receptors.include?(s[:index])
        @ball_receptors << s[:index]
        return s[:obj]
      end
    end
    nil
  end
  def projectile_hit?(obj)
    @elements.each do |e|
      if e.is_a? Projectile
        if e.owner != obj && e.bounds.intersect?(obj.bounds)
          @elements.delete e
          return true
        end
      end
    end
    false
  end
  def add(element)
    @elements << element
  end
  def add_effect(e)
    @effects << e
  end
  def add_score_effect(x, y, score)
    add_effect ScoreEffect.new(x, y, score)
  end
  def save_check_point(id, obj)
    @entrance = id
    SB.stage.set_switch obj
    SB.stage.save_switches
  end
  def activate_wall(id)
    @elements.each do |e|
      if e.class == MovingWall and e.id == id
        e.activate
        break
      end
    end
  end
  def set_fixed_camera(x, y)
    @map.set_camera x, y
    @fixed_camera = true
    SB.player.bomb.stop
  end
  def unset_fixed_camera
    @fixed_camera = false
  end
  def finish
    @finished = true
    SB.player.bomb.active = false
  end
  def update(stopped)
    unless stopped
      @elements.each do |e|
        e.update self if e.is_visible @map
        @elements.delete e if e.dead?
      end
    end
    @effects.each do |e|
      e.update
      @effects.delete e if e.dead
    end
    @hide_tiles.each do |t|
      t.update self if t.is_visible @map
    end
    unless @fixed_camera
      SB.player.bomb.update(self)
      if SB.player.dead?
        @reload = true if KB.key_pressed? Gosu::KbReturn
        return
      end
      if @finished
        return :finish
      elsif @border_exit == 0 && SB.player.bomb.y + SB.player.bomb.h <= -C::EXIT_MARGIN ||
            @border_exit == 1 && SB.player.bomb.x >= @size.x - C::EXIT_MARGIN ||
            @border_exit == 2 && SB.player.bomb.y >= @size.x + C::EXIT_MARGIN ||
            @border_exit == 3 && SB.player.bomb.x + SB.player.bomb.w <= C::EXIT_MARGIN
        return :next_section
      elsif @border_exit != 2 && SB.player.bomb.y >= @size.y + C::EXIT_MARGIN
        SB.player.die
        return
      end
      @map.set_camera (SB.player.bomb.x - @margin.x).round, (SB.player.bomb.y - @margin.y).round
      if KB.key_pressed? Gosu::KbEscape
        SB.state = :paused
      end
    end
  end
  def draw
    draw_bgs
    @map.foreach do |i, j, x, y|
      b = @tiles[i][j].back
      if b >= 0
        ind = b
        if b >= 90 && b < 93; ind = 90 + (b - 90 + @tile_3_index) % 3
        elsif b >= 93 && b < 96; ind = 93 + (b - 93 + @tile_3_index) % 3
        elsif b >= 96; ind = 96 + (b - 96 + @tile_4_index) % 4; end
        @tileset[ind].draw x, y, 0
      end
      @tileset[@tiles[i][j].pass].draw x, y, 0 if @tiles[i][j].pass >= 0
      @tileset[@tiles[i][j].wall].draw x, y, 0 if @tiles[i][j].wall >= 0 and not @tiles[i][j].broken
    end
    @elements.each do |e|
      e.draw @map if e.is_visible @map
    end
    SB.player.bomb.draw @map
    @effects.each do |e|
      e.draw @map
    end
    @map.foreach do |i, j, x, y|
      f = @tiles[i][j].fore
      if f >= 0
        ind = f
        if f >= 90 && f < 93; ind = 90 + (f - 90 + @tile_3_index) % 3
        elsif f >= 93 && f < 96; ind = 93 + (f - 93 + @tile_3_index) % 3
        elsif f >= 96; ind = 96 + (f - 96 + @tile_4_index) % 4; end
        @tileset[ind].draw x, y, 0
      end
    end
    @tile_timer += 1
    if @tile_timer == C::TILE_ANIM_INTERVAL
      @tile_3_index = (@tile_3_index + 1) % 3
      @tile_4_index = (@tile_4_index + 1) % 4
      @tile_timer = 0
    end
    @hide_tiles.each do |t|
      t.draw @map if t.is_visible @map
    end
  end
  def draw_bgs
    @bgs.each_with_index do |bg, ind|
      back_x = -@map.cam.x * 0.9 + ind * 0.1; back_y = -@map.cam.y * 0.9 + ind * 0.1
      tiles_x = @size.x / bg.width; tiles_y = @size.y / bg.height
      (1..tiles_x-1).each do |i|
        if back_x + i * bg.width > 0
          back_x += (i - 1) * bg.width
          break
        end
      end
      (1..tiles_y-1).each do |i|
        if back_y + i * bg.height > 0
          back_y += (i - 1) * bg.height
          break
        end
      end
      first_back_y = back_y
      while back_x < C::SCREEN_WIDTH
        while back_y < C::SCREEN_HEIGHT
          bg.draw back_x, back_y, 0
          back_y += bg.height
        end
        back_x += bg.width
        back_y = first_back_y
      end
    end
  end
end
class Stage
  attr_reader :num, :id, :starting, :cur_entrance, :switches
  def initialize(world, num, loaded = false, time = nil)
    @world = world
    @num = num
    if time
      @time = time
      @counter = 0
    end
    @id = "#{world}-#{num}"
    @sections = []
    @entrances = []
    @switches = []
    taken_switches = loaded ? eval("[#{SB.save_data[9]}]") : []
    used_switches = loaded ? eval("[#{SB.save_data[10]}]") : []
    sections = Dir["#{Res.prefix}stage/#{world}/#{num}-*"]
    sections.sort.each do |s|
      @sections << Section.new(s, @entrances, @switches, taken_switches, used_switches)
    end
    SB.player.reset(loaded)
    reset_switches
    @cur_entrance = @entrances[loaded ? SB.save_data[7].to_i : 0]
    @cur_section = @cur_entrance[:section]
  end
  def start
    @panel_x = -600
    @timer = 0
    @alpha = 255
    @starting = true
    @cur_section.start @switches, @cur_entrance[:x], @cur_entrance[:y]
  end
  def update
    if @starting
      @timer = 240 if @timer < 240 and (KB.key_pressed? Gosu::KbReturn or KB.key_pressed? Gosu::KbSpace)
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
        SB.play_sound Res.sound(:victory)
        Gosu::Song.current_song.stop
        return :finish
      elsif status == :next_section
        index = @sections.index @cur_section
        @cur_section = @sections[index + 1]
        entrance = @entrances[@cur_section.default_entrance]
        @cur_section.start @switches, entrance[:x], entrance[:y]
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
        if @stopped_timer == C::STOP_TIME_DURATION
          @stopped = false
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
        reset_switches
        @cur_section = @cur_entrance[:section]
        start
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
      if s[:state] == :temp_taken or s[:state] == :temp_taken_used
        s[:state] = :normal
      elsif s[:state] == :temp_used
        s[:state] = :taken
      end
      s[:obj] = s[:type].new(s[:x], s[:y], s[:args], s[:section], s)
    end
  end
  def save_switches
    @switches.each do |s|
      if s[:state] == :temp_taken
        s[:state] = :taken
      elsif s[:state] == :temp_used or s[:state] == :temp_taken_used
        s[:state] = :used
      end
    end
  end
  def switches_by_state(state)
    @switches.select{ |s| s[:state] == state }.map{ |s| s[:index] }.join(',')
  end
  def stop_time
    @stopped = true
    @stopped_timer = 0
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
      world_name = @world == 'bonus' ? "#{SB.text(:bonus)} #{@num}" : SB.text("world_#{@world}")
      SB.text_helper.write_line world_name, @panel_x + 300, 220, :center
      name = @world == 'bonus' ? SB.text("bonus_#{@num}") : "#{@world}-#{@num}: #{SB.text("stage_#{@world}_#{@num}")}"
      SB.big_text_helper.write_line name, @panel_x + 300, 300, :center
    elsif @time
      SB.text_helper.write_line @time.to_s, 400, 570, :center, 0xffff00, 255, :border
    end
  end
end
class MenuImage < MenuElement
  def initialize(x, y, img)
    @x = x
    @y = y
    @img = Res.img img
  end
  def draw
    @img.draw @x, @y, 0
  end
end
class MenuPanel < MenuElement
  def initialize(x, y, w, h)
    @x = x
    @y = y
    @w = w
    @h = h
  end
  def draw
    G.window.draw_quad @x, @y, C::PANEL_COLOR,
                       @x + @w, @y, C::PANEL_COLOR,
                       @x, @y + @h, C::PANEL_COLOR,
                       @x + @w, @y + @h, C::PANEL_COLOR, 0
  end
end
class BombButton < Button
  include FormElement
  def initialize(x, bomb, form)
    super(x: x, y: 240, width: 80, height: 80) {
      SB.player.set_bomb(bomb)
      SB.state = :main
      form.reset
    }
    @bomb = SB.player.bomb(bomb)
    @bomb_img = Res.img "icon_Bomba#{bomb.capitalize}"
  end
  def draw
    G.window.draw_quad @x, @y, C::PANEL_COLOR,
                       @x + @w, @y, C::PANEL_COLOR,
                       @x, @y + @h, C::PANEL_COLOR,
                       @x + @w, @y + @h, C::PANEL_COLOR, 0
    @bomb_img.draw @x + 40 - @bomb_img.width / 2, @y + 30 - @bomb_img.height / 2, 0
    SB.small_text_helper.write_breaking @bomb.name, @x + 40, @y + 52, 64, :center
  end
end
class StageMenu
  class << self
    attr_reader :ready
    def initialize
      if @ready
        @stage_menu.reset
        set_bomb_screen_comps
        @alpha = 0
      else
        options_comps = [MenuPanel.new(10, 90, 780, 450)]
        options_comps.concat(Options.get_menu)
        @stage_menu = Form.new([
          MenuImage.new(275, 180, :ui_stageMenu),
          MenuButton.new(207, :resume, true) {
            SB.state = :main
          },
          MenuButton.new(257, :change_bomb) {
            @stage_menu.go_to_section 1
          },
          MenuButton.new(307, :options) {
            Options.set_temp
            @stage_menu.go_to_section 2
          },
          MenuButton.new(357, :save_exit) {
            SB.save_and_exit
          }
        ], [], options_comps, [
          MenuButton.new(350, :continue, false, 219) {
            SB.next_stage
          },
          MenuButton.new(350, :save_exit, false, 409) {
            SB.next_stage false
          }
        ])
        set_bomb_screen_comps
        @alpha = 0
        @ready = true
        @lives_icon = Res.img :icon_lives
        @hp_icon = Res.img :icon_hp
        @score_icon = Res.img :icon_score
      end
      Options.form = @stage_menu
    end
    def set_bomb_screen_comps
      sec = @stage_menu.section(1)
      sec.clear
      sec.add(MenuButton.new(550, :back, true) {
                @stage_menu.go_to_section 0
              })
      case SB.player.last_world
      when 1 then sec.add(BombButton.new(360, :azul, @stage_menu))
      when 2 then sec.add(BombButton.new(310, :azul, @stage_menu))
                  sec.add(BombButton.new(410, :vermelha, @stage_menu))
      when 3 then sec.add(BombButton.new(260, :azul, @stage_menu))
                  sec.add(BombButton.new(360, :vermelha, @stage_menu))
                  sec.add(BombButton.new(460, :amarela, @stage_menu))
      when 4 then sec.add(BombButton.new(210, :azul, @stage_menu))
                  sec.add(BombButton.new(310, :vermelha, @stage_menu))
                  sec.add(BombButton.new(410, :amarela, @stage_menu))
                  sec.add(BombButton.new(510, :verde, @stage_menu))
      else        sec.add(BombButton.new(160, :azul, @stage_menu))
                  sec.add(BombButton.new(260, :vermelha, @stage_menu))
                  sec.add(BombButton.new(360, :amarela, @stage_menu))
                  sec.add(BombButton.new(460, :verde, @stage_menu))
                  sec.add(BombButton.new(560, :branca, @stage_menu))
      end
    end
    def update_main
      if SB.player.dead?
        @dead_text = (SB.player.lives == 0 ? :game_over : :dead) if @dead_text.nil?
        @alpha += 17 if @alpha < 255
      elsif @dead_text
        @dead_text = nil
        @alpha = 0
      end
    end
    def update_end
      @stage_end_timer += 1 if @stage_end_timer < 30 * @stage_end_comps.length
      @stage_menu.update
      @stage_end_comps.each_with_index do |c, i|
        c.update_movement if @stage_end_timer >= i * 30
      end
    end
    def update_paused
      @stage_menu.update
    end
    def end_stage(next_world, next_bonus = false, bonus = false)
      p = MenuPanel.new(-600, 150, 400, 300)
      p.init_movement
      p.move_to 200, 150
      t1 = MenuText.new(:stage_complete, 1200, 160, 400, :center, true)
      t1.init_movement
      t1.move_to 400, 160
      t2 = MenuText.new(:score, 210, 820)
      t2.init_movement
      t2.move_to 210, 220
      t3 = MenuNumber.new(SB.player.stage_score, 590, 820, :right)
      t3.init_movement
      t3.move_to 590, 220
      t4 = MenuText.new(:total, 210, 860)
      t4.init_movement
      t4.move_to 210, 260
      t5 = MenuNumber.new(SB.player.score, 590, 860, :right, next_bonus ? 0xff0000 : 0)
      t5.init_movement
      t5.move_to 590, 260
      unless bonus
        t6 = MenuText.new(:spec_taken, 210, 900)
        t6.init_movement
        t6.move_to 210, 300
        t7 = MenuText.new(SB.player.specs.index(SB.stage.id) ? :yes : :no, 590, 900, 300, :right)
        t7.init_movement
        t7.move_to 590, 300
      end
      @stage_end_comps = [p, t1, t2, t3, t4, t5]
      @stage_end_comps << t6 << t7 unless bonus
      @stage_end_timer = 0
      if next_world or next_bonus
        @stage_menu.section(3).clear
        @stage_menu.section(3).add(MenuButton.new(350, :continue) {
                                     SB.check_next_stage
                                   })
        @continue_only = true
      elsif @continue_only
        @stage_menu.section(3).clear
        @stage_menu.section(3).add(MenuButton.new(350, :continue, false, 219) {
                                     SB.check_next_stage
                                   })
        @stage_menu.section(3).add(MenuButton.new(350, :save_exit, false, 409) {
                                     SB.check_next_stage false
                                   })
        @continue_only = false
      end
      @stage_menu.go_to_section 3
    end
    def update_lang
      @stage_menu.update_lang if StageMenu.ready
    end
    def draw
      if SB.state == :main
        draw_player_stats unless SB.stage.starting
        draw_player_dead if SB.player.dead?
      elsif SB.state == :paused
        draw_menu
      else
        draw_stage_stats
      end
    end
    def draw_player_stats
      p = SB.player
      G.window.draw_quad 5, 5, C::PANEL_COLOR,
                         205, 5, C::PANEL_COLOR,
                         205, 55, C::PANEL_COLOR,
                         5, 55, C::PANEL_COLOR, 0
      @lives_icon.draw 12, 10, 0
      SB.font.draw p.lives, 40, 10, 0, 1, 1, 0xff000000
      @hp_icon.draw 105, 10, 0
      SB.font.draw p.bomb.hp, 135, 10, 0, 1, 1, 0xff000000
      @score_icon.draw 10, 32, 0
      SB.font.draw p.stage_score, 40, 32, 0, 1, 1, 0xff000000
      G.window.draw_quad 745, 5, C::PANEL_COLOR,
                         795, 5, C::PANEL_COLOR,
                         795, 55, C::PANEL_COLOR,
                         745, 55, C::PANEL_COLOR, 0
      if p.cur_item_type
        item_set = p.items[p.cur_item_type]
        item_set[0][:obj].icon.draw 754, 14, 0
        SB.font.draw item_set.length.to_s, 780, 36, 0, 1, 1, 0xff000000
      end
      if p.items.length > 1
        G.window.draw_triangle 745, 30, C::ARROW_COLOR,
                               749, 26, C::ARROW_COLOR,
                               749, 34, C::ARROW_COLOR, 0
        G.window.draw_triangle 791, 25, C::ARROW_COLOR,
                               796, 30, C::ARROW_COLOR,
                               791, 35, C::ARROW_COLOR, 0
      end
      G.window.draw_quad 690, 5, C::PANEL_COLOR,
                         740, 5, C::PANEL_COLOR,
                         740, 55, C::PANEL_COLOR,
                         690, 55, C::PANEL_COLOR, 0
      b = p.bomb
      if b.type == :verde; icon = 'explode'
      elsif b.type == :branca; icon = 'time'
      else; return; end
      Res.img("icon_#{icon}").draw(699, 14, 0, 1, 1, b.can_use_ability ? 0xffffffff : 0x66ffffff)
    end
    def draw_player_dead
      c = ((@alpha / 2) << 24)
      G.window.draw_quad 0, 0, c,
                         C::SCREEN_WIDTH, 0, c,
                         0, C::SCREEN_HEIGHT, c,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, c, 0
      SB.big_text_helper.write_line SB.text(@dead_text), 400, 250, :center, 0, @alpha
      SB.text_helper.write_line SB.text(:restart), 400, 300, :center, 0, @alpha
    end
    def draw_menu
      G.window.draw_quad 0, 0, 0x80000000,
                         C::SCREEN_WIDTH, 0, 0x80000000,
                         0, C::SCREEN_HEIGHT, 0x80000000,
                         C::SCREEN_WIDTH, C::SCREEN_HEIGHT, 0x80000000, 0
      @stage_menu.draw
    end
    def draw_stage_stats
      @stage_end_comps.each { |c| c.draw }
      @stage_menu.draw if @stage_end_timer >= @stage_end_comps.length * 30
    end
  end
end
class MapStage
  attr_reader :x, :y
  def initialize(world, num, x, y, img)
    @x = x
    @y = y
    @img = Res.img "icon_#{img}"
    @glows = img != :unknown
    @state = 0
    @alpha =
      if @glows
        0xff
      else
        0x7f
      end
    @world = world
    @num = num
  end
  def name
    SB.text("stage_#{@world}_#{@num}")
  end
  def update
    return unless @glows
    if @state == 0
      @alpha -= 2
      if @alpha == 0x7f
        @state = 1
      end
    else
      @alpha += 2
      if @alpha == 0xff
        @state = 0
      end
    end
  end
  def select(loaded_stage)
    SB.stage = Stage.new(@world, @num, @num == loaded_stage)
    SB.stage.start
    SB.state = :main
  end
  def open
    @img = Res.img :icon_current
    @glows = true
    @alpha = 0xff
  end
  def close
    @img = Res.img :icon_complete
  end
  def draw(alpha)
    a = ((alpha / 255.0) * (@alpha / 255.0) * 255).round
    @img.draw @x, @y, 0, 1, 1, (a << 24) | 0xffffff
  end
end
class World
  attr_reader :num, :stage_count
  def initialize(num = 1, stage_num = 1, loaded = false)
    @num = num
    @loaded_stage = loaded ? stage_num : nil
    @water = Sprite.new 0, 0, :ui_water, 2, 2
    @mark = GameObject.new 0, 0, 1, 1, :ui_mark
    @arrow = Res.img :ui_changeWorld
    @parchment = Res.img :ui_parchment
    @secret_world = Res.img :ui_secretWorld if SB.player.last_world == C::LAST_WORLD
    @map = Res.img "bg_world#{num}"
    @song = Res.song("w#{@num}")
    @stages = []
    File.open("#{Res.prefix}stage/#{@num}/world").each_with_index do |l, i|
      coords = l.split ','
      if i == 0; @mark.x = coords[0].to_i; @mark.y = coords[1].to_i; next; end
      state =
        if num < SB.player.last_world
          :complete
        elsif i < SB.player.last_stage
          :complete
        elsif i == SB.player.last_stage
          :current
        else
          :unknown
        end
      @stages << MapStage.new(@num, i, coords[0].to_i, coords[1].to_i, state)
    end
    @stage_count = @stages.count
    @enabled_stage_count = num < SB.player.last_world ? @stage_count : SB.player.last_stage
    @cur = (loaded ? @loaded_stage : @enabled_stage_count) - 1
    @bomb = Sprite.new 0, 0, "sprite_Bomba#{SB.player.bomb.type.to_s.capitalize}", 6, 4
    set_bomb_position
    @trans_alpha = 0
  end
  def resume
    SB.play_song @song
    SB.state = :map
  end
  def update
    @water.animate [0, 1, 2, 3], 6
    @bomb.animate [0, 1, 0, 2], 8
    if @next_world
      @trans_alpha -= 17
      @mark.move_free(@mark_aim, @mark_speed)
      if @trans_alpha == 0
        SB.world = World.new(@next_world)
      end
      return
    elsif @trans_alpha < 0xff
      @trans_alpha += 17
    end
    @stages.each { |i| i.update }
    if KB.key_pressed? Gosu::KbEscape or KB.key_pressed? Gosu::KbBackspace
      Menu.reset
      SB.state = :menu
    elsif KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
      @stages[@cur].select(@loaded_stage)
    elsif @cur > 0 and (KB.key_pressed? Gosu::KbLeft or KB.key_pressed? Gosu::KbDown)
      @cur -= 1
      set_bomb_position
    elsif @cur < @enabled_stage_count - 1 and (KB.key_pressed? Gosu::KbRight or KB.key_pressed? Gosu::KbUp)
      @cur += 1
      set_bomb_position
    elsif KB.key_pressed? Gosu::KbLeftShift and @num > 1
      change_world(@num - 1)
    elsif KB.key_pressed? Gosu::KbRightShift and @num < SB.player.last_world
      change_world(@num + 1)
    end
  end
  def set_bomb_position
    @bomb.x = @stages[@cur].x - 4; @bomb.y = @stages[@cur].y - 15
  end
  def set_loaded(stage_num)
    @loaded_stage = stage_num
    @bomb = Sprite.new 0, 0, "sprite_Bomba#{SB.save_data[3].capitalize}", 5, 2
    set_bomb_position
  end
  def open_stage(continue)
    @stages[@cur].close
    if @cur < @stage_count - 1
      @stages[@cur + 1].open
      @enabled_stage_count += 1
      if continue
        @cur += 1
        set_bomb_position
      end
    end
  end
  def change_world(num)
    @next_world = num
    f = File.open("#{Res.prefix}stage/#{@next_world}/world")
    coords = f.readline.split ','
    @mark_aim = Vector.new(coords[0].to_i, coords[1].to_i)
    @mark_speed = @mark_aim.distance(@mark.position) / 15
    f.close
  end
  def draw
    G.window.clear 0x6ab8ff
    y = 0
    while y < C::SCREEN_HEIGHT
      x = 0
      while x < C::SCREEN_WIDTH
        @water.x = x; @water.y = y
        @water.draw
        x += 40
      end
      y += 40
    end
    @map.draw 0, 0, 0, 1, 1, (@trans_alpha << 24) | 0xffffff
    @parchment.draw 0, 0, 0
    @secret_world.draw 0, 75, 0 if @secret_world
    @mark.draw
    @stages.each { |s| s.draw @trans_alpha }
    @bomb.draw nil, 1, 1, @trans_alpha
    SB.big_text_helper.write_line SB.text("world_#{@num}"), 525, 10, :center, 0, @trans_alpha
    SB.text_helper.write_breaking "#{@num}-#{@cur+1}: #{@stages[@cur].name}", 525, 55, 550, :center, 0, @trans_alpha
    SB.text_helper.write_breaking(SB.text(:ch_st_instruct).gsub('\n', "\n"), 780, 545, 600, :right, 0, @trans_alpha)
    if @num > 1
      @arrow.draw 260, 10, 0, 1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:left_shift), 315, 13, 60, :right, 0, @trans_alpha
    end
    if @num < SB.player.last_world
      @arrow.draw 790, 10, 0, -1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:right_shift), 735, 13, 60, :left, 0, @trans_alpha
    end
    if @cur > 0
      @arrow.draw 260, 47, 0, 1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:left_arrow), 315, 50, 60, :right, 0, @trans_alpha
    end
    if @cur < @enabled_stage_count - 1
      @arrow.draw 790, 47, 0, -1, 1, (@trans_alpha << 24) | 0xffffff
      SB.small_text_helper.write_breaking SB.text(:right_arrow), 735, 50, 60, :left, 0, @trans_alpha
    end
  end
end
class SavedGameButton < Button
  include FormElement
  def initialize(x, y)
    super(x: x, y: y, width: 370, height: 80)
  end
end
class NewGameButton < Button
  include FormElement
  attr_reader :text_id
  def initialize(index, x, y, menu)
    super(x: x, y: y, width: 370, height: 80) {
      menu.go_to_new_game(@index - 1)
      SB.play_sound @sound
    }
    @index = index
    @img = Res.img(:ui_bgGameSlot)
    @text = SB.text(:new_game)
    @text_id = :new_game
    @sound = Res.sound :btn1
  end
  def draw(alpha = 0xff, z_index = 0)
    @img.draw @x, @y, 0
    SB.font.draw_rel @index.to_s, @x + 365, @y + 40, 0, 1, 0.5, 3, 3, 0x80000000
    SB.text_helper.write_line @text, @x + 185, @y + 30, :center, 0xffffff, 255, :border
  end
end
class SavedGame
  include FormElement
  def initialize(index, x, y, name, bomb, world_stage, specs, score)
    @index = index
    @x = x
    @y = y
    @name = name
    @world_stage = world_stage
    @specs = specs.split(',').size
    @score = score
    @bg = Res.img(:ui_bgGameSlot)
    @bomb = Res.img("icon_Bomba#{bomb.capitalize}")
    @map_icon = Res.img(:icon_map)
    @spec_icon = Res.img(:icon_spec)
    @score_icon = Res.img(:icon_score)
  end
  def update; end
  def set_position(x, y)
    @x = x; @y = y
  end
  def draw
    @bg.draw @x, @y, 0
    @bomb.draw @x + 5, @y + 5, 0
    @map_icon.draw @x + 45, @y + 40, 0
    @spec_icon.draw @x + 135, @y + 40, 0
    @score_icon.draw @x + 227, @y + 42, 0
    SB.font.draw_rel @index.to_s, @x + 365, @y + 40, 0, 1, 0.5, 3, 3, 0x80000000
    SB.text_helper.write_line @name, @x + 45, @y + 5, :left, 0xffffff, 255, :border
    SB.text_helper.write_line @world_stage, @x + 75, @y + 41
    SB.text_helper.write_line @specs.to_s, @x + 165, @y + 41
    SB.text_helper.write_line @score, @x + 255, @y + 41
  end
end
class Menu
  class << self
    def initialize
      @bg = Res.img :bg_start1, true, false, '.jpg'
      @title = Res.img :ui_title, true
      @form = Form.new([
        MenuButton.new(270, :play) {
          @form.go_to_section 1
        },
        MenuButton.new(320, :help) {
          @form.go_to_section 7
        },
        MenuButton.new(370, :options) {
          Options.set_temp
          @form.go_to_section 5
        },
        MenuButton.new(420, :credits) {
          @form.go_to_section 6
        },
        MenuButton.new(470, :exit, true) {
          exit
        }
      ], [], [
        MenuButton.new(345, :continue) {
          SB.load_game @selected_game
        },
        MenuButton.new(395, :delete) {
          @form.go_to_section 4
        },
        MenuButton.new(445, :back, true) {
          @form.go_to_section 1
        }
      ], [
        (@txt_name = MenuTextField.new(295)),
        MenuText.new(:what_name, 400, 220, 400, :center),
        MenuButton.new(345, :play) {
          SB.new_game(@txt_name.text.downcase, @new_game_index) unless @txt_name.text.empty?
        },
        MenuButton.new(395, :back, true) {
          @form.go_to_section 1
        }
      ], [
        MenuText.new(:delete_confirm, 400, 270, 400, :center),
        MenuButton.new(345, :no, true) {
          @form.go_to_section 1
        },
        MenuButton.new(395, :yes) {
          File.delete(@selected_game)
          add_game_slots
          @form.go_to_section 1
        }
      ], Options.get_menu, [
        MenuButton.new(550, :back, true) {
          @form.go_to_section 0
        },
        MenuText.new(:credits_text, 400, 200, 600, :center)
      ], [
        MenuButton.new(550, :back, true) {
          @form.go_to_section 0
        },
        MenuText.new(:help_text, 400, 200, 600, :center)
      ])
      Options.form = @form
      add_game_slots
    end
    def update
      if @form.cur_section_index == 3 && @form.section(3).cur_btn == @txt_name && KB.key_pressed?(Gosu::KbReturn)
        SB.new_game(@txt_name.text.downcase, @new_game_index) unless @txt_name.text.empty?
      end
      @form.update
    end
    def reset
      @form.reset
      @txt_name.text = ''
      add_game_slots
      Options.form = @form
      SB.play_song Res.song(:main)
    end
    def update_lang
      @form.update_lang
    end
    def add_game_slots
      components = []
      @saved_games = []
      games = Dir["#{SB.save_dir}/*"].sort
      next_index = 0
      sound = Res.sound :btn1
      games.each do |g|
        file = g.split('/')[-1]
        next unless /^[0-9]$/ =~ file
        num = file.to_i
        (next_index...num).each do |i|
          components << NewGameButton.new(i + 1, 20 + (i % 2) * 390, 95 + (i / 2) * 90, self)
        end
        next_index = num + 1
        data = IO.readlines(g).map { |l| l.chomp }
        saved_game = SavedGame.new(num + 1, 20 + (num % 2) * 390, 95 + (num / 2) * 90, data[0], data[3], data[2], data[6], data[5])
        @saved_games << saved_game
        components << saved_game
        components <<
          SavedGameButton.new(20 + (num % 2) * 390, 95 + (num / 2) * 90) {
            @selected_game = g
            @form.go_to_section 2
            SB.play_sound sound
          }
      end
      (next_index...C::GAME_LIMIT).each do |i|
        components << NewGameButton.new(i + 1, 20 + (i % 2) * 390, 95 + (i / 2) * 90, self)
      end
      components << MenuButton.new(550, :back, true) {
        @form.go_to_section 0
      }
      components << MenuText.new(:choose_game, 780, 25, 380, :right)
      section = @form.section(1)
      section.clear
      components.each { |c| section.add(c) }
    end
    def go_to_new_game(index)
      @new_game_index = index
      @form.go_to_section 3
    end
    def draw
      @bg.draw 0, 0, 0
      @title.draw 0, 0, 0, @form.cur_section_index == 1 ? 0.5 : 1, @form.cur_section_index == 1 ? 0.5 : 1
      @form.draw
    end
  end
end
class SBGame < MiniGL::GameWindow
  def initialize
    super(C::SCREEN_WIDTH, C::SCREEN_HEIGHT, false, Vector.new(0, 0.7))
    G.ramp_slip_threshold = 0.8
    G.ramp_slip_force = 0.8
    
    os = RbConfig::CONFIG['host_os']
    dir =
      if /linux/ =~ os
        "#{Dir.home}/.aleva-games/super-bombinhas"
      else
        "#{Dir.home}/AppData/Local/Aleva Games/Super Bombinhas"
      end
    SB.initialize dir
    @logo = Res.img(:ui_alevaLogo)
    @timer = @state = @alpha = 0
  end
  def needs_cursor?
    SB.state != :main && SB.state != :map
  end
  def update
    KB.update
    Mouse.update
    close if KB.key_pressed? Gosu::KbTab
    if SB.state == :presentation
      @timer += 1
      if @state < 2
        @alpha += 5 if @alpha < 255
        if @timer == 120
          @state += 1
          @timer = 0
          @alpha = 0 if @state == 1
        end
      elsif @state > 2
        @alpha -= 17 if @alpha > 0
        @alpha = 0 if @alpha < 0
        if @timer == 15
          if @state == 5; SB.state = :menu
          else; @state += 1; @alpha = 255; end
          @timer = 0
        end
      else
        @alpha -= 5 if @alpha > 0
        if @timer == 120
          @state += 1
          @timer = 0
          @alpha = 255
          SB.play_song Res.song(:main)
        end
      end
    elsif SB.state == :menu
      Menu.update
    elsif SB.state == :map
      SB.world.update
    elsif SB.state == :main
      status = SB.stage.update
      SB.end_stage if status == :finish
      StageMenu.update_main
    elsif SB.state == :stage_end
      SB.player.bomb.update(nil)
      StageMenu.update_end
    elsif SB.state == :paused
      StageMenu.update_paused
    elsif SB.state == :movie
      SB.movie.update
    elsif SB.state == :game_end || SB.state == :game_end_2
      if KB.key_pressed? Gosu::KbReturn or KB.key_pressed? Gosu::KbSpace
        Menu.reset
        SB.state = :menu
      end
    end
  end
  def draw
    if SB.state == :presentation
      @logo.draw 200, 235, 0, 1, 1, (@state == 1 ? 0xffffffff : (@alpha << 24) | 0xffffff)
      SB.text_helper.write_line(SB.text(:presents), 400, 365, :center, 0xffffff, (@state == 0 ? 0 : @alpha))
      if @state > 2
        Menu.draw
        (0..3).each do |i|
          (0..3).each do |j|
            s = (i + j) % 3
            c = @state < s + 3 ? 0xff000000 : @state == s + 3 ? @alpha << 24 : 0
            G.window.draw_quad i * 200, j * 150, c,
                               i * 200 + 200, j * 150, c,
                               i * 200, j * 150 + 150, c,
                               i * 200 + 200, j * 150 + 150, c, 0
          end
        end
      end
    elsif SB.state == :menu
      Menu.draw
    elsif SB.state == :map
      SB.world.draw
    elsif SB.state == :main || SB.state == :paused || SB.state == :stage_end
      SB.stage.draw
      StageMenu.draw
    elsif SB.state == :movie
      SB.movie.draw
    elsif SB.state == :game_end || SB.state == :game_end_2
      clear 0
      SB.big_text_helper.write_line SB.text(SB.state), 400, 280, :center, 0xffffff
      SB.small_text_helper.write_line SB.text("#{SB.state}_sub"), 400, 320, :center, 0xffffff, 51
    end
  end
end
class MiniGL::GameObject
  def is_visible(map)
    return map.cam.intersect? @active_bounds if @active_bounds
    false
  end
  def dead?
    @dead
  end
  def position
    Vector.new(@x, @y)
  end
  def speak(msg_id, page = 0)
    return if SB.state == :paused
    msg = SB.text(msg_id).split('/')
    G.window.draw_quad 5, 495, C::PANEL_COLOR,
                       795, 495, C::PANEL_COLOR,
                       5, 595, C::PANEL_COLOR,
                       795, 595, C::PANEL_COLOR, 1
    SB.text_helper.write_breaking msg[page], 10, 495, 780, :justified, 0, 255, 1
    if msg.size > 1 && page < msg.size - 1
      G.window.draw_triangle 780, 585, C::ARROW_COLOR,
                             790, 585, C::ARROW_COLOR,
                             785, 590, C::ARROW_COLOR, 1
    end
  end
end
SBGame.new.show