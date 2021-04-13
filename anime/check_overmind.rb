require 'digest'
require_relative './cache'

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
RESULTS = {}
HIDE_LOCAL_ONLY = false
# TODO hide_local_only make extensible so it dosen't only depend on local and remote
CACHE_PATH = 'check_overminds.cache.json'
CACHE_REFRESH = 30
DIGEST_ALGO = Digest::SHA256

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
  puts 'skipping external' unless $included.include? 'external'

  abort("overmind or an external hard drive need to be connected to work") unless ($included.size > 1)
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
  attr_accessor :season, :name, :local_size, :remote_size, :external_size, :long_external_size, :external_size_extra, :local_checksum, :remote_checksum, :external_checksum, :long_external_checksum

  def initialize(season, name)
    @season = season
    @name = name
    @local_size = 0
    @remote_size = 0
    @external_size = 0
    @long_external_size = 0
    @local_checksum = 0
    @remote_checksum = 0
    @external_checksum = 0
    @long_external_checksum = 0
    season.add_episode self
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
      next unless instance_var.to_s.end_with?('size')
      value = instance_variable_get instance_var
      biggest_value = value if value > biggest_value
    end
    biggest_value
  end

  def biggest_size_names
    biggest_instance_vars = []
    biggest_value = 0
    instance_variables.each do |instance_var|
      next unless instance_var.to_s.end_with?('size')
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
      checksum_mapping = {'0' => '0'}
      index = 0
      [@local_checksum.to_s, @remote_checksum.to_s, @external_checksum.to_s, @long_external_checksum.to_s].each do |checksum|
        if checksum_mapping[checksum].nil?
          index += 1
          checksum_mapping[checksum] = "Checksum ##{index}"
        end
      end
      checksums = {}
      checksums[:local] = LocalString.new(checksum_mapping[@local_checksum.to_s]).uncolor if $included.include? 'local'
      checksums[:remote] = RemoteString.new(checksum_mapping[@remote_checksum.to_s]).uncolor if $included.include? 'remote'
      checksums[:external] = ExternalString.new(checksum_mapping[@external_checksum.to_s]).uncolor if $included.include? 'external'
      checksums[:long_external] = LongExternalString.new(checksum_mapping[@long_external_checksum.to_s]).uncolor if $included.include? 'long_external'
      [:checksum, checksums]
    else
      sizes = {}
      sizes[:local] = LocalString.new(h_size(@local_size)).uncolor if $included.include? 'local'
      sizes[:remote] = RemoteString.new(h_size(@remote_size)).uncolor if $included.include? 'remote'
      sizes[:external] = ExternalString.new(h_size(@external_size)).uncolor if $included.include? 'external'
      sizes[:long_external] = LongExternalString.new(h_size(@long_external_size)).uncolor if $included.include? 'long_external'
      [:size, sizes]
    end
  end

  def h_size(size)
    ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5, strip_insignificant_zeros: false})
  end

  def sizes_same?()
    sizes = Set.new
    $included.each do |type|
      sizes << @local_size if $included.include? 'local'
      sizes << @remote_size if $included.include? 'remote'
      sizes << @external_size if $included.include? 'external'
      sizes << @long_external_size if $included.include? 'long_external'
    end
    sizes.delete(0)
    sizes.size == 1
  end

  def to_s
    name = File.basename(@name, '.*').cyan
    name = @name.cyan
    return "#{name}" if defined?(HIDE_LOCAL_ONLY) && HIDE_LOCAL_ONLY && local_size != 0 && remote_size == 0
    str = "#{name}:"

    different_part, human_strs = human_sizes

    # count number of times size shows up
    counts = Hash.new(0)
    # 0 is always colored
    counts['0 Bytes'.uncolor] = human_strs.count * -1 + 1
    # must be 2 or more in order to be uncolored
    counts['min repetitions to color'] = 2

    if different_part == :size
      biggest_size_names.each do |biggest_size_name|
        # drop @, size / checksum and convert to symbol
        counts[human_strs[biggest_size_name[1..-1].split('_')[0..-2].join('_').to_sym].uncolor] = human_strs.count
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

    str << " #{human_strs[:local]}" if human_strs.has_key? :local
    str << " (#{human_strs[:remote]})" if human_strs.has_key?(:remote)
    both_zero = external_size == long_external_size && external_size == 0
    # str << " [both]" if both_zero && (sizes.has_key?(:external) || sizes.has_key?(:long_external))
    str << " [#{human_strs[:external]}]" if both_zero && (human_strs.has_key?(:external) || human_strs.has_key?(:long_external))
    str << " [#{human_strs[:external]}]" if !both_zero && human_strs.has_key?(:external) && external_size != 0
    str << ' &' if in_both_external?
    str << " {#{human_strs[:long_external]}}" if !both_zero && human_strs.has_key?(:long_external) && long_external_size != 0
    str << @external_size_extra.to_s
    str
  end
