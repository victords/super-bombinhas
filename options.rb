require_relative 'form'

class Options
  def form=(form)
    @form = form
  end

  def set_temp
    @lang = SB.lang
    @sound_volume = SB.sound_volume
    @music_volume = SB.music_volume
  end

  def get_menu
    [
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
    ]
  end
end