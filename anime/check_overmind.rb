$start = Time.now
require 'digest'
require_relative './cache'
require 'active_support'
require 'active_support/number_helper'
require 'zlib'

REMOTE = !ARGV.empty?
LOCAL_PATH = '/mnt/d/anime'
EXTERNAL_PATH = '/mnt/g/anime'
LONG_EXTERNAL_PATH = '/mnt/f/anime'
# LOCAL_PATH = '/mnt/c/Users/Philip Ross/Downloads/test/local'
# EXTERNAL_PATH = '/mnt/c/Users/Philip Ross/Downloads/test/external'
# LONG_EXTERNAL_PATH = '/mnt/c/Users/Philip Ross/Downloads/test/long_external'
TEMP_PATH = '/mnt/e/anime'
REMOTE_PATHS = ['/entertainment/anime']
OPTS = {encoding: 'UTF-8'}
SSH_OPTIONS = {compression: true, config: true, timeout: 1, max_pkt_size: 0x10000}
HIDE_LOCAL_ONLY = false
# TODO hide_local_only make extensible so it dosen't only depend on local and remote
CACHE_PATH = 'check_overminds.cache.json'
CACHE_REFRESH = 30 # seconds
PRINT_REFRESH = 1 / 60.0 # seconds
DIGEST_ALGO = Digest::SHA256
ANIME_SEMAPHORE = Mutex.new
ERROR_THRESHOLD = 5000

if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
  require 'colorize'
  require 'active_support/core_ext/string/access'
  require 'active_support/core_ext/string/indent'
  require 'active_support/core_ext/string/filters'
  require 'terminal-size'
  require 'tty-cursor'

  $terminal_size = Terminal.size
  Signal.trap('SIGWINCH', proc { $terminal_size = Terminal.size })
  $cursor = TTY::Cursor

  $included = Set.new
  $included << 'local'.freeze
  $included << 'remote'.freeze
  $included << 'external'.freeze if File.directory?(EXTERNAL_PATH)
  $included << 'long_external'.freeze if File.directory?(LONG_EXTERNAL_PATH)
  puts 'skipping overmind' unless $included.include? 'remote'.freeze
  puts 'skipping external' unless $included.include? 'external'.freeze

  abort("overmind or an external hard drive need to be connected to work") unless ($included.size > 1)

  $updating_lines = $included.dup.delete('remote'.freeze).size
end

class String
  def uncolor
    replace self.light_black
  end
end

class LocalString < String
  def paint
    replace self.light_green
  end
end

class RemoteString < String
  def paint
    replace self.light_red
  end
end

class ExternalString < String
  def paint
    replace self.light_magenta
  end
end

class LongExternalString < String
  def paint
    replace self.light_yellow
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

  def merge!(anime_to_merge)
    anime_to_merge.seasons.each_value do |season_to_merge|
      find_season(self, season_to_merge.name).merge!(season_to_merge)
    end
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

  def merge!(season_to_merge)
    season_to_merge.episodes.each_value do |episode_to_merge|
      find_episode(self, episode_to_merge.name).merge!(episode_to_merge)
    end
  end
end

