require 'mime/types'
require 'pathname'
require 'set'
if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
  require 'colorize'
  require 'active_support'
  require 'active_support/number_helper'
  require 'active_support/core_ext/string/indent'
  require 'highline/import'
  require 'shellwords'
end

# Only works for movies
REMOTE = !ARGV.empty?
LOCAL_PATH = '/mnt/e/movies'
# LOCAL_PATH = '/mnt/h/tv'
# LOCAL_PATH = "/mnt/c/Users/Philip Ross/Downloads/ryan/empty_movies"
REMOTE_PATH = '/notanime/ryan/movies/Movies/'
# REMOTE_PATH = '/notanime/ryan/tv/TV Shows/'
REMOTE_LOCAL_PATH = '/mnt/c/Users/Philip Ross/Downloads/ryan/empty_movies' # debug

REMOTE_RESULTS = []
LOCAL_RESULTS = []

LOCAL_CACHE = Set.new

# COUNT_LETTERS = 'a'..'z'
COUNT_LETTERS = ('a'..'z').to_a + (' '..'?').to_a

# THRESHOLD = 75.0 # %
THRESHOLD = 90.0 # %
# THRESHOLD = 100.0 # %
BATCH_SIZE = 10

# Note doesn't actually delete on server, just builds commands to
def main
  start = Time.now
  puts Time.now
  begin
    Net::SSH.start(ENV['OVERMIND_HOST'], ENV['OVERMIND_USER'], password: ENV['OVERMIND_PASSWORD'], timeout: 1, port: 666) do |ssh|
      ssh.sftp.connect do |sftp|
        sftp.upload!(__FILE__, "remote.rb")
      end
      puts 'running on remote'
      serialized_results = ssh.exec! "source load_rbenv && ruby remote.rb remote"
      # puts "result from remote: #{serialized_results}"
      begin
        REMOTE_RESULTS.replace Marshal::load(serialized_results)
      rescue TypeError => e
        puts 'Error reading results from remote'
        puts serialized_results
      end
      ssh.exec! "rm remote.rb"
    end
  rescue Errno::EAGAIN => e
    puts 'could not connect to overmind'
    $included.delete('remote')
  end

  puts 'running locally'
  iterate(LOCAL_PATH)
  # iterate(REMOTE_LOCAL_PATH, false)

  puts 'calculating similarity'
  similar_results = get_similar_results(LOCAL_RESULTS, REMOTE_RESULTS)
  # similar_results = similar_results.reverse
  puts 'done calculating similarity'
  puts "Took #{Time.now - start} seconds"
  puts "local size: #{LOCAL_RESULTS.size}"
  puts "remote size: #{REMOTE_RESULTS.size}"

  # ssh = nil
  count = 0
  similar_results.each_slice(BATCH_SIZE) do |array|
    array.each do |obj|
      count += 1
      # puts o
      # puts "similarity: #{sprintf("%05.2f", o[:similarity].round(2))}% local: \"#{o[:local][:name]}\", remote: \"#{o[:remote][:name]}\""
      print_similarity(obj)
      # break if count >= 10
    end
    case yes_no_or_split
    when 'y'
      remove_array(array)
    when 's'
      cmd = 'sudo rm -rf'
      array.each do |obj|
        print_similarity(obj)
        cmd += build_remove(obj) if yesno
      end
      puts "cmd split: #{cmd.light_green}"
      puts 'split'
    when 'n'
    end
  end
  puts similar_results.size
end

def remove_array(array)
  cmd = "sudo rm -rf #{array.map { |a| Shellwords.escape(File.dirname(a[:remote][:original_path])) }.join(' ')}".light_green
  puts "cmd: #{cmd}"
end

def build_remove(obj)
  ' ' + Shellwords.escape(File.dirname(obj[:remote][:original_path]))
end

def print_similarity(result)
  max_name_length = [result[:local][:name].size, result[:remote][:name].size].max
  local = (result[:local][:name].ljust(max_name_length) + ' | ' + result[:local][:relative_path]).light_cyan
  remote = (result[:remote][:name].ljust(max_name_length) + ' | ' + result[:remote][:relative_path]).light_red
  similarity = sprintf("%05.2f%%", result[:similarity]).light_magenta
  # puts result
  puts local
  puts remote
  puts similarity
  puts ''
end

def remote_main
  iterate(REMOTE_PATH)
  puts Marshal::dump(LOCAL_RESULTS)
end

# on remote
# iterate recursively through remote path
# add all directorys / or files that have (####)
# add as {name: ..., char_count: {a: 1, ...}} (char count is upto (####))
# return this as a list
#
# on local
# do the same with local
#
# iterate through the remote array
# figure out how to calculate similarity
#
# if similar enough add to new array {local: local, remote: remote, similarity: ##}
# print and output
#

