require 'shell'

REMOTE = !ARGV.empty?
LOCAL_PATH = '/mnt/d/anime'
EXTERNAL_PATH = '/mnt/g/anime'
LONG_EXTERNAL_PATH = '/mnt/f/anime'
OPTS = {encoding: 'UTF-8'}
$print_buffer = []

$shell = Shell.new
# p = $shell.transact do
#   find_system_command('mkvinfo')
# end
# puts p
# asdf
Shell.def_system_command :mkvinfo, $shell.transact { find_system_command('mkvinfo') }

if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
  require 'colorize'
  require 'active_support'
  require 'active_support/number_helper'
  require 'active_support/core_ext/string/indent'

  $included = Set.new
  $included << 'local'
  $included << 'remote'
  $included << 'external' if File.directory?(EXTERNAL_PATH)
  $included << 'long_external' if File.directory?(LONG_EXTERNAL_PATH)
  puts 'skipping overmind' unless $included.include? 'remote'
end

class String
  def indent_path(path)
    # puts path
    # puts path.count("/")
    indent((path.count("/") - 4) * 2)
  end
end

def main
  # if $included.include? 'remote'
  #   begin
  #     Net::SSH.start(ENV['OVERMIND_HOST'], ENV['OVERMIND_USER'], password: ENV['OVERMIND_PASSWORD'], timeout: 1) do |ssh|
  #       ssh.sftp.connect do |sftp|
  #         sftp.upload!(__FILE__, "remote.rb")
  #       end
  #       puts 'running on remote'
  #       serialized_results = ssh.exec! "source ~/.rvm/scripts/rvm; ruby remote.rb remote"
  #       RESULTS.replace Marshal::load(serialized_results)
  #       ssh.exec! "rm remote.rb"
  #     end
  #   rescue Errno::EAGAIN => e
  #     puts 'could not connect to overmind'
  #     $included.delete('remote')
  #   end
  # end
  if $included.include? 'local'
    puts 'running locally'
    iterate LOCAL_PATH, 'local'
    # iterate LOCAL_PATH + '/zWatched', 'local'
  end
  # if $included.include? 'external'
  #   puts 'running on external'
  #   iterate EXTERNAL_PATH, 'external'
  #   iterate EXTERNAL_PATH + '/zWatched', 'external'
  # end
  # if $included.include? 'long_external'
  #   puts 'running on long external'
  #   iterate LONG_EXTERNAL_PATH, 'long_external'
  #   iterate LONG_EXTERNAL_PATH + '/zWatched', 'long_external'
  # end
end

def iterate(path, type)
  shows = Dir.entries path, **OPTS
  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    # next unless show.start_with?('C')
    analyze_show show, path + '/' + show, type
    count += 1
    # break if count > 2
  end
end

def printr(str)
  print "\r#{str}"
  sleep 0.5
end

def analyze_show(show, path, type)
  $print_buffer << show.indent_path(path)
  print " "  * 120
  print "\r#{show}\r"
  entries = Dir.entries path, **OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' # || entry.end_with?('.txt')
    analyze_show(entry, path + '/' + entry, type) and next if nested_show? entry
    if File.directory?("#{path}/#{entry}")
      analyze_season entry, path + '/' + entry, type
    else
      analyze_episode nil, entry, path + '/' + entry, type
    end
  end
  $print_buffer.clear
end

def analyze_season(season, path, type)
  $print_buffer << season.indent_path(path)
  entries = Dir.entries path, **OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry, path + '/' + entry, type
  end
  $print_buffer.pop unless $print_buffer.empty?
end

def analyze_episode(season, episode_name, path, type)
  if episode_name.end_with? '.mkv'
    $print_buffer.each {|s| puts s}
    $print_buffer.clear
    print episode_name.indent_path path
    print " "
    $shell.transact do

    end
    print "\n"
  end
end

def nested_show?(show)
  nested_shows = ['A Certain Scientific Railgun', 'The Legend of Korra']
  nested_shows.include? show
end

def remote_main
  iterate(REMOTE_PATH, 'remote')
  puts Marshal::dump(RESULTS)
end


if ARGV.empty?
  start = Time.now
  main
  puts "Took #{Time.now - start} seconds"
else
  remote_main
end
