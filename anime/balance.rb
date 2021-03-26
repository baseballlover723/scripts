require 'optparse'

# CAP_ANIME = 3.63 # TB
# CAP_LONG = 1.81 # TB
CAP_ANIME = 4.54 # TB
CAP_LONG = 3.63 # TB
CAP_TOTAL = CAP_ANIME + CAP_LONG
RATIO_ANIME = CAP_ANIME / CAP_TOTAL
RATIO_LONG = CAP_LONG / CAP_TOTAL


help = "Usage: balance.rb [free anime space in GB] [free long anime space in GB]\nex: balance.rb 20.5 15.8"
if ARGV.size != 2
  puts "invalid amount of arguments, please pass 2 arguments"
  puts help
end

free_anime = ARGV[0].to_f
free_long = ARGV[1].to_f
free_total = free_anime + free_long

ideal_free_anime = free_total * RATIO_ANIME
ideal_free_long = free_total * RATIO_LONG

puts "ideal_free_anime: #{ideal_free_anime}"
puts "ideal_free_long: #{ideal_free_long}"

move = ideal_free_anime - free_anime
if move > 0
  puts "move #{move} GB from anime to long"
else
  puts "move #{-move} GB from long to anime"
end

