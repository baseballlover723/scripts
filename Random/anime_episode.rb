PATH = 'D:\anime'
OPTS = {encoding: 'UTF-8'}
RESULTS = {}
require 'set'
require 'pp'

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
    @episodes = Set.new
    anime.add_season self
  end

  def add_episode(episode)
    @episodes << episode
  end

  def missing_episodes
    return [] if @episodes.empty?
    miss_episodes = []
    last_episode_num = @episodes.max.to_i
    first_episode_num = @episodes.min.to_i
    first_episode_num.upto(last_episode_num).each do |check_episode|
      miss_episodes << check_episode unless @episodes.include? check_episode.to_f
    end
    miss_episodes.sort
  end
end

def main
  shows = Dir.entries PATH, OPTS

  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    # count += 1 and next if count < 4
    analyze_show show
    count += 1
    # break if count > 6
  end
  PATH << '/zWatched'
  watched_shows = Dir.entries PATH, OPTS
  watched_shows.each do |show|
    next if show == '.' || show == '..' || show == 'desktop.ini'
    analyze_show show
  end
end

def analyze_show(show)
  # puts "analyzing #{show}"
  anime = RESULTS[show] || Anime.new(show)
  RESULTS[anime.name] = anime

  root_season = Season.new(anime, 'root')
  entries = Dir.entries "#{PATH}/#{anime.name}", OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    if File.directory?("#{PATH}/#{anime.name}/#{entry}")
      analyze_season Season.new(anime, entry)
    else
      analyze_episode root_season, entry
    end
  end
  if root_season.episodes.empty?
    anime.seasons.delete(root_season.name)
  end
end

def analyze_season(season)
  # puts "analyzing #{season.anime.name}: #{season.name}"
  entries = Dir.entries "#{PATH}/#{season.anime.name}/#{season.name}", OPTS
  entries.each do |entry|
    # puts entry
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry
  end
end

def analyze_episode(season, episode_name)
  season.add_episode(episode_name.to_f) if episode_name.to_f != 0 || episode_name.start_with?('0')
  if episode_name.include? '&'
    season.add_episode(episode_name.split('&')[1].to_f)
  end
end

def trim_results
  RESULTS.each_value do |anime|
    anime.seasons.each_value do |season|
      anime.seasons.delete(season.name) if season.missing_episodes.empty?
    end
    RESULTS.delete(anime.name) if anime.seasons.empty?
  end
end

def print_results
  RESULTS.each_value do |anime|
    puts ''
    if anime.seasons.length == 1 && anime.seasons[:root]
      puts "#{anime.name}: #{anime.seasons[:root].missing_episodes}"
    else
      anime.seasons.each_value do |season|
        puts "#{anime.name}#{' ' + season.name unless season.name == 'root'}: #{season.missing_episodes}"
      end
    end
  end
  puts ''
end

main
trim_results
print_results
