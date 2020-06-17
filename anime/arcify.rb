# requires arcifyd files
require 'colorize'
require 'pp'
require 'highline/import'
require 'fileutils'
require 'set'
require_relative 'arcs'

# PATH = '/mnt/c/Users/Philip Ross/Downloads/Naruto; Shippūden/'
PATH = '/mnt/c/Users/Philip Ross/Downloads/World Trigger (Copy)/'
# PATH = '/mnt/f/anime/Black Clover (In Progress)/'
# PATH = '../../raided/Naruto/'
PATH << '/' unless PATH.end_with? '/'
OPTS = {encoding: 'UTF-8'}
RESULTS = []
FILES = {}
ARCS = ALL_ARCS[File.basename(PATH).split(/ \(/, 2).first]
# 1.upto(500).each do |numb|
#   File.open(PATH + numb.to_s + '.mkv', 'w')
# end

puts("Could not find directory at #{PATH}") || exit unless File.directory? PATH

ARCS.keys.select {|a| a.is_a? Range}.each_cons(2) do |last, current|
  if last.last >= current.first
    puts "Bad Arc Order '#{current}' is after '#{last}'".light_red
    exit
  end
end

IGNORE_FOLDERS = [
  'Movies',
]
IGNORE_PREFIX = '[bonkai77]'

# puts ARCS.pretty_inspect

def main
  puts ''
  gather_files PATH

  puts "Arcifying #{File.basename(PATH).light_cyan}"
  if yesno(verify_arcify)
    arcify PATH
  end
end

def gather_files(path)
  Dir.glob(escape_glob(path) + "**/*").sort.each do |f|
    next unless File.file? f
    directory_name = File.basename File.dirname f
    next if IGNORE_FOLDERS.include? directory_name
    next if f.end_with?('.enc')

    filename = File.basename(f)
    filename = filename[IGNORE_PREFIX.length..-1] if filename.start_with?(IGNORE_PREFIX)

    episode_number = filename[/\d+/].to_i
    FILES[episode_number] = f
  end
end

def verify_arcify
  missing_episodes = []
  non_arced_episodes = []

  ARCS.keys.each do |episode_range|
    next unless episode_range.is_a? Range
    episode_range.each do |numb|
      missing_episodes << numb unless FILES.include? numb
    end
  end
  if missing_episodes.empty?
    puts 'Found all episodes in arcs on disk'.light_green
  else
    puts "Can't find episodes on disk: #{missing_episodes.map(&:to_s).map(&:light_red).join(', ')}"
  end

  FILES.keys.each do |numb|
    non_arced_episodes << numb unless ARCS[numb]
  end

  if non_arced_episodes.empty?
    puts 'All episodes on disk have an arc'.light_green
  else
    puts "Can't find an arc for episodes: #{non_arced_episodes.map(&:to_s).map(&:light_red).join(', ')}"
  end

  missing_episodes.empty? && non_arced_episodes.empty?
end

def arcify(path)
  movie_arcs = Set.new
  ARCS.each_with_index do |(episode_range, arc_name), index|
    folder_name = "Arc #{index + 1} (#{arc_name})/"
    folder_name = folder_name.gsub(/ filler\)\/\z/, ') (Non-Canon)/')
    folder_name = folder_name.gsub(/ \(\)/, '')
    FileUtils.mkdir_p(path + folder_name)
    movie_arcs << path + folder_name if episode_range.is_a?(String) && episode_range.start_with?('movie')
    next unless episode_range.is_a? Range
    episode_range.each do |episode_number|
      file = FILES[episode_number]
      next unless file
      File.rename file, path + folder_name + File.basename(file)
    end
  end
  Dir.glob(escape_glob(path) + "*").each do |f|
    next if movie_arcs.include? f + '/'
    Dir.rmdir(f) if Dir.empty?(f)
  end
  puts "Done Arcifying #{File.basename(path).light_cyan}"
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) {|x| "\\"+x}
end

def yesno(default = true, prompt = 'Continue?')
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until %w[y n].include? a
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    a = ask("#{prompt} #{s} ") {|q| q.limit = 1; q.case = :downcase}
    $VERBOSE = original_verbosity
    a = d if a.length == 0
  end
  a == 'y'
end

main
