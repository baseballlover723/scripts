$start = Time.now
require 'openssl'
require_relative './cache'
require 'active_support'
require 'active_support/number_helper'
require 'zlib'

REMOTE = !ARGV.empty?
SKIP = []
# SKIP = [:movies]
# SKIP = [:tv]
# LOCAL_PATH = '/mnt/c/Users/Philip Ross/Downloads'
LOCAL_PATHS = {movies: '/mnt/e/movies', tv: '/mnt/e/tv'}
EXTERNAL_PATHS = {movies: '/mnt/h/movies', tv: '/mnt/i/tv'}
# EXTERNAL_PATHS = {movies: '/mnt/e/movies'}
REMOTE_PATHS = {movies: '/entertainment/movies', tv: '/entertainment/tv'}
# REMOTE_PATHS = {movies: '/entertainment/movies', tv: '/raided/temp_tv'}
# REMOTE_PATHS = {movies: '../../entertainment/movies'}
OPTS = {encoding: 'UTF-8'}
SSH_OPTIONS = {compression: true, config: true, timeout: 1, max_pkt_size: 0x10000}
RESULTS = {movies: {}, tv: {}}
MOVIE_EXTENSIONS = ['.mkv', '.mp4', '.m4v', '.srt', '.avi']
BLACKLIST = ['anime', 'Naruto', 'Naruto - Copy']
# FILTER = /Season \d\d - Episode(s?) \d\d\d-\d\d\d/
FILTER = /Naruto/
CACHE_PATH = 'moviess.cache.json'
CACHE_REFRESH = 30 # seconds
PRINT_REFRESH = 1 / 60.0 # seconds
DIGEST_ALGO = OpenSSL::Digest::SHA256
SHOW_SEMAPHORE = Mutex.new
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
  $included << 'remote'.freeze
  $included << 'local'.freeze if File.directory? LOCAL_PATHS.values.first
  $included << 'external'.freeze if File.directory? EXTERNAL_PATHS.values.first
  puts 'skipping overmind' unless $included.include? 'remote'.freeze
  puts 'skipping local' unless $included.include? 'local'.freeze
  puts 'skipping external' unless $included.include? 'external'.freeze

  abort("overmind or an external hard drive need to be connected to work") unless ($included.size > 1)

  $updating_lines = $included.dup.delete('remote'.freeze).size + ($included.include?('external'.freeze) ? 1 : 0)
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

class ShowGroup
  attr_accessor :name, :shows

  def initialize(name, ignore)
    @name = name
    @shows = {}
    @ignore = !!ignore
  end

  def add_show(show)
    @shows[show.name] = show
  end

  def ignore?
    @ignore
  end

  def inspect
    "name: #{name}"
  end
end

class Show
  attr_accessor :show_group, :name, :seasons

  def initialize(show_group, name)
    @show_group = show_group
    @name = name
    @seasons = {}

    show_group.add_show self
  end

  def add_season(season)
    @seasons[season.name] = season
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
end