# TODO change directory to be either parent or grandparent
# TODO change back to only on video files
def iterate(path, _local = true)
  count = 0
  Dir.glob("#{path}/**/*").each do |f|
    next if f.end_with?('.enc') || f.end_with?('.ini')
    # next if File.directory? f
    directory = File.basename(File.dirname(f))
    has_year = directory[/\(\d+{4,}\)/]
    has_res = directory[/\[\d+{3,}.\]/]
    has_enc = directory[/\{.+{3}\}/]
    # puts "dir: #{directory} directory[/\\(\\d+{4,}\\)/]: #{has_year} directory[/\\[\\d+{3,}.\\]/]: #{has_res} directory[/\\{.+{3}\\}/]: #{has_enc}"
    next unless has_year || has_res || has_enc
    # next unless is_video? File.extname(f)
    # break if count > 1
    count += 1
    #next if count < 3
    #puts f
    #puts ''
    filename = File.basename(f)
    #puts "directory: #{directory}"
    #puts "filename: #{filename}"
    name = trim_filename(directory)
    relative_path = Pathname.new(f).relative_path_from(Pathname.new(path)).to_s

    if _local # debug
      if !LOCAL_CACHE.include? name
        LOCAL_RESULTS << {name: name, original_path: f, relative_path: relative_path, count: count_chars(name.downcase)}
        LOCAL_CACHE << name
      end
    else
      if !LOCAL_CACHE.include? name
        REMOTE_RESULTS << {name: name, original_path: f, relative_path: relative_path, count: count_chars(name.downcase)}
        LOCAL_CACHE << name
      end
    end
  end
end

def get_directory(path)
  puts path
end

def trim_filename(str)
  name = File.basename(str, File.extname(str))
  name = name[0...name.index(/\(\d+\)/)] if name[/\(\d+\)/]
  name = name[0...name.index(/\[\d+.\]/)] if name[/\[\d+.\]/]
  name = name[0...name.index(/\{.+\}/)] if name[/\{.+\}/]

  name.strip
end

def count_chars(str)
  count = Hash.new(0)
  str.each_char { |c| count[c] += 1 }
  count
end

def calculate_similarity(local_result, remote_result)
  # puts "\ncalculate similiarity\n"
  # puts "local: #{local_result}"
  # puts "remote: #{remote_result}"
  combined_size = local_result[:name].size + remote_result[:name].size
  diff = 0


  COUNT_LETTERS.each do |letter|
    local = local_result[:count][letter]
    remote = remote_result[:count][letter]
    lower_diff = (local - remote).abs
    upper_diff = (local_result[:count][letter.upcase] - remote_result[:count][letter.upcase]).abs
    upper_diff = lower_diff if lower_diff < upper_diff
    upper_diff = 0 if letter.downcase == letter.upcase

    d = lower_diff - upper_diff / 2.0
    diff += d
    # puts "#{letter}: #{d} = #{lower_diff} - #{upper_diff} / 2"
  end
  # puts "diff: #{diff}"
  # puts "combined_size: #{combined_size}"
  # puts "threshold: #{threshhold}"


  # puts "\n\n"
  100 * (1 - (diff / combined_size))
end

def get_similar_results(local_results, remote_results)
  LOCAL_RESULTS.product(REMOTE_RESULTS).map do |local, remote|
    similarity = calculate_similarity(local, remote)
    {similarity: similarity, local: local, remote: remote} if similarity >= THRESHOLD
  end.compact.sort_by { |s| s[:similarity] }.reverse!
end

def is_video?(ext)
  MIME::Types.type_for(ext).any? { |mt| mt.media_type == 'video' }
end

def yes_no_or_split(prompt = 'Continue?', default = true)
  a = ''
  s = case default
      when true
        '[Y/n/s]'
      when false
        '[y/N/s]'
      when 'switch'
        '[y/n/S]'
      end
  d = case default
      when true
        'y'
      when false
        'n'
      when 'switch'
        's'
      end
  until ['y', 'n', 's', 3.chr].include? a
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    a = ask("#{prompt} #{s} ") { |q| q.limit = 1; q.case = :downcase }
    $VERBOSE = original_verbosity
    a = d if a.length == 0
    raise Exception.new('canceled program') if a.ord == 3
  end
  a
end

def yesno(prompt = 'Continue?', default = true)
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until ['y', 'n', 3.chr].include? a
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    a = ask("#{prompt} #{s} ") { |q| q.limit = 1; q.case = :downcase }
    $VERBOSE = original_verbosity
    a = d if a.length == 0
    raise Exception.new('canceled program') if a.ord == 3
  end
  a == 'y'
end

def print_results
  puts LOCAL_RESULTS.map { |r| r[:original_path] }
  puts "\n******************\n"
  puts REMOTE_RESULTS.map { |r| r[:original_path] }
end

if ARGV.empty?
  main
  #dups = find_dups
  #trim_results
  # print_results
  #print_dups dups
else
  remote_main
end
