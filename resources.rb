require './global'
include Gosu

class Res
	def self.initialize
		@@imgs = Hash.new
		@@global_imgs = Hash.new
		@@sounds = Hash.new
		@@global_sounds = Hash.new
	end
	
	def self.img id, global = false, tileable = false, ext = ".png"
		if global; a = @@global_imgs; else; a = @@imgs; end
		return a[id] if a[id]
		s = "data/img/" + id.to_s.split('_').join('/') + ext
		img = Image.new G.window, s, tileable
		a[id] = img
	end
	
	def self.imgs id, sprite_cols, sprite_rows, global = false, ext = ".png"
		if global; a = @@global_imgs; else; a = @@imgs; end
		return a[id] if a[id]
		s = "data/img/" + id.to_s.split('_').join('/') + ext
		imgs = Image.load_tiles G.window, s, -sprite_cols, -sprite_rows, false
		a[id] = imgs
	end
	
	def self.tileset id, global = false
		if global; a = @@global_imgs; else; a = @@imgs; end
		return a[id] if a[id]
		s = "data/img/tileset/#{id}.png"
		tileset = Image.load_tiles G.window, s, C::TileSize, C::TileSize, true
		a[id] = tileset
	end
	
	def self.sound id, global = false
		if global; a = @@global_sounds; else; a = @@sounds; end
		return a[id] if a[id]
		s = "data/sound/se/" + id.to_s.split('_').join('/') + ".wav"
		sound = Sample.new G.window, s
		a[id] = sound
	end
	
	def self.song id, global = false
		if global; a = @@global_sounds; else; a = @@sounds; end
		return a[id] if a[id]
		s = "data/sound/bgm/" + id.to_s.split('_').join('/') + ".ogg"
		song = Song.new G.window, s
		a[id] = song
	end
	
	def self.text id
		G.texts[G.lang][id.to_sym]
	end
	
	def self.clear
		@imgs.clear
		@sounds.clear
	end
end
