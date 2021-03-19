require 'fileutils'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'

PATH = '/mnt/d/anime'
# PATH = '/mnt/g/anime'
# PATH = '/entertainment/tv'
OPTS = { encoding: 'UTF-8' }
SHOWS = {}
RESULTS = []

PARTITION_SIZE = 1300 * 1024 * 1024 * 1024
# PARTITION_SIZE = 1500 * 1024 * 1024 * 1024
BUFFER_SIZE = 55 * 1024 * 1024 * 1024
TRANSFER_SIZE = PARTITION_SIZE - BUFFER_SIZE
OTHER_FILES_SIZE = 325 * 1024 * 1024 * 1024

class Anime
  attr_accessor :name, :bytes

  def initialize(name, bytes)
    @name = name
    @bytes = bytes
  end

  def size
    ActiveSupport::NumberHelper.number_to_human_size(@bytes, { precision: 5, strip_insignificant_zeros: false })
  end

  def to_s
    "#{@name.cyan}: #{size}"
  end
end

class Group
  attr_accessor :animes, :number
  @@count = 0

  def initialize(animes = [], number = nil)
    @animes = animes
    if number.nil?
      @@count += 1
      @number = @@count.to_s
    else
      @number = number
    end
  end

  def bytes
    animes.sum(&:bytes)
  end

  def size
    ActiveSupport::NumberHelper.number_to_human_size(bytes, { precision: 5, strip_insignificant_zeros: false })
  end

  def to_s
    if animes.empty?
      "Group ##{number.to_s.cyan} (empty)"
    else
      "Group ##{number.to_s.cyan} (#{size}): \"#{animes.first.name}\" - \"#{animes.last.name}\""
    end
  end
end

def main
  shows = Dir.entries PATH, OPTS
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini' || show == 'format.txt'
    calculate_size show
  end
  PATH << '/zWatched'
  watched_shows = Dir.entries PATH, OPTS
  watched_shows.each do |show|
    next if show == '.' || show == '..' || show == 'desktop.ini'
    calculate_size show
  end

  RESULTS.sort_by! { |a| a.name.downcase }
  print "\r".ljust(120)
  print "\r"

  # buffer_size = BUFFER_SIZE
  # transfer_size = TRANSFER_SIZE
  # plus_minus = 20
  #
  # buffer_sizes = (-plus_minus..plus_minus).map do |buffer_adjustment|
  #   puts "#{buffer_adjustment} GiB Buffer Adjustment"
  #   buffer_size = BUFFER_SIZE + buffer_adjustment * 1024 * 1024 * 1024
  #   transfer_size = PARTITION_SIZE - buffer_size
  #   [ buffer_adjustment, calculate_groups(RESULTS.clone, PARTITION_SIZE, buffer_size, transfer_size, OTHER_FILES_SIZE) ]
  # end.to_h.sort_by { |k, v| [v, k.abs] }
  #
  # puts "\n********************************\n\n"
  # buffer_sizes.each do |adjustment, std_deviation|
  #   puts "#{adjustment}: #{human_size(std_deviation)}"
  # end

  calculate_groups(RESULTS.clone, PARTITION_SIZE, BUFFER_SIZE, TRANSFER_SIZE, OTHER_FILES_SIZE)
end

