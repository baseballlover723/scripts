require 'sys/filesystem'
require 'active_support'
require 'active_support/number_helper'

ANIME_PATH = "/mnt/g"
LONG_PATH = "/mnt/f"

def main
  stat_anime = Sys::Filesystem.stat(ANIME_PATH)
  stat_long = Sys::Filesystem.stat(LONG_PATH)

  cap_anime = total(stat_anime)
  cap_long = total(stat_long)
  cap_total = cap_anime + cap_long
  ratio_anime = cap_anime / cap_total
  ratio_long = cap_long / cap_total

  free_anime = free(stat_anime)
  free_long = free(stat_long)
  free_total = free_anime + free_long

  ideal_free_anime = free_total * ratio_anime
  ideal_free_long = free_total * ratio_long


  puts "ideal_free_anime: #{human_size(ideal_free_anime)}"
  puts "ideal_free_long: #{human_size(ideal_free_long)}"

  move = ideal_free_anime - free_anime
  if move > 0
    puts "move #{human_size(move)} from anime to long"
  else
    puts "move #{human_size(-move)} from long to anime"
  end
end

def total(stat)
  stat.block_size * stat.blocks.to_f
end

def free(stat)
  stat.block_size * stat.blocks_available.to_f
end

def human_size(size)
  ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5, strip_insignificant_zeros: false})
end

main
