require 'streamio-ffmpeg'
require 'json'

PATH = 'D:\anime'
OPTS = {encoding: 'UTF-8'}
RESULTS = {}

class Anime
  attr_accessor :name, :seasons

  def initialize(name)
    @name = name
    @seasons = {}
  end

  def add_season(season)
    @seasons[season.name] = season
  end

  def inspect
    @seasons.size == 1 ? @seasons.values.first.inspect : @seasons
  end

  def to_json(state)
    seasons = {resolutions: resolutions}
    seasons.merge! @seasons
    @seasons.size == 1 ? @seasons.values.first.to_json(state) : seasons.to_json(state)
  end

  def resolutions
    @seasons.values.map(&:resolutions).inject({}) { |h1, h2| h1.merge(h2) { |res, count1, count2| count1+count2 } }
  end
end

class Season
  attr_accessor :anime, :name, :episodes

  def initialize(anime, name)
    @anime = anime
    @name = name
    @episodes = Hash.new { |h, k| h[k] = [] }
    anime.add_season self
  end

  def add_episode(episode)
    @episodes[episode.resolution] << episode
  end

  def resolutions
    hash = Hash.new(0)
    @episodes.each do |resolution, episodes|
      hash[resolution] = episodes.size
    end
    hash
  end

  def inspect
    @name == 'root' ? {resolutions: resolutions, episodes: @episodes} : {name: @name, resolutions: resolutions, episodes: @episodes}
  end

  def to_json(state)
    (@name == 'root' ? {resolutions: resolutions, episodes: @episodes} : {name: @name, resolutions: resolutions, episodes: @episodes}).to_json
  end
end

class Episode
  attr_accessor :season, :name, :resolution

  def initialize(season, name, resolution)
    @season = season
    @name = name
    @resolution = resolution
    season.add_episode self
  end

  def inspect
    @name.chomp('.mp4')
  end

  def to_json(state)
    '"' + @name.chomp('.mp4') + '"'
  end
end

def main
  shows = Dir.entries PATH, OPTS

  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched'
    # count += 1 and next if count < 4
    analyze_show show
    count += 1
    # break if count > 4
  end
    PATH << '/zWatched'
    watched_shows = Dir.entries PATH, OPTS
    watched_shows.each do |show|
      next if show == '.' || show == '..' || show == 'desktop.ini'
      analyze_show show
    end
end

def analyze_show(show)
  puts "analyzing #{show}"
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
  puts "analyzing #{season.anime.name}: #{season.name}"
  entries = Dir.entries "#{PATH}/#{season.anime.name}/#{season.name}", OPTS
  entries.each do |entry|
    # puts entry
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry
  end
end

def analyze_episode(season, episode_name)
  path = season.name == 'root' ? "#{PATH}/#{season.anime.name}/#{episode_name}" : "#{PATH}/#{season.anime.name}/#{season.name}/#{episode_name}"
  raw_episode = FFMPEG::Movie.new path
  episode = Episode.new(season, episode_name, raw_episode.height)

end

start = Time.now
main
RESULTS.reject!{|a| RESULTS[a].resolutions.size == 1}
File.open("anime.json", "w") do |f|
  f.write(JSON.pretty_generate(RESULTS))
  # f.write(RESULTS)
end
puts RESULTS
finish = Time.now
puts "took #{finish - start} seconds"
