require_relative 'menu'
require_relative 'stage_menu'

class SBGame < MiniGL::GameWindow
  def initialize
    super(C::SCREEN_WIDTH, C::SCREEN_HEIGHT, false, Vector.new(0, 0.9))
    SB.initialize
  end

  def needs_cursor?
    SB.state != :main && SB.state != :map
  end

  def update
    KB.update
    Mouse.update

    close if KB.key_pressed? Gosu::KbTab

    if SB.state == :presentation

    elsif SB.state == :menu
      Menu.update
    elsif SB.state == :map
      SB.world.update
    elsif SB.state == :main
      status = SB.stage.update
      SB.end_stage if status == :finish
    elsif SB.state == :stage_end
      SB.player.bomb.update(nil)
      StageMenu.update
    elsif SB.state == :paused
      StageMenu.update
    end
  end

  def draw
    if SB.state == :presentation

    elsif SB.state == :menu
      Menu.draw
    elsif SB.state == :map
      SB.world.draw
    elsif SB.state == :main || SB.state == :paused || SB.state == :stage_end
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

  def position
    Vector.new(@x, @y)
  end
end

SBGame.new.show
