start_level = 1
end_level = 18
(start_level..end_level).each do |level|
  flat_pen = 5 + 0.5 * level
  percent_pen = flat_pen / 0.07
  puts "level: #{level}, flat_pen: #{flat_pen}, percent pen: #{percent_pen}"
end