class Episode
  ATTRS = [:local_size, :remote_size, :external_size, :long_external_size, :local_checksum, :remote_checksum, :external_checksum, :long_external_checksum]
  attr_accessor :season, :name, :external_size_extra
  attr_accessor *ATTRS

  def initialize(season, name)
    @season = season
    @name = name
    ATTRS.each do |attr|
      instance_variable_set("@#{attr}", 0)
    end
    season.add_episode self
  end

  def merge!(episode_to_merge)
    ATTRS.each do |attr|
      to_merge_value = episode_to_merge.send(attr)
      if to_merge_value != 0
        send(:"#{attr}=", to_merge_value)
      end
    end
  end

  def in_both_external?
    @external_size != 0 && @long_external_size != 0
  end

  def only_external
    @external_size != 0 ? @external_size : @long_external_size
  end

  # def external_size=(size)
  #   if @external_size == 0
  #     @external_size = size
  #   else
  #     @external_size_extra = size
  #   end
  # end

  def biggest_size
    biggest_value = 0
    instance_variables.each do |instance_var|
      next unless instance_var.to_s.end_with?('size'.freeze)
      value = instance_variable_get instance_var
      biggest_value = value if value > biggest_value
    end
    biggest_value
  end

  def biggest_size_names
    biggest_instance_vars = []
    biggest_value = 0
    instance_variables.each do |instance_var|
      next unless instance_var.to_s.end_with?('size'.freeze)
      value = instance_variable_get instance_var
      if value > biggest_value
        biggest_value = value
        biggest_instance_vars = [instance_var]
      elsif value == biggest_value
        biggest_instance_vars << instance_var
      end
    end
    biggest_instance_vars
  end

  def human_sizes
    if sizes_same?
      checksum_mapping = {'0'.freeze => '0'.freeze}
      index = 0
      [@local_checksum.to_s, @remote_checksum.to_s, @external_checksum.to_s, @long_external_checksum.to_s].each do |checksum|
        if checksum_mapping[checksum].nil?
          index += 1
          checksum_mapping[checksum] = 'Checksum #'.freeze + index.to_s
        end
      end
      checksums = {}
      checksums[:local] = LocalString.new(checksum_mapping[@local_checksum.to_s]).uncolor if $included.include? 'local'.freeze
      checksums[:remote] = RemoteString.new(checksum_mapping[@remote_checksum.to_s]).uncolor if $included.include? 'remote'.freeze
      checksums[:external] = ExternalString.new(checksum_mapping[@external_checksum.to_s]).uncolor if $included.include? 'external'.freeze
      checksums[:long_external] = LongExternalString.new(checksum_mapping[@long_external_checksum.to_s]).uncolor if $included.include? 'long_external'.freeze
      [:checksum, checksums]
    else
      sizes = {}
      sizes[:local] = LocalString.new(h_size(@local_size)).uncolor if $included.include? 'local'.freeze
      sizes[:remote] = RemoteString.new(h_size(@remote_size)).uncolor if $included.include? 'remote'.freeze
      sizes[:external] = ExternalString.new(h_size(@external_size)).uncolor if $included.include? 'external'.freeze
      sizes[:long_external] = LongExternalString.new(h_size(@long_external_size)).uncolor if $included.include? 'long_external'.freeze
      [:size, sizes]
    end
  end

  def sizes_same?()
    sizes = Set.new
    filtered_types = []
    both_zero = external_size == long_external_size && external_size == 0
    filtered_types << 'external'.freeze if !both_zero && external_size == 0
    filtered_types << 'long_external'.freeze if !both_zero && long_external_size == 0
    $included.reject do |type|
      filtered_types.include?(type)
    end.each do |type|
      sizes << send((type + '_size'.freeze).to_sym)
    end
    sizes.size == 1
  end

  def to_s
    str = @name.cyan
    return str if defined?(HIDE_LOCAL_ONLY) && HIDE_LOCAL_ONLY && local_size != 0 && remote_size == 0
    str << ':'.freeze

    different_part, human_strs = human_sizes

    # count number of times size shows up
    counts = Hash.new(0)
    # 0 is always colored
    counts['0 Bytes'.freeze] = human_strs.count * -1 + 1
    # must be 2 or more in order to be uncolored
    counts['min repetitions to color'.freeze] = 2

    if different_part == :size
      biggest_size_names.each do |biggest_size_name|
        # drop @, size / checksum and convert to symbol
        counts[human_strs[biggest_size_name[1..-1].split('_'.freeze)[0..-2].join('_'.freeze).to_sym].uncolor] = human_strs.count
      end
    end

    # initialize all sizes in size count
    human_strs.each do |_size_type, size|
      counts[size] = 0 unless counts.include? size
    end
    human_strs.each do |_size_type, size|
      counts[size.dup] += 1
    end

    # color if not the most common (0 always colored)
    max_size_count = counts.values.max
    human_strs.each do |size_type, size|
      if counts[size] == max_size_count
        human_strs[size_type] = size.uncolor
      else
        human_strs[size_type] = size.paint
      end
    end

    human_strs[:external] = human_strs[:external].paint if in_both_external?
    human_strs[:long_external] = human_strs[:long_external].paint if in_both_external?

    str.concat(' '.freeze, human_strs[:local]) if human_strs.has_key? :local
    str.concat(' ('.freeze, human_strs[:remote], ')'.freeze) if human_strs.has_key?(:remote)
    both_zero = external_size == long_external_size && external_size == 0
    # str << ' [both]'.freeze if both_zero && (sizes.has_key?(:external) || sizes.has_key?(:long_external))
    str.concat(' ['.freeze, human_strs[:external], ']'.freeze) if both_zero && (human_strs.has_key?(:external) || human_strs.has_key?(:long_external))
    str.concat(' ['.freeze, human_strs[:external], ']'.freeze) if !both_zero && human_strs.has_key?(:external) && external_size != 0
    str << ' &'.freeze if in_both_external?
    str.concat(' {'.freeze, human_strs[:long_external], '}'.freeze) if !both_zero && human_strs.has_key?(:long_external) && long_external_size != 0
    str << @external_size_extra.to_s
    str
  end
