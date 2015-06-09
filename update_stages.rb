ind = ARGV.shift.to_i
puts "Índice: #{ind}"
files = Dir['/home/victor/aleva/super-bombinhas/data/stage/*/*']
files[0...1].each do |f_name|
  next if ['world', 'times'].include? f_name.split('/')[-1]
  puts "processing #{f_name}..."

  File.open(f_name) do |f|
    content = f.read
    99.downto(ind) do |i|
      content.gsub! /@#{i}([:;])/, "@#{i + 1}\\1"
    end
    File.open("#{f_name}_", 'w') do |new_f|
      new_f.write content
    end
  end
end