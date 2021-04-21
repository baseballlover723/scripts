require 'set'
require 'colorize'
require 'shellwords'

PATHS = [
 # "/mnt/c/Users/Philip Ross/Downloads/Akudama Drive",
  "/mnt/c/Users/Philip Ross/Downloads/Season 3",
  # "/mnt/d/anime/Re;ZERO Starting Life in Another World (In Progress)/Season 2 (In Progress)",
 # "/mnt/f/anime/zWatched/Attack On Titan (In Progress)/Season 3",
# "/mnt/c/Users/Philip Ross/Downloads/Place to Place",
# '/mnt/c/Users/Philip Ross/Downloads/Season 2',
# '/mnt/c/Users/Philip Ross/Downloads/Black Lagoon/Season 2',
# '/mnt/c/Users/Philip Ross/Downloads/Black Lagoon/Season 3',
# '/mnt/c/Users/Philip Ross/Downloads/Accel World',
]
PATHS.each {|p| p << '/' unless p.end_with? '/'}
OPTS = {encoding: 'UTF-8'}

def expand_paths
  expanded = Set.new
  PATHS.each do |path|
    expanded << path and next unless path.end_with?('*') || path.end_with?('*/')
    dir_path = path.gsub('*/', '').gsub('*', '')
    entries = Dir.entries dir_path, **OPTS
    entries.each do |entry|
      next if entry == '.' || entry == '..' || entry == 'desktop.ini'
      expanded << dir_path + entry + '/'
    end

  end

  puts "pathes: #{expanded.inspect}"

  # exit
end

def main
  expand_paths

  PATHS.each do |path|
    first_episode = find_first_episode(path)
    puts "first #{first_episode}"
    puts
    system "mediainfo #{path.shellescape}#{first_episode.shellescape}"

    print "Select tracks to mark as default (seperate by comma) (a: audio, s: subtitles): "
    default_tracks = gets.strip.split(',').map(&:strip)
    # default_tracks << 'v1'

    set_defaults(path, default_tracks)
  end
end

def iterate(path)
  entries = Dir.entries path, **OPTS
  files = []
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini'
    next if entry.end_with? '.enc'
    files.push entry
    yield entry if block_given?
    # break
  end
  files.to_enum
end

def find_first_episode(path)
  iterate(path).sort_by {|f| f.to_i}.first
end

def set_defaults(path, default_tracks)
  if default_tracks.map(&:chars).map(&:first).uniq.size != default_tracks.size
    puts "default_tracks: #{default_tracks} should only set 1 per track type (audio, subtitle, ...)"
    exit(-1)
  end
  puts "tracks: #{default_tracks}"

  iterate(path) do |file|
    set_default path.shellescape + file.shellescape, default_tracks
  end

end

def set_default(path, default_tracks)
  puts ''
  puts File.basename(path).light_cyan
  tracks = `mkvmerge -i #{path}`.lines
  numb_audio = tracks.count {|t| t.include? 'audio'}
  numb_subtitles = tracks.count {|t| t.include? 'subtitles'}

  cmd = "mkvpropedit #{path}"
  default_tracks.each do |default_track|
    track_type_numb = default_track[/\d+/].to_i
    track_type = default_track[0]
    # set other tracks to not be default
    case track_type
    when 'a'
      numb_audio.times do |i|
        i += 1
        cmd += " --edit track:#{track_type}#{i} --set flag-default=0 --set flag-forced=0" if i != track_type_numb
      end
    when 's'
      numb_subtitles.times do |i|
        i += 1
        cmd += " --edit track:#{track_type}#{i} --set flag-default=0 --set flag-forced=0" if i != track_type_numb
      end
    end

    # set given tracks as default
    cmd += " --edit track:#{default_track} --set flag-default=1 --set flag-forced=0"

  end

  # puts cmd
  system(cmd)
end

def rename_show(path, rename, first_number)
  entries = Dir.entries path, **OPTS
  count = 0
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini'
    if File.directory?("#{path}/#{entry}")
      rename_season path + '/' + entry, rename, first_number
    else
      rename_episode path, entry, rename, first_number
    end
    count += 1
    # break if count > 2
  end
end

def rename_season(path, rename, first_number)
  episodes = Dir.entries path, **OPTS
  count = 0
  episodes.each do |episode_name|
    next if episode_name == '.' || episode_name == '..' || episode_name == 'desktop.ini'
    rename_episode path, episode_name, rename, first_number
    count += 1
    # break if count > 2
  end
end

def rename_episode(folder_path, name, rename, first_number)
  return if !name.include?('.') || name.end_with?('.enc') || name.end_with?('x.264')
  episode_number = extract_number name, rename, first_number
  puts "Not renaming '#{name.light_yellow}'" or return unless episode_number
  if rename
    File.rename(folder_path + '/' + name, folder_path + '/' + episode_number.to_s + File.extname(name))
  else
    RESULTS << episode_number
  end
end

def extract_number(str, rename, first_number)
  str = str[IGNORE_PREFIX.length..-1] if str.start_with?(IGNORE_PREFIX)
  return if str.end_with?(IGNORE_FILE_ENDING)
  str = str.gsub /\(\d\d\d\d\)/, ''

  puts str if !rename && first_number
  numb = first_number ? str[/\d+/] : str.scan(/\d+/)[1]
  # numb = str[/E\d+/][/\d+/].to_i
  # numb = str[/E\d+-E\d+/]&.gsub('E', '') || numb
  return unless numb
  numb = numb.to_i
  numb += NUMBER_INCREMENT if defined? NUMBER_INCREMENT

  numb if numb < 1900 # probably a movie
  numb
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\?]/) {|x| "\\" + x}
end

def yesno(prompt = 'Continue?', default = true)
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until %w[y n].include? a
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    a = ask("#{prompt} #{s} ") {|q| q.limit = 1; q.case = :downcase}
    $VERBOSE = original_verbosity
    exit 130 if a == "\cC" # handle ctrl c
    a = d if a.length == 0
  end
  a == 'y'
end

def analyze_missing
  missing_episodes_numbers = []
  set = Set.new
  duplicates = RESULTS.select {|e| !set.add?(e)}

  puts "duplicate episode numbers: #{duplicates.map(&:to_s).map(&:light_red).join(', ')}" unless duplicates.empty?
  RESULTS.min.upto(RESULTS.max).each do |numb|
    missing_episodes_numbers << numb unless set.include? numb
  end
  if missing_episodes_numbers.empty?
    puts 'no missing episodes'.light_green
  else
    puts "missing episodes: #{missing_episodes_numbers.map(&:to_s).map(&:light_red).join(', ')}"
  end
  return missing_episodes_numbers.empty? && duplicates.empty?
end

main