end

class Cache < BaseCache
  def initialize(cache, path, update_duration = -1)
    super(cache, path, update_duration)
  end

  def self.load_episode(path, last_modified, payload)
    CacheEpisode.new(path, last_modified, payload)
  end
end

CHECKSUM_KEY = 'checksum'.freeze
SIZE_KEY = 'size'.freeze

class CacheEpisode < BaseCachePayload

  def initialize(path, last_modified, payload)
    super(path, last_modified, payload)
  end

  def checksum
    payload[CHECKSUM_KEY]
  end

  def checksum=(checksum)
    payload[CHECKSUM_KEY] = checksum
  end

  def size
    payload[SIZE_KEY]
  end

  def size=(size)
    payload[SIZE_KEY] = size
  end

  def as_json(options = {})
    hash = super(options)
    hash[:checksum] = checksum
    hash[:size] = size
    hash
  end
end

def with_uploaded(ssh, files)
  files.map do |local, remote|
    ssh.sftp.upload(local, remote)
  end.map(&:wait)

  yield

  ssh.exec! "rm #{files.values.join(" ")}"
end

def execute_on_remote(ssh)
  serialized_results = ""
  channel = ssh.open_channel do |ch|
    ch.exec "source load_rbenv && ruby remote.rb remote" do |ch, success|
      raise "could not execute command" unless success
      # "on_data" is called when the process writes something to stdout
      transferring_data = false
      ch.on_data do |_c, data|
        if transferring_data
          serialized_results << data
        elsif data == "transferring_data\n"
          transferring_data = true
        elsif data.start_with?("progress: ")
          msg = data[10..-1]
          print_updating(msg, $updating_lines - 1, true)
        else
          $stdout.print data
        end
      end

      # "on_extended_data" is called when the process writes something to stderr
      ch.on_extended_data do |_c, _type, data|
        $stderr.print data
      end
    end
  end

  channel.wait

  Zlib::Inflate.inflate serialized_results
end

