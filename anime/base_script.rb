# TODO print results Hookpoint
require_relative 'classes'

if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
  require 'pathname'
  require 'tempfile'
end

class BaseScript
  attr_accessor :opts, :analyze_show, :analyze_season, :analyze_episode, :results, :location, :iterate_movies, :start_time

  def initialize(results = {})
    @opts = {encoding: 'UTF-8'}
    @analyze_show = true
    @analyze_season = true
    @analyze_episode = true
    @results = results
    @start_time = Time.now
  end

  def local?
    ARGV.empty?
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

  def remotely_iterate(path)
    puts "remotely iterating over #{path}"
    current_path = Pathname.new(__dir__)
    remote_folder = "remote_files/"
    results_file = Tempfile.new('results', binmode: true)
    results_file.write(Marshal::dump(results))
    results_file.rewind
    command = "ruby #{remote_folder}#{File.basename($PROGRAM_NAME)} #{path} #{remote_folder + File.basename(results_file.path)}"
    paths = [File.absolute_path('classes.rb')] + caller_locations(0).map { |st| st.absolute_path }
    paths = paths.uniq.map do |path|
      [path, remote_folder + Pathname.new(path).relative_path_from(current_path).to_s]
    end.to_h
    paths = paths.merge({results_file.path => remote_folder + File.basename(results_file.path)})
    begin
      remote_ssh do |ssh|
        ssh.exec! "mkdir -p #{remote_folder}"
        ssh.sftp.connect do |sftp|
          paths.each do |abs, rel|
            sftp.upload!(abs, rel)
          end
        end
        serialized_results = ssh.exec! "source load_rbenv && #{command}"
        ssh.exec! "rm -rf #{remote_folder}"
        begin
          @results = Marshal::load(serialized_results)
          return @results
        rescue TypeError => e
          puts 'Error reading results from remote'
          puts serialized_results
        end
      end
    end
  end

  def remote_ssh(remote = true)
    if remote
      Net::SSH.start(ENV['OVERMIND_HOST'], ENV['OVERMIND_USER'], password: ENV['OVERMIND_PASSWORD'], timeout: 1, port: 666) do |ssh|
        yield ssh
      end
    else
      yield nil
    end
  end

  def iterate(path)
    @location = calc_location(path)
    @iterate_movies = calc_movies(path)
    puts "running on #{@location}" if local?
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

  def calc_movies(path)
    path.match /^\/mnt\/[eh]/
  end

  def show_group?(name)
    # matches (####) [####.]
    !name.match /\(\d{4}\) \[\d+.\]/
  end

  def iterate_shows(path)
    return unless File.directory?(path) # TODO shouldn't need this to stop recursing in non show directories
    count = 0
    Dir.foreach path, **@opts do |show_name|
      next if show_name == '.' || show_name == '..' || show_name == 'zWatched' || show_name == 'desktop.ini' || show_name == 'format.txt'
      # next unless show.start_with?
      count += 1

      show_path = path + '/' + show_name
      if @iterate_movies && show_group?(show_name)
        iterate_shows(path + '/' + show_name)
      else
        show = find_show(show_name, show_path)
        iterate_seasons show, show_path if analyze_season?
        analyze_show(show, show_path) if analyze_show?
      end
      # break if count > 20
    end
  end

  def iterate_seasons(show, path)
    root_season = find_season show, 'root', path
    iterate_episodes root_season, path if analyze_episode?
    if root_season.episodes.empty?
      show.seasons.delete(root_season.name)
    else
      analyze_season(root_season, path) if analyze_season?
    end

    Dir.foreach path, **@opts do |season_name|
      next if season_name == '.' || season_name == '..' || season_name == 'desktop.ini' # || season_name.end_with?('.txt')
      season_path = path + '/' + season_name
      next unless File.directory?(season_path)

      season = find_season(show, season_name, season_path)
      iterate_episodes season, season_path if analyze_episode?
      analyze_season(season, season_path) if analyze_season?
    end
  end

  def iterate_episodes(season, path)
    Dir.foreach path, **@opts do |episode_name|
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
    puts 'trimming results' if local?
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
      exit 130 if a == "\cC" # handle ctrl c
      a = d if a.length == 0
    end
    a == 'y'
  end
end

def remote_main
  results = Marshal::load(File.read(ARGV[1]))
  script = Script.new(results)
  script.location = 'remote' # debug
  script.iterate(ARGV[0])
  script.trim_results
  puts Marshal::dump(script.results)
end
