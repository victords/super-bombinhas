bundle = <<END
require 'minigl'
require 'fileutils'
require 'rbconfig'
include MiniGL

END

file_names = %w(global credits bomb elements enemies form items movie options player section stage stage_menu world menu game)

file_names.each do |name|
  File.open("#{name}.rb") do |f|
    c = f.read
    c.gsub!(/^require(_relative)? '[a-z0-9_]+'\n/, '')
    c.gsub!(/^include [A-Za-z0-9_]+\n/, '')
    c.gsub!(/^\s*#.*\n/, '')
    c.gsub!(/ #[^"\n]+$/, '')
    bundle += c + "\n"
    puts "Processed #{name}"
  end
end

bundle.gsub!("\n\n", "\n")
bundle.gsub!("\n\n", "\n")
File.open('sb.rb', 'w+') do |f|
  f.write bundle
end