file = File.read(ARGV[0])
chars = ['b', 'f', 'p', 'w']
chars.each do |c|
	puts "replacing #{c}..."
	while m = /#{c}([0-9])([0-9])/.match(file) do
		i = (m[2].to_i - 1) * 8 + (m[1].to_i - 1)
		file.sub! /#{c}([0-9])([0-9])/, ("#{c.upcase}%02d" % i)
	end
end
chars.each do |c|
	file.gsub! c.upcase, c
end
File.open(ARGV[0], 'w') { |f| f.write(file) }