end

class Cache < BaseCache
  def initialize(cache)
    super(cache)
  end

  def self.load_episode(path, last_modified, payload)
    CacheEpisode.new(path, last_modified, payload)
  end

  def write(path = CACHE_PATH)
    super(path)
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

def main
  puts Time.now
  $cache = Cache.load(CACHE_PATH)
  if $included.include? 'remote'
    begin
      Net::SSH.start(ENV['OVERMIND_HOST'], ENV['OVERMIND_USER'], password: ENV['OVERMIND_PASSWORD'], timeout: 1, port: 666) do |ssh|
        ssh.sftp.connect do |sftp|
          sftp.upload!(__FILE__, "remote.rb")
          sftp.upload!("cache.rb", "cache.rb")
        end
        puts 'running on remote'
        serialized_results = ssh.exec! "source load_rbenv && ruby remote.rb remote"
        begin
          RESULTS.replace Marshal::load(serialized_results)
        rescue TypeError => e
          $included.delete? 'remote' # debug?
          puts 'Error reading results from remote'
          puts serialized_results
        end
        ssh.exec! "rm remote.rb"
        ssh.exec! "rm cache.rb"
      end
    rescue Errno::EAGAIN => e
      puts 'could not connect to overmind'
      $included.delete('remote')
    end
  end
  if $included.include? 'local'
    puts 'running locally'
    iterate LOCAL_PATH, 'local'
    iterate LOCAL_PATH + '/zWatched', 'local'
    puts
  end
  $cache.write(CACHE_PATH)
  if $included.include? 'external'
    puts 'running on external'
    iterate EXTERNAL_PATH, 'external'
    iterate EXTERNAL_PATH + '/zWatched', 'external'
    puts
  end
  $cache.write(CACHE_PATH)
  if $included.include? 'long_external'
    puts 'running on long external'
    iterate LONG_EXTERNAL_PATH, 'long_external'
    iterate LONG_EXTERNAL_PATH + '/zWatched', 'long_external'
    puts
  end
  $cache.write(CACHE_PATH)
end

def iterate(path, type)
  shows = Dir.entries path, **OPTS
  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    count += 1
    # break if count > 5 # DEBUG
    # next unless show < "A"
    # next unless show.start_with?('A Silent')
    analyze_show show, path + '/' + show, type
  end
end

def analyze_show(show, path, type)
  begin
    anime = RESULTS[show] || Anime.new(show)
    RESULTS[anime.name] = anime
    root_season = find_season anime, 'root'
    entries = Dir.entries path, **OPTS
    entries.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' # || entry.end_with?('.txt')
      analyze_show(entry, path + '/' + entry, type) and next if nested_show? entry
      if File.directory?("#{path}/#{entry}")
        analyze_season find_season(anime, entry), path + '/' + entry, type
      else
        analyze_episode root_season, entry, path + '/' + entry, type
      end
    end
    if root_season.episodes.empty?
      anime.seasons.delete(root_season.name)
    end
  rescue Errno::EACCES => _
  end
end

def analyze_season(season, path, type)
  begin
    entries = Dir.entries path, **OPTS
    entries.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
      analyze_episode season, entry, path + '/' + entry, type
    end
  rescue Errno::EACCES => _
  end
end