class Episode
  attr_accessor :season, :name, :remote_size, :external_size, :local_size, :local_checksum, :remote_checksum, :external_checksum

  def initialize(season, name)
    @season = season
    @name = name
    @local_size = 0
    @remote_size = 0
    @external_size = 0
    @local_checksum = 0
    @remote_checksum = 0
    @external_checksum = 0
    season.add_episode self
  end

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
      [@local_checksum.to_s, @remote_checksum.to_s, @external_checksum.to_s].each do |checksum|
        if checksum_mapping[checksum].nil?
          index += 1
          checksum_mapping[checksum] = 'Checksum #'.freeze + index.to_s
        end
      end
      checksums = {}
      checksums[:local] = LocalString.new(checksum_mapping[@local_checksum.to_s]).uncolor if $included.include? 'local'.freeze
      checksums[:remote] = RemoteString.new(checksum_mapping[@remote_checksum.to_s]).uncolor if $included.include? 'remote'.freeze
      checksums[:external] = ExternalString.new(checksum_mapping[@external_checksum.to_s]).uncolor if $included.include? 'external'.freeze
      [:checksum, checksums]
    else
      sizes = {}
      sizes[:local] = LocalString.new(h_size(@local_size)).uncolor if $included.include? 'local'.freeze
      sizes[:remote] = RemoteString.new(h_size(@remote_size)).uncolor if $included.include? 'remote'.freeze
      sizes[:external] = ExternalString.new(h_size(@external_size)).uncolor if $included.include? 'external'.freeze
      [:size, sizes]
    end
  end

  def sizes_same?()
    sizes = Set.new
    $included.each do |type|
      sizes << send((type + '_size'.freeze).to_sym)
    end
    sizes.size == 1
  end

  def to_s
    name = @name
    name = name[/.*S\d\dE\d\d/] if name[/S\d\dE\d\d/]
    name = name.cyan
    str = name + ':'.freeze

    different_part, human_strs = human_sizes

    # count number of times size shows up
    counts = Hash.new(0)
    # 0 is always colored
    counts['0 Bytes'.freeze] = human_strs.count * -1 + 1
    # must be 2 or more in order to be uncolored
    counts['min repetitions to color'.freeze] = 2

    if different_part == :size
      biggest_size_names.each do |biggest_size_name|
        # drop @ and convert to symbol
        counts[human_strs[biggest_size_name[1..-1].split('_'.freeze)[0..-2].join('_'.freeze).to_sym].uncolor] = human_strs.count
      end
    end

    # initialize all sizes in size count
    human_strs.each do |_size_location, size|
      counts[size] = 0 unless counts.include? size
    end
    human_strs.each do |_size_location, size|
      counts[size.dup] += 1
    end

    # color if not the most common (0 always colored)
    max_size_count = counts.values.max
    human_strs.each do |size_location, size|
      if counts[size] == max_size_count
        human_strs[size_location] = size.uncolor
      else
        human_strs[size_location] = size.paint
      end
    end

    str.concat(' '.freeze, human_strs[:local]) if human_strs.has_key? :local
    str.concat(' ('.freeze, human_strs[:remote], ')'.freeze) if human_strs.has_key? :remote
    str.concat(' ['.freeze, human_strs[:external], ']'.freeze) if human_strs.has_key? :external
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
  $cache = Cache.load(CACHE_PATH, CACHE_REFRESH)
  if $included.include? 'remote'.freeze
    begin
      Net::SSH.start(ENV['OVERMIND_SSH_HOST'], nil, SSH_OPTIONS) do |ssh|
        with_uploaded(ssh, {__FILE__ => 'remote.rb', 'cache.rb' => 'cache.rb'}) do
          serialized_results = execute_on_remote(ssh)
          begin
            RESULTS.replace Marshal::load(serialized_results)
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
    puts 'running on local'
    current_line += 1
    threads << Thread.new(current_line) do |line|
      LOCAL_PATHS.reject { |type, _path| SKIP.include?(type) }.each do |type, path|
        print_thread = start_print_thread
        iterate path, 'local'.freeze, type, line
        print_thread.exit
        $cache.write
        print_updating("done running local", line, true)
      end
    end
  end
  if $included.include? 'external'.freeze
    EXTERNAL_PATHS.reject { |type, _path| SKIP.include?(type) }.each do |type, path|
      puts "running on external (#{type})"
      current_line += 1
      threads << Thread.new(current_line) do |line|
        print_thread = start_print_thread
        iterate path, 'external'.freeze, type, line
        print_thread.exit
        $cache.write
        print_updating("done running #{path}", line, true)
      end
    end
  end
  threads.each { |thread| thread.join }
end

def iterate(path, location, type, line = 0)
  shows = Dir.entries path, **OPTS
  count = 0
  shows.sort.each do |show_name|
    next if show_name == '.' || show_name == '..' || show_name == 'zWatched' || show_name == 'desktop.ini'
    next unless File.directory? path + '/' + show_name
    next if BLACKLIST.include? show_name
    next if show_name[FILTER]
    count += 1
    # break if count > 2
    # next unless show_name < 'BBD'
    # next unless show.start_with?('C')
    analyze_show_group show_name, path + '/' + show_name, location, type, line
  end
end

def analyze_show_group(name, path, location, type, line)
  begin
    show_group = find_show_group name, type
    if show_group.ignore?
      analyze_show show_group, name, path, location, type, line
      return
    end

    entries = Dir.entries path, **OPTS
    entries.sort.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
      analyze_show show_group, entry, path + '/' + entry, location, type, line
    end
  rescue Errno::EACCES => _
  end
end

def analyze_show(show_group, show_name, path, location, type, line)
  begin
    # iterate(path, location, type) if nested_folder? show_name
    # (analyze_show_group(show_name, path, location, type); return) if show_group? show_name
    show = find_show(show_group, show_name)
    root_season = find_season show, 'root'
    entries = Dir.entries path, **OPTS
    entries.sort.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
      if File.directory?("#{path}/#{entry}")
        analyze_season find_season(show, entry), path + '/' + entry, location, line
      else
        analyze_episode root_season, entry, path + '/' + entry, location, line
      end
    end
    if root_season.episodes.empty?
      show.seasons.delete(root_season.name)
    end
  rescue Errno::EACCES => _
  end
