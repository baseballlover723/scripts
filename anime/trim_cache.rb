require 'json'
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

def main
  Dir.glob("*" + EXT).each do |cache_file|
    trim_cache(cache_file)
  end
end

def trim_cache(path)
  puts "trimming #{path}"
  json = JSON.parse(File.read(path))
  $total_paths += before_size = json.size
  json.select! do |path, _data|
    still_exists?(path)
  end
  $trimmed_paths += before_size - json.size
  File.write(path, JSON.generate(json))
end

def still_exists?(path)
  File.exist?(path) && !File.directory?(path)
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
