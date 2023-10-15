require 'fileutils'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'

# PATH = '/mnt/d/anime'
PATH = '/mnt/g/anime'
# PATH = '/mnt/e/movies'
# PATH = '/mnt/e/tv'
# PATH = '/entertainment/tv'
OPTS = {encoding: 'UTF-8'}
SHOWS = {}
RESULTS = []

class Anime
  attr_accessor :name, :bytes

  def initialize(name, bytes)
    @name = name
    @bytes = bytes
  end

  def size
    ActiveSupport::NumberHelper.number_to_human_size(@bytes, {precision: 5, strip_insignificant_zeros: false})
  end

  def to_s
    "#{@name.cyan}: #{size}"
  end
end

def main
  iterate(PATH)
  iterate(PATH + '/zWatched')
end

def iterate(path)
  return unless File.directory?(path)
  shows = Dir.entries path, **OPTS
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini' || show == 'format.txt'
    if path.include?("movies")
      if show_group?(show)
        iterate(path + '/' + show)
      else
        calculate_size path, show
      end
    else
      calculate_size path, show
    end
  end
end

def directory_size(path)
  # path << '/' unless path.end_with?('/')

  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, **OPTS
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

def calculate_size(path, show)
  print "\rcalculating size for #{show}".ljust(120)
  size = directory_size "#{path}/#{show}"
  if SHOWS.include? show
    anime = SHOWS[show]
    anime.bytes += size
  else
    anime = Anime.new(show, size)
    RESULTS << anime
    SHOWS[anime.name] = anime
  end
end

def show_group?(name)
  # matches (####) [####.]
  !name.match /\(\d{4}\) \[\d+.\]/
end

start = Time.now
main
RESULTS.sort_by(&:name)
# File.open('./anime.log', 'w') do |file|
#   RESULTS.each do |anime|
#     file.puts(anime.name)
#   end
# end
# RESULTS.sort_by!(&:bytes).reverse!
RESULTS.sort_by!(&:bytes)
# RESULTS.sort_by!(&:name)
print "\r".ljust(120)
print "\r"
total = 0
RESULTS.each do |result|
  next if result.bytes < 1024 * 1024 * 1024 * 20
  # next if result.name.include?('x265')
  # next if result.name.include?('1080p') || result.name.include?('2160p')
  # next unless result.name.include?('1080p')
  # next unless result.name.include?('2160p')
  puts result unless result.bytes == 0
  total += result.bytes
end
a = Anime.new('total', total)
puts a
puts "Took #{Time.now - start} seconds"

