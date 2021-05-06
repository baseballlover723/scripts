require 'json'
require 'pathname'
require 'active_support'
require 'active_support/number_helper'

if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
end

SSH_OPTIONS = {compression: true, config: true, timeout: 1, max_pkt_size: 0x10000}
EXT = '.cache.json'
$total_paths = 0
$trimmed_paths = 0
$cached_drive_paths = {}

def main
  Dir.glob("*" + EXT).each do |cache_file|
    trim_cache(cache_file)
  end
end

def trim_cache(path)
  puts "trimming #{path}"
  json = JSON.parse(File.read(path))
  before_size = json.size
  connected_paths = 0
  json.select! do |path, _data|
    next true unless drive_connected?(path)
    connected_paths += 1
    File.file?(path) # returns false for existing directories
  end
  $total_paths += connected_paths
  $trimmed_paths += before_size - json.size
  File.write(path, JSON.generate(json))
end

# optimized so that it only caches files if they meet the correct directory depth, and that it only creates pathnames for new directories
def drive_connected?(path)
  drive_path = $cached_drive_paths.keys.find { |p| path.start_with?(p) }
  return $cached_drive_paths[drive_path] if drive_path && $cached_drive_paths[drive_path]
  drive_path = Pathname.new(path).descend.take(3).fetch(2, path).to_s

  exists = File.exist?(drive_path) && File.directory?(drive_path)
  $cached_drive_paths[drive_path] = exists if drive_path != path
  exists
end

def remote_trim
  begin
    Net::SSH.start(ENV['OVERMIND_SSH_HOST'], nil, SSH_OPTIONS) do |ssh|
      ssh.sftp.upload!(__FILE__, 'remote.rb')
      puts "\n*************** running on remote ***************\n\n"
      puts ssh.exec! "source load_rbenv && ruby remote.rb remote"
      ssh.exec! "rm remote.rb"
    end
  rescue Errno::EAGAIN => e
    puts 'could not connect to overmind'
  end
end

start = Time.now
main
duration = Time.now - start
avg_duration = duration / $total_paths * 1000
puts "\nTrimmed #{ActiveSupport::NumberHelper.number_to_delimited $trimmed_paths} paths"
puts "took #{duration} seconds for #{ActiveSupport::NumberHelper.number_to_delimited $total_paths} paths (avg #{avg_duration.round(3)} ms per file)"

if ARGV.empty?
  remote_trim
end
