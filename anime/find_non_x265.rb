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
CACHE_PATH = 'find_non_x265s.cache.json'
OPTS = {encoding: 'UTF-8'}
RESULTS = {}
SIZES = {KB: 1024.0, MB: 1024.0, GB: 1024.0, TB: 1024.0}
EXCLUDED_CODECS = ['x265']
SEEN_CODECS = Set.new
EXCEPTIONS = {}
$numb_files = 0

def human_size(bytes, threshhold)
  prev_string = "#{bytes} Bytes"
  prev_value = bytes
  SIZES.each do |unit, multi|
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

  def size
    @seasons.values.map(&:size).inject(0, :+)
  end

  def numb_files
    @seasons.values.map(&:numb_files).inject(0, :+)
  end

  def print(out = STDOUT)
    name_str = @name.magenta.bold
    out.puts "#{name_str}: #{human_size size, 1} (#{numb_files} files)"
    unless seasons.size == 1 && seasons.values.first.name == 'root'
      seasons.each_value do |season|
        out.puts "#{season.name}: #{human_size season.size, 2} (#{season.numb_files} files)".indent 4
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

  def size
    @episodes.values.map(&:size).map(&:to_i).inject(0, :+)
  end

  def numb_files
    @episodes.size
  end
end

class Episode
  attr_accessor :season, :name, :size, :codec, :cached

  def initialize(season, name)
    @season = season
    @name = name
    season.add_episode self
  end

  def cached?
    !!@cached
  end

  def to_s
    "#{File.basename(@name, '.*')} (#{size} Bytes) {#{codec}}"
  end
end

class Cache < BaseCache
  def initialize(cache)
    super(cache)
  end

  def self.load_episode(path, last_modified, payload)
    CacheEpisode.new(path, last_modified, payload)
  end

  def write(path=CACHE_PATH)
    super(path)
  end
end

CODEC_KEY = 'codec'.freeze
SIZE_KEY = 'size'.freeze
class CacheEpisode < BaseCachePayload

  def initialize(path, last_modified, payload)
    super(path, last_modified, payload)
  end

  def codec
    payload[CODEC_KEY]
  end

  def codec=(codec)
    payload[CODEC_KEY] = codec
  end

  def size
    payload[SIZE_KEY]
  end

  def size=(size)
    payload[SIZE_KEY] = size
  end

  def as_json(options={})
    hash = super(options)
    hash[:codec] = codec
    hash[:size] = size
    hash
  end
end

def main
  $cache = Cache.load(CACHE_PATH)

  pool = Concurrent::FixedThreadPool.new(16)
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
    count += 1
    # break if count > 5
    pool.post do
      begin
        analyze_show show, path + '/' + show
      rescue Exception => e
        EXCEPTIONS[show] = e
      end
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
  data, cached = $cache.get(path) do
    {CODEC_KEY => extract_codec(path), SIZE_KEY => File.size(path)}
  end
  episode.size = data[SIZE_KEY]
  episode.codec = data[CODEC_KEY]
  episode.cached = cached
  SEEN_CODECS << data[CODEC_KEY]
end

def extract_codec(path)
  codec = `mediainfo --ReadByHuman=0 --ParseSpeed=0 --Inform="Video;%InternetMediaType%" #{Shellwords.escape(path)}`.strip
  codec = codec.sub('video/', '') if codec.start_with?('video/')
  codec = codec[/H\d\d\d/].sub('H', 'x') if codec[/H\d\d\d/]

  $numb_files += 1

  codec
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
  MIME::Types.type_for(ext).any? { |mt| mt.media_type == 'video' }
end

def should_exclude(codec)
  EXCLUDED_CODECS.include? codec
end

def trim_results
  RESULTS.each_value do |show|
    show.seasons.each_value do |season|
      season.episodes.each_value do |episode|
        season.episodes.delete(episode.name) if should_exclude episode.codec
      end
      show.seasons.delete(season.name) if season.episodes.size == 0
    end
    RESULTS.delete(show.name) if show.seasons.size == 0
  end
end

def print_results
  log = File.new('./find_non_x265_log.log', 'w')
  log.puts 'total'.green.bold + ': ' + human_size(RESULTS.values.map(&:size).inject(0, :+), 1)
  RESULTS.values.sort_by(&:size).reverse.each do |anime|
    anime.print(log)
  end

  # RESULTS.values.sort_by(&:size).reverse.map(&:print)
  RESULTS.values.sort_by(&:size).each do |anime|
    anime.print(STDOUT)
  end
  puts 'total'.green.bold + ': ' + human_size(RESULTS.values.map(&:size).inject(0, :+), 1)
end

start = Time.now
main
trim_results
# save_results
finish = Time.now
print_results
if !EXCEPTIONS.empty?
  EXCEPTIONS.each do |show, exception|
    puts "\n*********************************\n\n"
    puts exception.full_message
    puts show.red.bold + ': ' + exception.message
  end
  puts 'Erroring shows: ["' + EXCEPTIONS.keys.map(&:to_s).map(&:red).map(&:bold).join('", "') + '"]'
end
puts "Codecs Seen: #{SEEN_CODECS.inspect}"
avg_time = (finish - start) * 1000.0 / $numb_files
puts "averaged #{avg_time.round(3)} ms per file (#{ActiveSupport::NumberHelper.number_to_delimited $numb_files} files)"
puts "took #{finish - start} seconds"
print "\a"
