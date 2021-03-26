require_relative './base_script'
if ARGV.empty?
  require 'highline/import'
  require 'colorize'
end

PATH_TYPES = [:remote_path, :local_path, :local_watched_path, :external_path, :external_watched_path, :long_external_path, :long_external_watched_path]

class Show < BaseShow
  attr_accessor :new_name, *PATH_TYPES

  def new_name
    @name.gsub(' (In Progress)', '')
  end

  def to_s
    "#{name}: remote: #{remote_path}, local: #{local_path}, external: #{external_path} long_external: #{long_external_path}"
  end
end

class Season < BaseSeason
  attr_accessor :new_name, *PATH_TYPES

  def new_name
    @name.gsub(' (In Progress)', '')
  end

  def to_s
    "#{name}: remote: #{remote_path}, local: #{local_path}, external: #{external_path} long_external: #{long_external_path}"
  end
end

class Script < BaseScript
  def initialize(results = {})
    super(results)
    @analyze_episode = false
  end

  def analyze_show(show, path)
    return unless show.name.include? 'In Progress'
    show.send(@location + '_path=', path)
  end

  def analyze_season(season, path)
    return unless season.name.include? 'In Progress'
    season.send(@location + '_path=', path)
  end

  def should_trim_show?(show)
    super && !show.name.include?('In Progress')
  end

  def should_trim_season?(season)
    return !season.show.name.include?('In Progress') if season.name == 'root'
    !season.name.include? 'In Progress'
  end

  def calc_location(path)
    location = super
    path.match?(/\/zWatched\/?$/) ? "#{location}_watched" : location
  end

  def rename_results
    remote_ssh do |ssh|
      results.each_value do |show|
        if BaseScript.yesno("rename \"#{show.name.light_red}\": #{show.seasons.values.map(&:name).to_s.light_red}\n-> \"#{show.new_name.light_green}\": #{show.seasons.values.map(&:new_name).to_s.light_green}")
          show.seasons.values.each do |season|
            next if season.name == 'root'
            rename(ssh, season)
          end
          rename(ssh, show)
        end
      end
    end
  end

  def rename(ssh, season)
    puts "renaming #{season.name}"
    PATH_TYPES.each do |path_type|
      path = season.send(path_type)
      next unless path
      new_path = File.dirname(path) + '/' + season.new_name
      path_type.to_s.start_with?('remote') ? remote_rename(ssh, path, new_path) : local_rename(path, new_path)
    end
  end

  def local_rename(old_path, new_path)
    File.rename old_path, new_path
  end

  def remote_rename(ssh, old_path, new_path)
    # ssh.exec!("mv \"#{old_path}\" \"#{new_path}\"")
  end
end

def main
  script = Script.new

  script.remotely_iterate("/entertainment/anime")
  script.iterate '/mnt/d/anime'
  script.iterate '/mnt/d/anime/zWatched'
  script.iterate '/mnt/g/anime'
  script.iterate '/mnt/g/anime/zWatched'
  script.iterate '/mnt/f/anime'
  script.iterate '/mnt/f/anime/zWatched'

  script.trim_results
  script.end_time

  script.rename_results
end

if ARGV.empty?
  main
else
  remote_main
end