def main
  puts "Took #{Time.now - $start} seconds to load script"
  puts Time.now
  remote_results = {}
  $cache = Cache.load(CACHE_PATH, CACHE_REFRESH)
  if $included.include? 'remote'.freeze
    begin
      Net::SSH.start(ENV['OVERMIND_SSH_HOST'], nil, SSH_OPTIONS) do |ssh|
        with_uploaded(ssh, {__FILE__ => 'remote.rb', 'cache.rb' => 'cache.rb'}) do
          serialized_results = execute_on_remote(ssh)
          begin
            remote_results.replace Marshal::load(serialized_results)
          rescue TypeError => e
            $included.delete? 'remote'.freeze # debug?
            $stderr.puts 'Error reading results from remote'
            $stderr.puts e.full_message
            if serialized_results.size <= ERROR_THRESHOLD
              $stderr.puts serialized_results
            else
              $stderr.puts serialized_results.truncate(ERROR_THRESHOLD / 2)
              $stderr.puts "\n**** #{serialized_results.size - ERROR_THRESHOLD} serialized_results chars omitted ****\n\n"
              $stderr.puts serialized_results.last(ERROR_THRESHOLD / 2)
            end
          end
        end
      end
    rescue Errno::EAGAIN => e
      puts 'could not connect to overmind'
      $included.delete('remote'.freeze)
    end
  end

  threads = []
  Thread.abort_on_exception = true
  current_line = -1

  puts
  if $included.include? 'local'.freeze
    puts 'running locally'
    current_line += 1
    threads << Thread.new(current_line) do |line|
      results = {}
      print_thread = start_print_thread
      iterate results, LOCAL_PATH + '/zWatched', 'local'.freeze, line
      iterate results, LOCAL_PATH, 'local'.freeze, line
      print_thread.exit
      $cache.write
      print_updating("done running local", line, true)
      results
    end
  end
  if $included.include? 'external'.freeze
    puts 'running on external'
    current_line += 1
    threads << Thread.new(current_line) do |line|
      results = {}
      print_thread = start_print_thread
      iterate results, EXTERNAL_PATH + '/zWatched', 'external'.freeze, line
      iterate results, EXTERNAL_PATH, 'external'.freeze, line
      print_thread.exit
      $cache.write
      print_updating("done running external", line, true)
      results
    end
  end
  if $included.include? 'long_external'.freeze
    puts 'running on long external'
    current_line += 1
    threads << Thread.new(current_line) do |line|
      results = {}
      print_thread = start_print_thread
      iterate results, LONG_EXTERNAL_PATH + '/zWatched', 'long_external'.freeze, line
      iterate results, LONG_EXTERNAL_PATH, 'long_external'.freeze, line
      print_thread.exit
      $cache.write
      print_updating("done running long_external", line, true)
      results
    end
  end
  results = threads.map { |thread| thread.value }
  merge!(remote_results, *results)
end

def iterate(results, path, type, line = 0)
  shows = Dir.entries path, **OPTS
  count = 0
  shows.sort.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    count += 1
    # break if count > 5 # DEBUG
    # next unless show < "A"
    # next unless show.start_with?('A Silent')
    analyze_show results, show, path + '/' + show, type, line
  end
end

def analyze_show(results, show, path, type, line)
  begin
    anime = find_anime(results, show)
    root_season = find_season anime, 'root'
    entries = Dir.entries path, **OPTS
    entries.sort.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' # || entry.end_with?('.txt')
      if File.directory?("#{path}/#{entry}")
        analyze_season find_season(anime, entry), path + '/' + entry, type, line
      else
        analyze_episode root_season, entry, path + '/' + entry, type, line
      end
    end
  rescue Errno::EACCES => _
  end
end

def analyze_season(season, path, type, line, prefix = '')
  begin
    entries = Dir.entries path, **OPTS
    entries.sort.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
      analyze_episode season, prefix + entry, path + '/' + entry, type, line
    end
  rescue Errno::EACCES => _
  end
end

def analyze_episode(season, episode_name, path, type, line)
  begin
    return unless File.exist?(path)
    # recurse for directories from here on out
    analyze_season(season, path, type, line, episode_name + '/') and return if File.directory?(path)

    print_updating("Calcing CKSM for #{path}", line)
    data, _cached = $cache.get(path) do
      print_updating("Calcing CKSM for #{path}", line, true)
      file_size = File.size(path)
      if (file_size == 0) # so
        file_size = 1
      end
      {CHECKSUM_KEY => DIGEST_ALGO.file(path).to_s, SIZE_KEY => file_size}
    end

    episode_name.chomp!('.filepart')
    episode_name.chomp!('.crdownload')
    episode_name.chomp! '.mp4'
    episode_name.chomp! '.mkv'
    episode = find_episode season, episode_name
    episode.send(type + '_size=', data[SIZE_KEY])
    episode.send(type + '_checksum=', data[CHECKSUM_KEY])
  rescue Errno::EACCES => _
  end
