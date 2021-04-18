require 'colorize'
require 'active_support'
require 'active_support/number_helper'
require 'active_support/core_ext/string/indent'
require 'shellwords'
require 'mime/types'
require 'json'
require_relative './cache'

PATH = '/mnt/d/anime'
MOVIE_PATH = '/mnt/e/movies'
TV_PATH = '/mnt/h/tv'
CACHE_PATH = 'durations.cache.json'
OPTS = {encoding: 'UTF-8'}
RESULTS = {}
TIMES = {seconds: 1000.0, minutes: 60.0, hours: 60.0, days: 24.0, months: (365.25/12), years: 12.0}
#TODO investigate why a certain scientific railgun shows up on a certain magical index iwth 47 mins?
# commit and push

def human_duration(ms, threshhold)
  prev_string = "#{ms} milliseconds"
  prev_value = ms
  TIMES.each do |unit, multi|
    return prev_string.cyan.bold if prev_value.abs / multi < threshhold
    prev_value /= multi
    prev_string = "#{prev_value.round 2} #{unit}"
  end
  prev_string
end

class Anime
  attr_accessor :name, :seasons, :all_cached

  def initialize(name)
    @name = name
    @seasons = {}
  end

  def all_cached?
    seasons.values.map(&:all_cached?).all?
  end

  def add_season(season)
    @seasons[season.name] = season
  end

  def duration
    @seasons.values.map(&:duration).inject(0, :+)
  end


  def print(out =  STDOUT)
    name_str = @name.magenta.bold
    out.puts "#{name_str}: #{human_duration duration, 1}"
    unless seasons.size == 1 && seasons.values.first.name == 'root'
      seasons.each_value do |season|
        out.puts "#{season.name}: #{human_duration season.duration, 2}".indent 4
      end
    end
  end
end

class Season
  attr_accessor :anime, :name, :episodes, :all_cached

  def initialize(anime, name)
    @anime = anime
    @name = name
    @episodes = {}
    anime.add_season self
  end

  def all_cached?
    episodes.values.map(&:cached?).all?
  end

  def add_episode(episode)
    @episodes[episode.name] = episode
  end

  def duration
    @episodes.values.map(&:duration).map(&:to_i).inject(0, :+)
  end
end

class Episode
  attr_accessor :season, :name, :duration, :cached

  def initialize(season, name)
    @season = season
    @name = name
    season.add_episode self
  end

  def cached?
    !!@cached
  end

  def to_s
    "#{File.basename(@name, '.*')} (#{duration} ms)"
  end
end

class Cache < BaseCache
  KEY = 'duration'.freeze

  def initialize(cache, path, update_duration = -1)
    super(cache, path, update_duration = -1)
  end

  def self.load_episode(path, last_modified, payload)
    CacheEpisode.new(path, last_modified, payload[KEY])
  end
end

class CacheEpisode < BaseCachePayload
  alias_attr :duration, :payload

  def initialize(path, last_modified, duration)
    super(path, last_modified, duration)
  end

  def as_json(options={})
    hash = super(options)
    hash[:duration] = duration
    hash
  end
end

def main
  $cache = Cache.load(CACHE_PATH)

  pool = Concurrent::FixedThreadPool.new(8)
  # iterate MOVIE_PATH, pool
  # iterate TV_PATH, pool
  iterate PATH + '/zWatched', pool
  iterate PATH, pool

  pool.shutdown
  pool.wait_for_termination
  $cache.write
  puts 'Done: Calculating'
end

def iterate(path, pool)
  shows = Dir.entries path, **OPTS
  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    # next unless show.start_with?('C')
    count += 1
    # break if count > 5
    pool.post do
      analyze_show show, path + '/' + show
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
    f = "#{path}/#{f}"
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f if File.directory? f
  end
  total_size
end

def analyze_show(show, path)
  anime = RESULTS[show] || Anime.new(show)
  RESULTS[anime.name] = anime
  root_season = find_season anime, 'root'
  entries = Dir.entries path, **OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_show(entry, path + '/' + entry) and next if nested_show? entry
    if File.directory?("#{path}/#{entry}")
      analyze_season find_season(anime, entry), path + '/' + entry
    else
      analyze_episode root_season, entry, path + '/' + entry
    end
  end
  if root_season.episodes.empty?
    anime.seasons.delete(root_season.name)
  end
  print "analyzed #{show}\n" unless anime.all_cached?
end

def analyze_season(season, path)
  entries = Dir.entries path, **OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry, path + '/' + entry
  end
  print "analyzed #{season.anime.name}: #{season.name}\n" unless season.all_cached?
end

def analyze_episode(season, episode_name, path)
  return if path.include?('/Featurettes') || path.include?('/Extra')
  return unless is_video?(File.extname(path))

  episode = find_episode season, episode_name
  episode.duration, episode.cached = $cache.get(path) do
    `mediainfo --ReadByHuman=0 --ParseSpeed=0 --Inform="General;%Duration%" #{Shellwords.escape(path)}`.to_i
  end
end

def nested_show?(show)
  nested_shows = ['A Certain Scientific Railgun', 'The Legend of Korra']
  nested_shows.include? show
end

def find_season(anime, name)
  anime.seasons[name] || Season.new(anime, name)
end

def find_episode(season, name)
  season.episodes[name] || Episode.new(season, name)
end

def is_video?(ext)
  MIME::Types.type_for(ext).any? {|mt| mt.media_type == 'video'}
end

def print_results
  # RESULTS.values.sort_by(&:duration).reverse.map(&:print)
  RESULTS.values.sort_by(&:duration).each do |anime|
    anime.print(STDOUT)
  end
  puts 'total'.green.bold + ': ' + human_duration(RESULTS.values.map(&:duration).inject(0, :+), 1)

  log = File.new('./durations.log', 'w')
  log.puts 'total'.green.bold + ': ' + human_duration(RESULTS.values.map(&:duration).inject(0, :+), 1)
  RESULTS.values.sort_by(&:duration).reverse.each do |anime|
    anime.print(log)
  end
end


start = Time.now
main
finish = Time.now
print_results
puts "took #{human_duration (finish - start) * 1000, 1}"
print "\a"
