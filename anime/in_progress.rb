# DONE Get list of shows with (In Progress) in remote, local and external
# DONE store paths and names for remote, local, and external
# DONE iterate over
# query api to see if it indeed done
# ask yes or no to remove (In Progress)
# DONE rename folders on local and external
# TODO remote stuff
#   read remote
#   rename remote

require_relative './base_script'
if ARGV.empty?
  require 'highline/import'
  require 'colorize'
end

PATH_TYPES = [:remote_path, :local_path, :external_path, :long_external_path]

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
end

def main
  script = Script.new
  # script.location = 'local' # debug
  # script.iterate '/mnt/d/anime'
  # script.iterate '/mnt/c/Users/Philip Ross/Downloads/anime'
  script.remotely_iterate("/entertainment/anime")
  # script.location = 'local' # debug
  # script.iterate '/mnt/c/Users/Philip Ross/Downloads/anime'
  # script.location = 'external' # debug
  # script.iterate '/mnt/c/Users/Philip Ross/Downloads/anime external'
  # script.iterate '/mnt/d/anime'
  # script.iterate '/mnt/g/anime'
  # script.iterate '/mnt/f/anime'

  # puts script.results
  script.trim_results
  script.end_time
  results = script.results

  puts "\n\n" # debug

  results.each_value do |show|
    if BaseScript.yesno("rename \"#{show.name.light_red}\": #{show.seasons.values.map(&:name).to_s.light_red}\n-> \"#{show.new_name.light_green}\": #{show.seasons.values.map(&:new_name).to_s.light_green}")
      show.seasons.values.each do |season|
        next if season.name == 'root'
        rename(season)
      end
      rename(show)
    end
  end

  puts "\n\n" # debug
  puts results.map { |_, r| r.name } # debug
  puts results.size # debug
end

def rename(season)
  puts "renaming #{season.name}"
  PATH_TYPES.each do |path_type|
    path = season.send(path_type)
    next unless path
    base = File.dirname path
    # puts "#{path} -> #{base + '/' + season.new_name}" # debug
    File.rename path, base + '/' + season.new_name
  end
end

if ARGV.empty?
  main
else
  remote_main
end
