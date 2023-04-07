bundle = <<END
gem 'gosu', '>=1.1.0'
gem 'minigl', '2.4.3'

require 'minigl'
require 'fileutils'
require 'rbconfig'
include MiniGL
END

file_names = %w(global credits bomb elements enemies form items movie options player section stage stage_menu world menu editor game)

file_names.each do |name|
  File.open("#{name}.rb") do |f|
    c = f.read
    c.gsub!(/^require(_relative)? '[a-z0-9_]+'\n/, '')
    c.gsub!(/^include [A-Za-z0-9_]+\n/, '')
    c.gsub!(/^gem .*?\n/, '')
    c.gsub!(/^\s*#.*\n/, '')
    c.gsub!(/ #[^"\n]+$/, '')
    bundle += c + "\n"
    puts "Processed #{name}"
  end
end

File.open('sb.rb', 'w+') do |f|
  f.write bundle
end