def calculate_groups(animes, partition_size, buffer_size, transfer_size, other_files_size)
  animes.unshift(Anime.new('other files', other_files_size))
  total_size = animes.sum(&:bytes)
  puts Anime.new('total size', total_size)
  puts Anime.new('Partition size', partition_size)
  puts Anime.new('Buffer size', buffer_size)
  puts Anime.new('Transfer size', transfer_size)

  numb_transfers = total_size / transfer_size.to_f
  puts "numb_transfers: #{numb_transfers}"
  current_group = Group.new()
  groups = [current_group]

  animes.each do |anime|
    if (current_group.bytes + anime.bytes) >= transfer_size
      current_group = Group.new()
      groups << current_group
    end
    current_group.animes << anime
  end

  puts "\nUnbalanced Groups\n\n"
  groups.each do |group|
    puts group
  end
  puts "std_deviation: #{human_size standard_deviation(groups)}"

  groups = balance_groups(groups)

  puts "\nBalanced Groups\n\n"
  groups.each do |group|
    puts group
  end
  puts "std_deviation: #{human_size standard_deviation(groups)}"
  puts

  # puts "\nRight Weighted Groups\n\n"
  # transfer_left_to_right(groups[0], groups[1])
  # groups.each do |group|
  #   puts group
  # end
  # puts "std_deviation: #{human_size standard_deviation(groups)}"
  # transfer_right_to_left(groups[0], groups[1])
  #
  # puts "\nLeft Weighted Groups\n\n"
  # transfer_right_to_left(groups[0], groups[1])
  # groups.each do |group|
  #   puts group
  # end
  # puts "std_deviation: #{human_size standard_deviation(groups)}"
  # transfer_left_to_right(groups[0], groups[1])
  standard_deviation(groups)
end

def balance_groups(groups)
  loop do
    made_changes = false
    groups.each_cons(2) do |group1, group2|
      made_changes ||= balance_left_to_right(groups, group1, group2)
      made_changes ||= balance_right_to_left(groups, group1, group2)
    end
    return groups unless made_changes
  end
end

def human_size(n)
  ActiveSupport::NumberHelper.number_to_human_size(n, { precision: 5, strip_insignificant_zeros: false })
end

def balance_left_to_right(groups, group1, group2)
  omnibalance(groups, group1, group2, ->(l, r) { transfer_left_to_right(l, r) }, ->(l, r) { transfer_right_to_left(l, r) })
end

def balance_right_to_left(groups, group1, group2)
  omnibalance(groups, group1, group2, ->(l, r) { transfer_right_to_left(l, r) }, ->(l, r) { transfer_left_to_right(l, r) })
end

def omnibalance(groups, group1, group2, forwards, backwards)
  made_changes = false
  current = standard_deviation(groups)

  loop do
    forwards.call(group1, group2)
    prev = current
    current = standard_deviation(groups)
    # puts "\nprev: #{human_size prev}, current: #{human_size current}"
    if (current > prev)
      backwards.call(group1, group2)
      return made_changes
    end
    made_changes = true
  end
end

def transfer_left_to_right(group1, group2)
  anime = group1.animes.pop
  # puts "moving #{anime.name} from group ##{group1.number} to group ##{group2.number}".light_green
  group2.animes.unshift(anime)
end

def transfer_right_to_left(group1, group2)
  anime = group2.animes.shift
  # puts "moving #{anime.name} from group ##{group2.number} to group ##{group1.number}".light_red
  group1.animes << anime
end

def standard_deviation(groups)
  mean = groups.sum(&:bytes) / groups.size.to_f
  variance = (groups.inject(0) { |accum, group| accum + (group.bytes - mean) ** 2 }) / (groups.size - 1).to_f
  Math.sqrt(variance)
end

def directory_size(path)
  # path << '/' unless path.end_with?('/')

  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'zWatched' || f == 'desktop.ini'
    # next unless f.include?(File.basename(path))
    # puts "f: #{f}"
    f = "#{path}/#{f}"
    # puts "basename: #{File.basename path}"
    # puts "path: #{path}"
    # puts f
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f if File.directory? f
  end
  total_size
end

# f: 26.mp4
# basename: Season 2 (Dark Tournament Saga)
# path: /mnt/d/anime/Yu Yu Hakusho; Ghost Files/Season 2 (Dark Tournament Saga)
# /mnt/d/anime/Yu Yu Hakusho; Ghost Files/Season 2 (Dark Tournament Saga)/26.mp4

def calculate_size(show)
  print "\rcalculating size for #{show}".ljust(120)
  size = directory_size "#{PATH}/#{show}"
  if SHOWS.include? show
    anime = SHOWS[show]
    anime.bytes += size
  else
    anime = Anime.new(show, size)
    RESULTS << anime
    SHOWS[anime.name] = anime
  end
end

start = Time.now
main
puts "Took #{Time.now - start} seconds"