end

def print_updating(msg, line, force = false)
  print "progress: #{msg}" or return if !ARGV.empty? && force

  if force || should_print?
    Thread.current[:should_print] = false
    str = $cursor.save
    ($updating_lines - line).times { str << $cursor.prev_line }
    str << $cursor.clear_line
    str << msg.truncate($terminal_size[:width]) + "\n"

    str << $cursor.restore
    print(str)
  end
end

def start_print_thread
  thread = Thread.current
  Thread.new do
    while true
      thread[:should_print] = true
      sleep PRINT_REFRESH
    end
  end
end

def should_print?
  Thread.current[:should_print]
end

def remote_main
  results = {}
  $stdout.sync = true # don't buffer stdout
  puts "running on remote"
  $cache = Cache.load(CACHE_PATH, CACHE_REFRESH)

  REMOTE_PATHS.each do |rp|
    puts "running on #{rp}"
    iterate(results, rp, 'remote'.freeze) if File.exist?(rp)
    print_updating("done running remote #{rp}", 0, true)
    $cache.write
  end
  binary = Zlib::Deflate.deflate(Marshal::dump(results))
  puts "Took #{Time.now - $start} seconds to run on remote. binary size: #{h_size(binary.bytesize)}"
  sleep 0.000001 # prevents control messages from getting mixed with other messages
  puts "transferring_data" # tells local that the next output is data
  sleep 0.000001 # prevents control messages from getting mixed with other messages
  $stdout.sync = false # turn back on stdout buffering
  print binary
end

def find_anime(results, name)
  ANIME_SEMAPHORE.synchronize do
    anime = results[name] || Anime.new(name)
    results[anime.name] = anime
  end
end

def find_season(anime, name)
  anime.seasons[name] || Season.new(anime, name)
end

def find_episode(season, name)
  season.episodes[name] || Episode.new(season, name)
end

def merge!(*results_arg)
  first_result, *results = results_arg
  results.reduce(first_result) do |results, to_merge|
    to_merge.each_value do |anime_to_merge|
      find_anime(results, anime_to_merge.name).merge!(anime_to_merge)
    end
    results
  end
end

def find_dups(results)
  dups = Set.new
  results.each_value do |show|
    dups << show if find_show_dups show
  end
  dups
end

def find_show_dups(show)
  show.seasons.each_value do |season|
    season.episodes.each_value do |episode|
      return true if episode.in_both_external?
    end
  end
  false
end

def trim_results(results)
  results.each_value do |show|
    show.seasons.each_value do |season|
      season.episodes.each_value do |episode|
        sizes = Set.new
        checksums = Set.new
        included = $included.dup
        included.delete('external'.freeze) if episode.external_size != episode.long_external_size && episode.external_size == 0
        included.delete('long_external'.freeze) if episode.external_size != episode.long_external_size && episode.long_external_size == 0
        included.each do |type|
          sizes << episode.send("#{type}_size")
          checksums << episode.send("#{type}_checksum").to_s
        end

        season.episodes.delete(episode.name) if sizes.size == 1 && checksums.size == 1
        # if sizes.size == 2 && $included.include?('long_external'.freeze)
        #   non_long_external_sizes = Set.new
        #   $included.each do |type|
        #     non_long_external_sizes << episode.send("#{type}_size") unless type == 'long_external'.freeze
        #   end
        season.episodes.delete(episode.name) if sizes.size == 1 && checksums.size == 1 #if non_long_external_sizes.size == 1
        # end
      end
      show.seasons.delete(season.name) if season.episodes.size == 0
      # show.seasons.delete(season.name) if season.episodes.size > 10 # TODO delete
    end
    results.delete(show.name) if show.seasons.size == 0
  end
