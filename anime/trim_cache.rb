require 'json'
require 'active_support'
require 'active_support/number_helper'

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
  File.exist?(path)
end

start = Time.now
main
duration = Time.now - start
avg_duration = duration / $total_paths * 1000
puts "\nTrimmed #{ActiveSupport::NumberHelper.number_to_delimited $trimmed_paths} paths"
puts "took #{duration} seconds for #{ActiveSupport::NumberHelper.number_to_delimited $total_paths} paths (avg #{avg_duration.round(3)} ms per file)"
