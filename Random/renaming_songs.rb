puts "Renaming files..."

folder_path = "C:/Users/Philip Ross/Music/Saijaku Muhai no Bahamut/"
Dir.glob(folder_path + "*").sort.each do |f|
  filename = File.basename(f, File.extname(f))
  next unless filename.match(/\d/)
  puts filename
  puts filename[5..-1]
  File.rename(f, folder_path + filename[5..-1] + File.extname(f))
end

puts "Renaming complete."