require 'fileutils'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'

SHORT_PATH = '/mnt/g/anime'
LONG_PATH = '/mnt/f/anime'
LIMIT = 1024 * 1024 * 1024 * 18
OPTS = {encoding: 'UTF-8'}

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
  short_results = iterate_drive(SHORT_PATH, true)
  long_results = iterate_drive(LONG_PATH, false)
  print "\r".ljust(120)
  print "\r"

  puts "LIMIT: #{ActiveSupport::NumberHelper.number_to_human_size(LIMIT).green}"
  print_results(short_results, true)
  puts
  print_results(long_results, false)
end

def iterate_drive(path, short)
  results = []
  show_cache = {}
  iterate(path, results, show_cache, short)
  iterate(path + '/zWatched', results, show_cache, short)
  results
end

def iterate(path, results, show_cache, short)
  return unless File.directory?(path)
  shows = Dir.entries path, **OPTS
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini' || show == 'format.txt'
    calculate_size results, show_cache, path, show, short
  end
end

def directory_size(path)
  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, **OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'zWatched' || f == 'desktop.ini'
    f = "#{path}/#{f}"
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f if File.directory? f
  end
  total_size
end

def calculate_size(results, show_cache, path, show, short)
  print "\rcalculating size for #{short ? "short" : "long"} #{show}".ljust(120)
  size = directory_size "#{path}/#{show}"
  if show_cache.include? show
    anime = show_cache[show]
    anime.bytes += size
  else
    anime = Anime.new(show, size)
    results << anime
    show_cache[anime.name] = anime
  end
end

def print_results(results, short)
  results.sort_by!(&:bytes)
  results.reverse! if !short
  # results.sort_by!(&:name)

  puts "#{short ? "short" : "long"} -> #{short ? "long" : "short"}"
  puts

  total = 0
  results.each do |result|
    next if (short && result.bytes < LIMIT) || (!short && result.bytes > LIMIT)
    puts result unless result.bytes == 0
    total += result.bytes
  end
  a = Anime.new("total #{short ? "short" : "long"}", total)
  puts a
end

start = Time.now
main
puts "Took #{Time.now - start} seconds"
