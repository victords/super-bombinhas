require 'rbconfig'
require 'gosu'
require_relative 'menu'
require_relative 'stage_menu'
require_relative 'movie'

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

    close if KB.key_pressed? Gosu.
    toggle_fullscreen if KB.key_pressed? Gosu::KbF4

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
      if KB.key_pressed? Gosu:: or KB.key_pressed? Gosu::KbSpace
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
end

SBGame.new.show
