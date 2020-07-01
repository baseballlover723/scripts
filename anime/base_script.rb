# DONE Create Base script
# DONE Create Common Base Classes (ShowGroup?, Show, Seasons, Episode)
# DONE Create Common iteration
# MOSTLY DONE Hookpoints: analyze episode, trim results, print results, analyze season?, analyze show?
# DONE Handle comparing scripts, (making multiple iterations kept seperate)
# TODO handle remote execution
#   upload files to remote
#   execute files
#   handle results
require_relative 'classes'

class BaseScript
  attr_accessor :opts, :analyze_show, :analyze_season, :analyze_episode, :results, :location, :start_time

  def initialize
    @opts = {encoding: 'UTF-8'}
    @analyze_show = true
    @analyze_season = true
    @analyze_episode = true
    @results = {}
    @start_time = Time.now
  end

  def end_time
    duration = Time.now - @start_time
    puts "Took #{duration} seconds"
  end

  def analyze_show?
    @analyze_show
  end

  def analyze_season?
    @analyze_season
  end

  def analyze_episode?
    @analyze_episode
  end

  def iterate(path)
    # @location = calc_location(path)
    puts "running on #{@location}"
    iterate_shows path
    @results
  end

  def calc_location(path)
    case path
    when /^\/mnt\/[de]/
      'local'
    when /^\/mnt\/[ghi]/
      'external'
    when /^\/mnt\/[f]/
      'long_external'
    when /^\/entertainment\//
      'remote'
    else
      'other'
    end
  end

  def iterate_shows(path)
    count = 0
    Dir.foreach path, @opts do |show_name|
      next if show_name == '.' || show_name == '..' || show_name == 'zWatched' || show_name == 'desktop.ini'
      # next unless show.start_with?

      show_path = path + '/' + show_name
      show = find_show(show_name, show_path)
      iterate_seasons show, show_path
      analyze_show(show, show_path) if analyze_show?
      count += 1
      # break if count > 20
    end
  end

  def iterate_seasons(show, path)
    root_season = find_season show, 'root', path
    iterate_episodes root_season, path
    if root_season.episodes.empty?
      show.seasons.delete(root_season.name)
    else
      analyze_season(root_season, path) if analyze_season?
    end

    Dir.foreach path, @opts do |season_name|
      next if season_name == '.' || season_name == '..' || season_name == 'desktop.ini' # || season_name.end_with?('.txt')
      season_path = path + '/' + season_name
      next unless File.directory?(season_path)

      season = find_season(show, season_name, season_path)
      iterate_episodes season, season_path
      analyze_season(season, season_path) if analyze_season?
    end
  end

  def iterate_episodes(season, path)
    Dir.foreach path, @opts do |episode_name|
      next if episode_name == '.' || episode_name == '..' || episode_name == 'desktop.ini' || episode_name.end_with?('.txt')
      episode_path = path + '/' + episode_name
      next if File.directory? episode_path

      episode = find_episode(season, episode_name, episode_path)
      analyze_episode episode, episode_path if analyze_episode?
    end
  end

  def analyze_show(show, path) end

  def analyze_season(season, path) end

  def analyze_episode(episode, path) end

  def find_show(show, path)
    show = @results[show] || Show.new(show, path)
    @results[show.name] = show
    show
  end

  def find_season(show, name, path)
    show.seasons[name] || Season.new(show, name, path)
  end

  def find_episode(season, name, path)
    name.chomp!('.filepart')
    name.chomp!('.crdownload')
    name.chomp! '.mp4'
    name.chomp! '.mkv'
    season.episodes[name] || Episode.new(season, name, path)
  end

  def trim_results
    puts 'trimming results'
    @results.each_value do |show|
      show.seasons.each_value do |season|
        season.episodes.each_value do |episode|
          season.episodes.delete(episode.name) if should_trim_episode?(episode)
        end
        show.seasons.delete(season.name) if should_trim_season?(season)
      end
      @results.delete(show.name) if should_trim_show?(show)
    end
  end

  def should_trim_show?(show)
    show.seasons.size == 0
  end

  def should_trim_season?(season)
    season.episodes.size == 0
  end

  def should_trim_episode?(episode)
    false
  end

  def self.yesno(prompt = 'Continue?', default = true)
    a = ''
    s = default ? '[Y/n]' : '[y/N]'
    d = default ? 'y' : 'n'
    until %w[y n].include? a
      original_verbosity = $VERBOSE
      $VERBOSE = nil
      a = ask("#{prompt} #{s} ") { |q| q.limit = 1; q.case = :downcase }
      $VERBOSE = original_verbosity
      a = d if a.length == 0
    end
    a == 'y'
  end
end
