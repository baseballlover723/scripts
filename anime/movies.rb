REMOTE = !ARGV.empty?
# LOCAL_PATH = '/mnt/c/Users/Philip Ross/Downloads'
LOCAL_PATHES = {movies: '/mnt/e/movies', tv: '/mnt/e/tv'}
EXTERNAL_PATHES = {movies: '/mnt/h/movies', tv: '/mnt/i/tv'}
# EXTERNAL_PATHES = {movies: '/mnt/e/movies'}
REMOTE_PATHES = {movies: '../../entertainment/movies', tv: '../../entertainment/tv'}
# REMOTE_PATHES = {movies: '../../entertainment/movies'}
OPTS = {encoding: 'UTF-8'}
RESULTS = {movies: {}, tv: {}, local: {}}
MOVIE_EXTENSIONS = ['.mkv', '.mp4', '.m4v', '.srt', '.avi']
BLACKLIST = ['anime', 'Naruto', 'Naruto - Copy']
# FILTER = /Season \d\d - Episode(s?) \d\d\d-\d\d\d/
FILTER = /Naruto/
# Need to transfer 1.9074 TB: EST: 16 days, 22 hours, 20 minutes and 59 seconds (1400 KB/s)
# Need to transfer 1.9074 TB: EST: 16 days, 22 hours, 20 minutes and 59 seconds (1400 KB/s)
if ARGV.empty?
  require 'dotenv/load'
  require 'net/ssh'
  require 'net/sftp'
  require 'colorize'
  require 'active_support'
  require 'active_support/number_helper'
  require 'active_support/core_ext/string/indent'

  $included = Set.new
  $included << 'remote'
  $included << 'local' if File.directory? LOCAL_PATHES.values.first
  $included << 'external' if File.directory? EXTERNAL_PATHES.values.first
  puts 'skipping overmind' unless $included.include? 'remote'
  puts 'skipping local' unless $included.include? 'local'
  puts 'skipping external' unless $included.include? 'external'

  # abort("overmind or an external hard drive need to be connected to work") unless ($included.size > 1)
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
  attr_accessor :season, :name, :remote_size, :external_size, :local_size

  def initialize(season, name)
    @season = season
    @name = name
    @remote_size = 0
    @external_size = 0
    @local_size = 0
    season.add_episode self
  end

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
    sizes = {}
    sizes[:local_size] = LocalString.new(h_size(@local_size)).uncolor if $included.include? 'local'
    sizes[:remote_size] = RemoteString.new(h_size(@remote_size)).uncolor if $included.include? 'remote'
    sizes[:external_size] = ExternalString.new(h_size(@external_size)).uncolor if $included.include? 'external'
    sizes
  end

  def h_size(size)
    ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5, strip_insignificant_zeros: false})
  end

  def to_s
    sizes = human_sizes

    # count number of times size shows up
    size_count = Hash.new(0)
    # 0 is always colored
    size_count['0 Bytes'.uncolor] = sizes.count * -1 + 1
    # must be 2 or more in order to be uncolored
    size_count['min repetitions to color'] = 2
    biggest_size_names.each do |biggest_size_name|
      # drop @ and convert to symbol
      size_count[sizes[biggest_size_name[1..-1].to_sym].uncolor] = sizes.count
    end

    # initialize all sizes in size count
    sizes.each do |_size_location, size|
      size_count[size] = 0 unless size_count.include? size
    end
    sizes.each do |_size_location, size|
      size_count[size.dup] += 1
    end

    # color if not the most common (0 always colored)
    max_size_count = size_count.values.max
    sizes.each do |size_location, size|
      if size_count[size] == max_size_count
        sizes[size_location] = size.uncolor
      else
        sizes[size_location] = size.paint
      end
    end

    # name = File.basename(@name, '.*'). cyan
    name = @name
    name = name[/.*S\d\dE\d\d/] if name[/S\d\dE\d\d/]
    name = name.cyan
    str = "#{name}:"
    str << " #{sizes[:local_size]}" if sizes.has_key? :local_size
    str << " (#{sizes[:remote_size]})" if sizes.has_key? :remote_size
    str << " [#{sizes[:external_size]}]" if sizes.has_key? :external_size
    str
  end
end

def main
  puts Time.now
  if $included.include? 'remote'
    begin
      Net::SSH.start(ENV['OVERMIND_HOST'], ENV['OVERMIND_USER'], password: ENV['OVERMIND_PASSWORD'], timeout: 1, port: 666) do |ssh|
        ssh.sftp.connect do |sftp|
          sftp.upload!(__FILE__, "remote.rb")
        end
        puts 'running on remote'
        serialized_results = ssh.exec! "source load_rbenv && ruby remote.rb remote"
        begin
          RESULTS.replace Marshal::load(serialized_results)
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
  end
  if $included.include? 'local'
    puts 'running on local'
    LOCAL_PATHES.each do |type, path|
      iterate path, 'local', type
    end
  end
  if $included.include? 'external'
    puts 'running on external'
    EXTERNAL_PATHES.each do |type, path|
      iterate path, 'external', type
    end
  end
end

