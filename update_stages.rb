ind = ARGV.shift.to_i
puts "Índice: #{ind}"
files = Dir['data/stage/*/*']
files.each do |f_name|
  next if ['world', 'times'].include? f_name.split('/')[-1]
  puts "processing #{f_name}..."

  f = File.open(f_name)
  content = f.read
  f.close
  200.downto(ind) do |i|
    content.gsub! /([@$])0?#{i}([:;])/, "\\1#{i + 1}\\2"
  end
  f = File.open(f_name, 'w')
  f.write content
  f.close
end