end

def analyze_season(season, path, location, line, prefix = '')
  begin
    entries = Dir.entries path, **OPTS
    entries.sort.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
      analyze_episode season, prefix + entry, path + '/' + entry, location, line
    end
  rescue Errno::EACCES => _
  end
end

TV_EPISODE_REGEX = /S\d\dE\d\d/i

def analyze_episode(season, episode_name, path, location, line)
  begin
    return unless File.exist?(path)
    # recurse for directories from here on out
    analyze_season(season, path, location, line, episode_name + '/') and return if File.directory?(path)

    human_path = path
    human_path = path.split("/").map { |p| p.match(TV_EPISODE_REGEX) ? p[TV_EPISODE_REGEX] : p }.join("/") if path.match TV_EPISODE_REGEX
    print_updating("Calcing CKSM for #{human_path}", line)

    data, _cached = $cache.get(path) do
      print_updating("Calcing CKSM for #{human_path}", line, true)
      file_size = File.size(path)
      if (file_size == 0) # so
        file_size = 1
      end
      {CHECKSUM_KEY => DIGEST_ALGO.file(path).to_s, SIZE_KEY => file_size}
    end
    # return unless episode_name.end_with? *MOVIE_EXTENSIONS
    episode_name.chomp!('.filepart')
    episode_name.chomp!('.crdownload')
    episode = find_episode season, episode_name
    episode.send(location + '_size=', data[SIZE_KEY])
    episode.send(location + '_checksum=', data[CHECKSUM_KEY])
  rescue Errno::EACCES => _
  end
end

def directory_size(path)
  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, **OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'zWatched' || f == 'desktop.ini'
    f = "#{path}/#{f}"
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f if File.directory? f
  end
  total_size
end

def directory_checksum(path)
  checksums = directory_checksum_helper(path).join(', ')
  DIGEST_ALGO.hexdigest(checksums).to_s
end

def directory_checksum_helper(path)
  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  checksums = []
  entries = Dir.entries path, **OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'zWatched' || f == 'desktop.ini'
    f = "#{path}/#{f}"
    checksums << DIGEST_ALGO.file(f).to_s if File.file?(f)
    checksums = checksums + directory_checksum_helper(f) if File.directory? f
  end
  checksums
end

def show_group?(name)
  # matches (####) [####.]
  !name.match /\(\d{4}\) \[\d+.\]/
end

def nested_show?(show)
  nested_shows = ['A Certain Scientific Railgun', 'The Legend of Korra']
  nested_shows.include? show
end

def nested_folder?(show_name)
  nested_folders = ['Marvel']
  nested_folders.include? show_name
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
  $stdout.sync = true # don't buffer stdout
  puts "running on remote"
  $cache = Cache.load(CACHE_PATH, CACHE_REFRESH)

  REMOTE_PATHS.reject { |type, _path| SKIP.include?(type) }.each do |type, path|
    puts "running on #{type}: #{path}"
    iterate(path, 'remote'.freeze, type)
    print_updating("done running remote #{type}: #{path}", 0, true)
    $cache.write
  end
  binary = Zlib::Deflate.deflate(Marshal::dump(RESULTS))
  puts "Took #{Time.now - $start} seconds to run on remote. binary size: #{h_size(binary.bytesize)}"
  sleep 0.000001 # prevents control messages from getting mixed with other messages
  puts "transferring_data" # tells local that the next output is data
  sleep 0.000001 # prevents control messages from getting mixed with other messages
  $stdout.sync = false # turn back on stdout buffering
  print binary
end

def find_show_group(show_group_name, type)
  SHOW_SEMAPHORE.synchronize do
    # if type == :local
    #   type = :movies if RESULTS[:movies].include? show_group_name
    #   type = :tv if RESULTS[:tv].include? show_group_name
    # end
    show_group = RESULTS[type][show_group_name] || ShowGroup.new(show_group_name, (type != :movies) || !show_group?(show_group_name))
    RESULTS[type][show_group.name] = show_group
    show_group
  end
end

def find_show(show_group, name)
  show_group.shows[name] || Show.new(show_group, name)
end

def find_season(show, name)
  show.seasons[name] || Season.new(show, name)