def iterate(path, location, type)
  shows = Dir.entries path, OPTS
  count = 0
  shows.each do |show_name|
    next if show_name == '.' || show_name == '..' || show_name == 'zWatched' || show_name == 'desktop.ini'
    next unless File.directory? path + '/' + show_name
    next if BLACKLIST.include? show_name
    next if show_name[FILTER]
    # next unless show.start_with?('C')
    analyze_show_group show_name, path + '/' + show_name, location, type
    count += 1
    # break if count > 2
  end
end

def analyze_show_group(name, path, location, type)
  show_group = find_show_group name, type
  if show_group.ignore?
    analyze_show show_group, name, path, location, type
    return
  end

  entries = Dir.entries path, OPTS
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_show show_group, entry, path + '/' + entry, location, type
  end
end

def analyze_show(show_group, show_name, path, location, type)
  # iterate(path, location, type) if nested_folder? show_name
  # (analyze_show_group(show_name, path, location, type); return) if show_group? show_name
  show = find_show(show_group, show_name)
  root_season = find_season show, 'root'
  entries = Dir.entries path, OPTS
  entries.sort.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    if File.directory?("#{path}/#{entry}")
      analyze_season find_season(show, entry), path + '/' + entry, location
    else
      analyze_episode root_season, entry, path + '/' + entry, location
    end
  end
  if root_season.episodes.empty?
    show.seasons.delete(root_season.name)
  end
end

def analyze_season(season, path, location)
  entries = Dir.entries path, OPTS
  entries.sort.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini' || entry.end_with?('.txt')
    analyze_episode season, entry, path + '/' + entry, location
  end
end

def analyze_episode(season, episode_name, path, location)
  if File.directory?(path)
    file_size = directory_size(path)
  else
    file_size = File.size(path)
    if (file_size == 0) # so
      file_size = 1
    end
  end
  episode_name.chomp!('.filepart')
  episode_name.chomp!('.crdownload')
  # return unless episode_name.end_with? *MOVIE_EXTENSIONS
  episode = find_episode season, episode_name
  episode.send(location + '_size=', file_size)
end

def directory_size(path)
  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'zWatched' || f == 'desktop.ini'
    f = "#{path}/#{f}"
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f if File.directory? f
  end
  total_size
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

def remote_main
  REMOTE_PATHES.each do |type, path|
    iterate(path, 'remote', type)
  end
  puts Marshal::dump(RESULTS)
end

def find_show_group(show_group_name, type)
  # if type == :local
  #   type = :movies if RESULTS[:movies].include? show_group_name
  #   type = :tv if RESULTS[:tv].include? show_group_name
  # end
  show_group = RESULTS[type][show_group_name] || ShowGroup.new(show_group_name, (type != :movies) || !show_group?(show_group_name))
  RESULTS[type][show_group.name] = show_group
  show_group
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
            # if sizes.size == 2 && $included.include?('local')
            #   non_local_sizes = Set.new
            #   $included.each do |location|
            #     non_local_sizes << episode.send("#{location}_size") unless location == 'local'
            #   end
            #   season.episodes.delete(episode.name) if non_local_sizes.size == 1 && non_local_sizes.none? {|s| s == 0}
            # end
            sizes = Set.new
            included = $included.dup
            included.each do |type|
              sizes << episode.send("#{type}_size")
            end
            season.episodes.delete(episode.name) if sizes.size == 1
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
  original_verbosity = $VERBOSE
  $VERBOSE = nil
  $cols = `tput cols`.to_i
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
  print " unchanged".uncolor
  print "\n"

  RESULTS.delete :movies # debug
  RESULTS.each do |type, results|
    puts type.to_s.light_yellow
    show_groups = results.values.sort_by(&:name)
    show_groups.each do |show_group|
      show_group.print
    end
  end

  if $included.include?('remote') && $included.include?('external')
    remote = 0
    external = 0
    RESULTS.each_value do |show_groups|
      show_groups.each_value do |show_group|
        show_group.shows.each_value do |show|
          show.seasons.each_value do |season|
            season.episodes.each_value do |episode|
              remote += episode.remote_size
              external += episode.external_size
            end
          end
        end
      end
    end
    transfer_amount = external
    transfer = ActiveSupport::NumberHelper.number_to_human_size(transfer_amount, {precision: 5, strip_insignificant_zeros: false})
    kilobytes_per_sec = 1200
    est = (transfer_amount) / (1024 * kilobytes_per_sec)
    puts "Need to transfer #{transfer.light_cyan}: EST: #{to_human_duration(est).light_cyan} (#{kilobytes_per_sec} KB/s)"
  end
end

class ShowGroup
  def print
    indent(ignore? ? 0 : 2) do
      puts name.indent($indent_size) unless ignore?
      shows.each_value &:print
    end
  end
end

class Show
  def print
    indent do
      puts name.indent $indent_size
      @seasons.each_value &:print
    end
  end
end

class Season
  def print
    indent(name == 'root' ? 0 : 4) do
      puts name.indent $indent_size unless name == 'root'
      indent(4) do
        str = ''
        episodes = @episodes.values.sort_by {|e| e.name.to_f == 0 ? 9999 : e.name.to_f}
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

if ARGV.empty?
  start = Time.now
  main
  trim_results
  print_results
  puts "Took #{Time.now - start} seconds"
else
  remote_main
end
