if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
  require 'colorize'
  require 'active_support'
  require 'active_support/number_helper'
  require 'active_support/core_ext/string/indent'
end

REMOTE = !ARGV.empty?
LOCAL_PATH = '/mnt/d/anime'
EXTERNAL_PATH = '/mnt/f/anime'
REMOTE_PATH = '../../raided/anime'
OPTS = {encoding: 'UTF-8'}
RESULTS = {}

class String
  def local_color
    replace self.light_green
  end

  def remote_color
    replace self.light_red
  end

  def external_color
    replace self.light_magenta
  end

  def uncolor
    replace self.uncolorize
  end
end

class Anime
  attr_accessor :name, :seasons

  def initialize(name)
    @name = name
    @seasons = {}
  end

  def add_season(season)
    @seasons[season.name] = season
  end
end

class Season
  attr_accessor :anime, :name, :episodes

  def initialize(anime, name)
    @anime = anime
    @name = name
    @episodes = {}
    anime.add_season self
  end

  def add_episode(episode)
    @episodes[episode.name] = episode
  end
end

class Episode
  attr_accessor :season, :name, :local_size, :remote_size, :external_size

  def initialize(season, name)
    @season = season
    @name = name
    @local_size = 0
    @remote_size = 0
    @external_size = 0
    season.add_episode self
  end

  def h_size(size)
    ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5, strip_insignificant_zeros: false})
  end

  def to_s
    local_size = h_size(@local_size)
    remote_size = h_size(@remote_size)
    external_size = h_size(@external_size)
    local_size.local_color unless @local_size == @remote_size || @local_size == @external_size
    remote_size.remote_color unless @remote_size == @local_size || @remote_size == @external_size
    external_size.external_color unless @external_size == @local_size || @external_size == @remote_size
    if @remote_size == 0 && @external_size == 0
      local_size.uncolor
      remote_size.remote_color
      external_size.external_color
    end
    if @local_size == 0 && @external_size == 0
      local_size.local_color
      remote_size.uncolor
      external_size.external_color
    end
    if @local_size == 0 && @remote_size == 0
      local_size.local_color
      remote_size.remote_color
      external_size = external_size.uncolorize
    end
    # TODO use file basename or something to remvove extension
    "#{@name.split('.')[0].cyan}: #{local_size} (#{remote_size}) [#{external_size}]"
  end
end

def main
  Net::SSH.start(ENV['OVERMIND_HOST'], ENV['OVERMIND_USER'], password: ENV['OVERMIND_PASSWORD']) do |ssh|
    ssh.sftp.connect do |sftp|
      sftp.upload!(__FILE__, "remote.rb")
    end
    puts 'running on remote'
    serialized_results = ssh.exec! "source ~/.rvm/scripts/rvm; ruby remote.rb remote"
    RESULTS.replace Marshal::load(serialized_results)
    ssh.exec! "rm remote.rb"
  end
  puts 'running locally'
  iterate LOCAL_PATH, 'local'
  iterate LOCAL_PATH + '/zWatched', 'local'
  iterate EXTERNAL_PATH, 'external'
  iterate EXTERNAL_PATH + '/zWatched', 'external'
end

def iterate(path, type)
  shows = Dir.entries path, OPTS
  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    analyze_show show, path + '/' + show, type
    count += 1
    # break if count > 5
  end
end

def analyze_show(show, path, type)
  anime = RESULTS[show] || Anime.new(show)
  RESULTS[anime.name] = anime
  root_season = find_season anime, 'root'
  entries = Dir.entries path, OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_show(entry, path + '/' + entry, type) or next if entry == 'A Certain Scientific Railgun'
    if File.directory?("#{path}/#{entry}")
      analyze_season find_season(anime, entry), path + '/' + entry, type
    else
      analyze_episode root_season, entry, path + '/' + entry, type
    end
  end
  if root_season.episodes.empty?
    anime.seasons.delete(root_season.name)
  end
end

def analyze_season(season, path, type)
  entries = Dir.entries path, OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry, path + '/' + entry, type
  end
end

def analyze_episode(season, episode_name, path, type)
  episode_name.chomp!('.filepart')
  episode_name.chomp!('.crdownload')
  episode = find_episode season, episode_name
  episode.send(type + '_size=', File.size(path))
end

def remote_main
  iterate(REMOTE_PATH, 'remote')
  puts Marshal::dump(RESULTS)
end

def find_season(anime, name)
  anime.seasons[name] || Season.new(anime, name)
end

def find_episode(season, name)
  season.episodes[name] || Episode.new(season, name)
end

def trim_results
  RESULTS.each_value do |show|
    show.seasons.each_value do |season|
      season.episodes.each_value do |episode|
        season.episodes.delete(episode.name) if episode.local_size == episode.remote_size && episode.local_size == episode.external_size
      end
      show.seasons.delete(season.name) if season.episodes.size == 0
    end
    RESULTS.delete(show.name) if show.seasons.size == 0
  end
end

def print_results
  original_verbosity = $VERBOSE
  $VERBOSE = nil
  cols = `tput cols`.to_i
  $VERBOSE = original_verbosity
  print "local size".local_color
  print " ("
  print "remote size".remote_color
  print ") ["
  print "external size".external_color
  print "]\n"

  shows = RESULTS.values.sort_by(&:name)
  shows.each do |show|
    puts show.name
    show.seasons.each_value do |season|
      puts season.name.indent 4 unless season.name == 'root'
      indent_size = season.name == 'root' ? 4 : 8
      str = ''
      episodes = season.episodes.values.sort_by { |e| e.name.to_f == 0 ? 9999 : e.name.to_f }
      episodes.each do |episode|
        episode_str = episode.to_s
        if (str + "#{episode_str}, ").uncolorize.length + indent_size < cols
          str += "#{episode_str}, "
        else
          puts str.indent indent_size
          str = "#{episode_str}, "
        end
      end
      puts str.indent indent_size
    end
  end
end

if ARGV.empty?
  start = Time.now
  main
  trim_results
  print_results
  puts "Took #{Time.now - start} seconds"
else
  remote_main
end
