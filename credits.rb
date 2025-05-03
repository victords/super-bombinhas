require_relative 'global'

class Credits
  FIRST_SPACING = 120
  SPACING = 200

  class << self
    def initialize
      @title = Res.img(:ui_title, true)
      @base_y = (C::SCREEN_HEIGHT - @title.height * 2) / 2
      @writer = SB.text_helper
      @texts = [
        [SB.text(:credits_prog), 2],
        ["Victor David Santos", 3],
        [SB.text(:credits_music), 2],
        ["Francesco Corrado\nZergananda", 3],
        [SB.text(:sounds), 2],
        ["Freesound.org\n" + SB.text(:sounds_edit), 3],
        [SB.text(:graph_soft), 2],
        ["Aseprite\nInkscape", 3],
        [SB.text(:music_soft), 2],
        ["Ardour 6\nmpv\nAudacity", 3],
        [SB.text(:langs_libs), 2],
        ["Ruby language\nGosu\nMiniGL\n" + SB.text(:developed), 3],
        [SB.text(:special_thanks), 2],
        ["Yuri David Santos\nMaria Alice Armelin\nFrancesco Corrado\nVinícius de Araújo Barboza\nStefano Girardi\nJorge Maldonado Ventura\nNur Bagus Satrio\n" + SB.text(:special_thanks3), 3]
      ]
      @full_height = @title.height * 2 + FIRST_SPACING
      @texts.each do |t|
        t << @full_height + SPACING
        @full_height += t[0].split("\n").size * t[1] * (SB.font.height + 5) - 5 + SPACING
      end
      @state = @timer = @alpha1 = @alpha2 = 0
    end

    def update
      @timer += 1
      if @state == 0
        Gosu::Song.current_song.volume = (1 - @timer.to_f / 30) * 0.1 * SB.music_volume
        if @timer == 30
          @state = 1
          @timer = 0
          SB.play_song(Res.song(:credits))
        end
      elsif @state == 1
        if @timer == 240
          @state = 2
          @timer = 0
        end
      elsif @state == 2
        @base_y -= 1
        if @base_y + @full_height <= 0
          @state = 3
          @timer = 0
        end
      elsif @state == 3
        if @timer >= 60
          @alpha1 += 3 if @alpha1 < 255
          if SB.key_pressed?(:confirm) || SB.key_pressed?(:back)
            Menu.reset
            SB.state = :menu
          end
        end
        if @timer >= 180
          @alpha2 += 1 if @alpha2 < 127
        end
      end
    end

    def draw
      if @state == 1 || @state == 2
        @title.draw((C::SCREEN_WIDTH - @title.width * 2) / 2, @base_y, 0, 2, 2)
        @texts.each do |t|
          @writer.write_breaking(t[0], C::SCREEN_WIDTH / 2, @base_y + t[2], 760, :center,0xffffff, 255, 0, t[1], t[1])
        end
      elsif @state == 3
        @writer.write_line(SB.text(:game_end), C::SCREEN_WIDTH / 2, (C::SCREEN_HEIGHT - SB.font.height) / 2, :center, 0xffffff, @alpha1)
        @writer.write_line(SB.text(:game_end_sub), C::SCREEN_WIDTH / 2, (C::SCREEN_HEIGHT - SB.font.height) / 2 + 30, :center, 0xffffff, @alpha2, nil, 0, 0, 0, 0, 1.5, 1.5)
      end
    end
  end
end
