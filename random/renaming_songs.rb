puts "Renaming files..."

folder_path = "/mnt/c/Users/Philip Ross/Music/Hamilton (Original Broadway Cast Recording)/"
Dir.glob(folder_path + "*").sort.each do |f|
  filename = File.basename(f, File.extname(f))
  next unless filename.start_with?('(Disc 2)')
  puts filename
  new_name = filename[9..-1]
  puts new_name
  track_num = new_name.to_i + 23
  new_name[0..1] = track_num.to_s
  puts new_name
  File.rename(f, folder_path + new_name + File.extname(f))
end

puts "Renaming complete."