end

def find_episode(season, name)
  season.episodes[name] || Episode.new(season, name)
end

def trim_results
  shows = {}
  [RESULTS[:movies], RESULTS[:tv]].each do |results|
    results.each_value do |show_group|
      show_group.shows.each_value do |show|
        if show.name == 'BBC Natural History Unit'
          # show.seasons.each do
        else
          shows[show.name] = show
        end
      end
    end
  end

  # puts shows.size
  # puts shows.class
  # puts shows.values.map(&:name).inspect

  RESULTS.each_value do |results|
    results.each_value do |show_group|
      show_group.shows.each_value do |show|
        show.seasons.each_value do |season|
          season.episodes.each_value do |episode|
            # sizes = Set.new
            # $included.each do |location|
            #   sizes << episode.send("#{location}_size")
            # end
            # season.episodes.delete(episode.name) if sizes.size == 1
            # if sizes.size == 2 && $included.include?('local'.freeze)
            #   non_local_sizes = Set.new
            #   $included.each do |location|
            #     non_local_sizes << episode.send("#{location}_size") unless location == 'local'.freeze
            #   end
            #   season.episodes.delete(episode.name) if non_local_sizes.size == 1 && non_local_sizes.none? {|s| s == 0}
            # end
            sizes = Set.new
            checksums = Set.new
            included = $included.dup
            included.each do |type|
              sizes << episode.send("#{type}_size")
              checksums << episode.send("#{type}_checksum").to_s
            end
            season.episodes.delete(episode.name) if sizes.size == 1 && checksums.size == 1
          end
          show.seasons.delete(season.name) if season.episodes.empty?
          # show.seasons.delete(season.name) if season.episodes.size > 10 # TODO delete
        end
        show_group.shows.delete(show.name) if show.seasons.empty?
      end
      results.delete show_group.name if show_group.shows.empty?
    end
  end
end

def print_results
  $cols = $terminal_size[:width]
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
  print " unchanged".uncolor
  print "\n"

  RESULTS.each do |type, results|
    puts type.to_s.light_yellow
    show_groups = results.values.sort_by(&:name)
    show_groups.each do |show_group|
      show_group.print
    end
  end

  if $included.include?('remote'.freeze) && $included.include?('external'.freeze)
    local = 0
    remote = 0
    external = 0
    RESULTS.each_value do |show_groups|
      show_groups.each_value do |show_group|
        show_group.shows.each_value do |show|
          show.seasons.each_value do |season|
            season.episodes.each_value do |episode|
              next if defined?(HIDE_LOCAL_ONLY) && HIDE_LOCAL_ONLY && episode.remote_size == 0 && episode.local_size != 0
              local += episode.local_size
              remote += episode.remote_size
              external += episode.external_size
            end
          end
        end
      end
    end
    transfer_amount = local
    transfer = ActiveSupport::NumberHelper.number_to_human_size(transfer_amount, {precision: 5, strip_insignificant_zeros: false})
    megabits_per_sec = 30
    est = (transfer_amount) / (1024 * 1024 * megabits_per_sec / 8)
    puts "Need to transfer #{transfer.light_cyan}: EST: #{to_human_duration(est).light_cyan} (#{megabits_per_sec} Mib/s)"
  end
end

class ShowGroup
  def print
    indent(ignore? ? 0 : 2) do
      puts name.indent($indent_size) unless ignore?
      shows.values.sort_by { |sg| sg.name }.each &:print
    end
  end
end

class Show
  def print
    indent do
      puts name.indent $indent_size
      @seasons.values.sort_by { |s| s.name }.each &:print
    end
  end
end

class Season
  def print
    indent(name == 'root' ? 0 : 4) do
      puts name.indent $indent_size unless name == 'root'
      indent(4) do
        str = ''
        episodes = @episodes.values.sort_by { |e| [e.name.count("/".freeze), e.name] }
        episodes.each do |episode|
          episode_str = episode.to_s
          if (str + "#{episode_str}, ").uncolorize.length + $indent_size < $cols
            str += "#{episode_str}, "
          else
            puts str.indent $indent_size
            str = "#{episode_str}, "
          end
        end
        puts str.indent $indent_size
      end
    end
  end
end

$indent_size = 0

def indent(numb = 2)
  $indent_size += numb
  yield
  $indent_size -= numb
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

if ARGV.empty?
  start = Time.now
  main
  trim_results
  print_results
  puts "Took #{Time.now - start} seconds"
else
  remote_main
end
