#!/home/victor/.rvm/rubies/ruby-2.0.0-p353/bin/ruby
#encoding: UTF-8

require_relative 'menu'
require_relative 'stage_menu'

class SBGame < MiniGL::GameWindow
  def initialize
    super(C::SCREEN_WIDTH, C::SCREEN_HEIGHT, false, Vector.new(0, 0.9))

    SB.initialize
    SB.menu = Menu.new

#    @frame = 0
  end

  def needs_cursor?
    SB.state != :main
  end

  def update
#    @frame += 1
#    if @frame == 60
#      puts @fps
#      @frame = 0
#    end
    KB.update
    Mouse.update

    close if KB.key_pressed? Gosu::KbTab

    if SB.state == :presentation

    elsif SB.state == :menu
      SB.menu.update
    elsif SB.state == :map
      SB.world.update
    elsif SB.state == :main
      SB.stage.update
    elsif SB.state == :paused
      StageMenu.update
    end
  end

  def draw
    if SB.state == :presentation

    elsif SB.state == :menu
      SB.menu.draw
    elsif SB.state == :map
      SB.world.draw
    elsif SB.state == :main || SB.state == :paused
      SB.stage.draw
      StageMenu.draw
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
end

SBGame.new.show
