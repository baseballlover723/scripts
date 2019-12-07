require 'mediainfo'
require 'concurrent'
require 'colorize'
require 'active_support/core_ext/string/indent'

PATH = '/mnt/d/anime'
# PATH = '/mnt/e/tv'
OPTS = {encoding: 'UTF-8'}
RESULTS = {}
# not light for work around with ansi colors in the log file
COLORS = {360 => :yellow, 480 => :magenta, 720 => :cyan, 1080 => :green, :other => :red}

class String
  def uncolor
    replace self.light_black
  end

  def paint(size)
    color_key = COLORS.include?(size) ? size : :other
    replace send(COLORS[color_key]).bold
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

  def resolutions
    @seasons.values.map(&:resolutions).inject({}) { |h1, h2| h1.merge(h2) { |res, count1, count2| count1+count2 } }
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

  def resolutions
    hash = Hash.new(0)
    @episodes.each do |_name, episode|
      hash[episode.resolution] += 1
    end
    hash
  end

  def highest_resolution
    resolutions.keys.max
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

  def to_s
    name = "#{File.basename(@name, '.*')} (#{resolution}p)"
    name.paint @resolution
  end
end

def main
  shows = Dir.entries PATH, OPTS

  count = 0
  pool = Concurrent::FixedThreadPool.new(8)
  # watched_shows = Dir.entries PATH + '/zWatched', OPTS
  # watched_shows.each do |show|
  #   next if show == '.' || show == '..' || show == 'desktop.ini'
  #   pool.post do
  #     analyze_show show, PATH + '/zWatched'
  #   end
  #   count += 1
  #   # break if count > 4
  # end
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched'
    # count += 1 and next if count < 4
    pool.post do
      analyze_show show, PATH
    end
    break
    count += 1
    # break if count > 4
  end
  pool.shutdown
  pool.wait_for_termination
end

def analyze_show(show, path)
  anime = RESULTS[show] || Anime.new(show)
  RESULTS[anime.name] = anime
  root_season = Season.new(anime, 'root')
  entries = Dir.entries "#{path}/#{anime.name}", OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_show(entry, path + '/' + anime.name) and next if nested_show? entry
    if File.directory?("#{path}/#{anime.name}/#{entry}")
      analyze_season Season.new(anime, entry), path
      break
    else
      analyze_episode root_season, entry, path
      break
    end
  end
  if root_season.episodes.empty?
    anime.seasons.delete(root_season.name)
  end
  print "analyzed #{show}\n"
end

def analyze_season(season, path)
  entries = Dir.entries "#{path}/#{season.anime.name}/#{season.name}", OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry, path
    break
  end
  print "analyzed #{season.anime.name}: #{season.name}\n"
end

def analyze_episode(season, episode_name, path)
  puts episode_name
  begin
  path = season.name == 'root' ? "#{path}/#{season.anime.name}/#{episode_name}" : "#{path}/#{season.anime.name}/#{season.name}/#{episode_name}"
  raw_episode = Mediainfo.new path
  puts raw_episode.inspect
  puts raw_episode.video?
  puts raw_episode.raw_response
  # puts raw_episode.video_stream.height
  episode = Episode.new(season, episode_name, raw_episode.video.height)
  rescue Exception => e
    puts "hello"
    puts "Error during processing: #{$!}"
    puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    # puts caller
  end
end

def nested_show?(show)
  nested_shows = ['A Certain Scientific Railgun', 'The Legend of Korra']
  nested_shows.include? show
end

class DoublePrinter
  def initialize(*targets)
    @targets = targets
  end

  def print(*args)
    @targets.each { |t| t.print(*args) }
  end

  def puts(*args)
    @targets.each { |t| t.puts(*args) }
  end

  def close
    @targets.each(&:close)
  end
end

def trim_results
  RESULTS.each do |_, anime|
    anime.seasons.each do |_, season|
      anime.seasons.delete(season.name) if season.resolutions.size == 1
    end
    RESULTS.delete(anime.name) if anime.seasons.empty?
  end
end

def print_results
  File.open('resolutions_log.log', 'w') do |log_file|
    log = DoublePrinter.new $stdout, log_file
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    cols = `tput cols`.to_i
    $VERBOSE = original_verbosity
    log.print '360p'.paint 360
    log.print ' 480p'.paint 480
    log.print ' 720p'.paint 720
    log.print ' 1080p'.paint 1080
    log.puts ' highest'.uncolor

    shows = RESULTS.values.sort_by(&:name)
    shows.each do |show|
      log.puts show.name
      show.seasons.each_value do |season|
        log.puts season.name.indent 4 unless season.name == 'root'
        indent_size = season.name == 'root' ? 4 : 8
        highest_resolution = season.highest_resolution
        str = ''
        episodes = season.episodes.values.sort_by { |e| e.name.to_f == 0 ? 9999 : e.name.to_f }
        episodes.each do |episode|
          episode_str = episode.to_s
          episode_str.uncolor if episode.resolution == highest_resolution
          if (str + "#{episode_str}, ").uncolorize.length + indent_size < cols
            str += "#{episode_str}, "
          else
            log.puts str.indent indent_size
            str = "#{episode_str}, "
          end
        end
        log.puts str.indent indent_size
      end
    end
  end
end

start = Time.now
main
trim_results
# print_results
finish = Time.now
File.open('resolutions_log.log', 'a') do |log_file|
  log = DoublePrinter.new $stdout, log_file
  log.puts "took #{finish - start} seconds"
end
print "\a"
