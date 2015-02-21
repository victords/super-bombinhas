require_relative 'section'

class Stage
  attr_reader :switches

  def initialize(world, num)
    @sections = []
    @entrances = []
    @switches = []
    sections = Dir["#{Res.prefix}stage/#{world}/#{num}-*.sbs"]
    sections.sort.each do |s|
      @sections << Section.new(s, @entrances, @switches)
    end

    SB.player.reset
    reset_switches
    @cur_section = @sections[0]
    @cur_entrance = @entrances[0]
    @cur_section.start @switches, @cur_entrance[:x], @cur_entrance[:y]
  end

  def update
    @cur_section.update
    check_reload
    check_entrance
    check_warp
  end

  def check_reload
    if @cur_section.reload
      @sections.each do |s|
        s.loaded = false
      end

      SB.player.reset
      reset_switches
      @cur_section = @cur_entrance[:section]
      @cur_section.start @switches, @cur_entrance[:x], @cur_entrance[:y]
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

  def draw
    # cuidar das transições
    @cur_section.draw
  end
end