end

def print_results(results)
  cols = $terminal_size[:width]
  print LocalString.new("local size").paint if $included.include? 'local'.freeze
  if $included.include? 'remote'.freeze
    print " ("
    print RemoteString.new("remote size").paint
    print ")"
  end
  if $included.include? 'external'.freeze
    print " ["
    print ExternalString.new("external size").paint
    print "]"
  end
  if $included.include?('long_external'.freeze) && $included.include?('external'.freeze)
    print " |"
  end
  if $included.include?('long_external'.freeze)
    print " {"
    print LongExternalString.new("long external size").paint
    print "}"
  end
  print " unchanged".uncolor
  print "\n"

  shows = results.values.sort_by(&:name).reverse
  shows.each do |show|
    puts show.name
    seasons = show.seasons.values.sort_by { |s| s.name }
    seasons.each do |season|
      puts season.name.indent 4 unless season.name == 'root'
      indent_size = season.name == 'root' ? 4 : 8
      str = ''
      episodes = season.episodes.values.sort_by { |e| episode_sort(e) }
      episodes.each do |episode|
        episode_str = episode.to_s
        if (str + episode_str + ', '.freeze).uncolorize.length + indent_size < cols
          str << episode_str
          str << ', '.freeze
        else
          puts str.indent indent_size
          str = episode_str + ', '.freeze
        end
      end
      puts str.indent indent_size
    end
  end

  if $included.include?('remote'.freeze) && $included.include?('external'.freeze)
    remote = 0
    external = 0
    local = 0
    results.each_value do |show|
      show.seasons.each_value do |season|
        season.episodes.each_value do |episode|
          # puts episode.inspect
          next if defined?(HIDE_LOCAL_ONLY) && HIDE_LOCAL_ONLY && episode.remote_size == 0 && episode.local_size != 0
          local += episode.local_size
          remote += episode.remote_size
          external += episode.external_size
        end
      end
    end
    transfer_amount = local
    transfer = ActiveSupport::NumberHelper.number_to_human_size(transfer_amount, {precision: 5, strip_insignificant_zeros: false})
    # kilobytes_per_sec = 1400
    # kilobytes_per_sec = 1200
    kilobytes_per_sec = 1024
    est = (transfer_amount) / (1024 * kilobytes_per_sec)
    puts "Need to transfer #{transfer.light_cyan}: EST: #{to_human_duration(est).light_cyan} (#{kilobytes_per_sec} KB/s)"
  end
end

def episode_sort(episode)
  if is_digit?(episode.name[0])
    # is a number
    [episode.name.to_f]
  else
    # sort by level of nesting and then by string sorting
    [9999, episode.name.count("/".freeze), episode.name]
  end
end

def is_digit?(s)
  code = s.ord
  # 48 is ASCII code of 0
  # 57 is ASCII code of 9
  48 <= code && code <= 57
end

def to_human_duration(time)
  mm, ss = time.divmod(60)
  hh, mm = mm.divmod(60)
  dd, hh = hh.divmod(24)
  str = ""
  str << "#{dd} days, " if dd > 0
  str << "#{hh} hours, " if hh > 0
  str << "#{mm} minutes, " if mm > 0
  str << "#{ss} seconds, " if ss > 0
  str = str[0..-3]
  str.reverse.sub(" ,", " and ".reverse).reverse
end

def h_size(size)
  ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5, strip_insignificant_zeros: false})
end

def print_dups(dups)
  puts ''
  if dups.empty?
    puts "There are no shows in both externals".light_green
  else
    puts "These shows are in both externals #{dups.map(&:name)}".light_red
  end
end

if ARGV.empty?
  start = Time.now
  results = main
  dups = find_dups(results)
  trim_results(results)
  print_results(results)
  print_dups dups
  puts "Took #{Time.now - start} seconds"
else
  remote_main
end