def analyze_episode(season, episode_name, path, type)
  begin
    return if File.directory? path
    print "\rcalculating size for #{path}".ljust(120) if ARGV.empty?
    data, _cached = $cache.get(path) do
      if Time.now - $cache.last_write_time > CACHE_REFRESH
        $cache.write(CACHE_PATH)
      end
      file_size = File.size(path)
      if (file_size == 0) # so
        file_size = 1
      else
        episode_name.chomp!('.filepart')
        episode_name.chomp!('.crdownload')
        episode_name.chomp! '.mp4'
        episode_name.chomp! '.mkv'
      end
      {CHECKSUM_KEY => DIGEST_ALGO.file(path).to_s, SIZE_KEY => file_size}
    end

    episode = find_episode season, episode_name
    episode.send(type + '_size=', data[SIZE_KEY])
    episode.send(type + '_checksum=', data[CHECKSUM_KEY])
  rescue Errno::EACCES => _
  end
end

def nested_show?(show)
  nested_shows = ['A Certain Scientific Railgun', 'The Legend of Korra']
  nested_shows.include? show
end

def remote_main
  $cache = Cache.load(CACHE_PATH)
  REMOTE_PATHS.each do |rp|
    iterate(rp, 'remote') if File.exist?(rp)
    $cache.write(CACHE_PATH)
  end
  puts Marshal::dump(RESULTS)
end

def find_season(anime, name)
  anime.seasons[name] || Season.new(anime, name)
end

def find_episode(season, name)
  season.episodes[name] || Episode.new(season, name)
end

def find_dups
  dups = Set.new
  RESULTS.each_value do |show|
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

def trim_results
  RESULTS.each_value do |show|
    show.seasons.each_value do |season|
      season.episodes.each_value do |episode|
        sizes = Set.new
        checksums = Set.new
        included = $included.dup
        included.delete('external') if episode.external_size != episode.long_external_size && episode.external_size == 0
        included.delete('long_external') if episode.external_size != episode.long_external_size && episode.long_external_size == 0
        included.each do |type|
          sizes << episode.send("#{type}_size")
          checksums << episode.send("#{type}_checksum").to_s
        end

        season.episodes.delete(episode.name) if sizes.size == 1 && checksums.size == 1
        # if sizes.size == 2 && $included.include?('long_external')
        #   non_long_external_sizes = Set.new
        #   $included.each do |type|
        #     non_long_external_sizes << episode.send("#{type}_size") unless type == 'long_external'
        #   end
        season.episodes.delete(episode.name) if sizes.size == 1 && checksums.size == 1 #if non_long_external_sizes.size == 1
        # end
      end
      show.seasons.delete(season.name) if season.episodes.size == 0
      # show.seasons.delete(season.name) if season.episodes.size > 10 # TODO delete
    end
    RESULTS.delete(show.name) if show.seasons.size == 0
  end
end

def print_results
  original_verbosity = $VERBOSE
  $VERBOSE = nil
  cols = `tput cols`.to_i
  $VERBOSE = original_verbosity
  print LocalString.new("local size").paint if $included.include? 'local'
  if $included.include? 'remote'
    print " ("
    print RemoteString.new("remote size").paint
    print ")"
  end
  if $included.include? 'external'
    print " ["
    print ExternalString.new("external size").paint
    print "]"
  end
  if $included.include?('long_external') && $included.include?('external')
    print " |"
  end
  if $included.include?('long_external')
    print " {"
    print LongExternalString.new("long external size").paint
    print "}"
  end
  print " unchanged".uncolor
  print "\n"

  shows = RESULTS.values.sort_by(&:name).reverse
  shows.each do |show|
    puts show.name
    show.seasons.each_value do |season|
      puts season.name.indent 4 unless season.name == 'root'
      indent_size = season.name == 'root' ? 4 : 8
      str = ''
      episodes = season.episodes.values.sort_by { |e| e.name.to_f == 0 ? 9999 : e.name.to_f }
      episodes.each do |episode|
        episode_str = episode.to_s
        if (str + "#{episode_str}, ").uncolorize.length + indent_size < cols
          str += "#{episode_str}, "
        else
          puts str.indent indent_size
          str = "#{episode_str}, "
        end
      end
      puts str.indent indent_size
    end
  end

  if $included.include?('remote') && $included.include?('external')
    remote = 0
    external = 0
    local = 0
    RESULTS.each_value do |show|
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
  main
  dups = find_dups
  trim_results
  print_results
  print_dups dups
  puts "Took #{Time.now - start} seconds"
else
  remote_main
end
