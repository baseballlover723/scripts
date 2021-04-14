require 'dotenv/load'
require 'pty'
require 'shellwords'
require 'active_support/core_ext/string/indent'
$indent_size = 4
$indent = -$indent_size

LOCAL_PATH = '/mnt/d/anime'
REMOTE_PATH = '/entertainment/anime'
# LOCAL_PATH = '/mnt/e/movies'
# REMOTE_PATH = '/entertainment/movies'
# ANIME_NAME = ".hack"
# ANIME_NAME = 'Olympus Has Fallen/Angel Has Fallen (2019) [1080p] {x265}'
OPTS = {encoding: 'UTF-8'}

MODES = [:unstarted, :sync_with_new_mtimes, :sync_file_with_mtimes, :sync_directories_with_mtimes, :done]

# -a archieve
# -c use checksums instead of file size
# -h human readable numbers
# -P progress bar
# -v verbose
def calc_options(mode)
  case mode
  when :sync_with_new_mtimes
    options = "-chPv -e 'ssh -p 666' --timeout 10 --protect-args"
    directories = false
    return options, directories
  when :sync_file_with_mtimes
    options = "-ahPv -e 'ssh -p 666' --timeout 10 --protect-args"
    directories = false
    return options, directories
  when :sync_directories_with_mtimes
    options = "-ahPv -e 'ssh -p 666' --include='*/' --exclude='*' --timeout 10 --protect-args" # directory
    directories = true
    return options, directories
  end
end

def main
  if defined? ANIME_NAME
    rsync_animes([ANIME_NAME])
  else
    iterate_anime_files("dirty_animes_*.txt")
  end
end

def move_mode_forwards(path)
  lines = File.read(path).split("\n")
  mode = lines.shift.to_sym
  next_mode = calc_next_mode(mode)
  content = "#{next_mode.to_s}\n"
  content += lines.join("\n")
  content += "\n"
  File.write(path, content)
  next_mode
end

def calc_next_mode(mode)
  MODES.each_cons(2) do |current_mode, next_mode|
    return next_mode if current_mode == mode
  end
  MODES.last
end

def local(anime)
  path = "#{LOCAL_PATH}/#{anime}/"
  path = "#{LOCAL_PATH}/zWatched/#{anime}/" unless Dir.exist?(path)
  raise "can't find anime #{anime} at \"#{"#{LOCAL_PATH}/#{anime}/"}\" or \"#{path}\"" unless Dir.exist?(path)
  path
end

def remote(anime)
  "#{ENV['OVERMIND_USER']}@#{ENV['OVERMIND_HOST']}:#{REMOTE_PATH}/#{anime}/"
end

def iterate_anime_files(glob)
  entries = Dir.glob glob
  entries.each.with_index do |path, i|
    iterate_anime_file(path, " (#{i + 1} / #{entries.size})")
  end
end

def iterate_anime_file(path, index_str)
  $indent += $indent_size
  animes = File.read(path).split("\n")
  mode = animes.shift.to_sym
  $indent -= $indent_size and return if mode == :done

  puts "\n**************************************\n\nanime file: #{path}#{index_str} &&&&&&&&&&&&&&&&&&&&&&&&".indent $indent
  rsync_animes(animes, mode, path)
end

def rsync_animes(animes, mode = MODES.first, path = nil)
  if mode == MODES.first
    mode = (path ? move_mode_forwards(path) : calc_next_mode(mode))
  end

  while mode != MODES.last
    animes.each.with_index do |anime, i|
      rsync_anime(anime, mode, " (#{i + 1} / #{animes.size})")
    end
    mode = (path ? move_mode_forwards(path) : calc_next_mode(mode))
    print "\a"
  end
  $indent -= $indent_size
end

def rsync_anime(anime, mode, index_str = '')
  $indent += $indent_size
  puts "\n Rsyncing #{anime} with mode #{mode}#{index_str} ******************\n\n".indent $indent, "*"
  options, directories = calc_options(mode)
  local_anime = local(anime)

  $indent += $indent_size
  iterate_recursive local_anime, directories do |episode_path|
    local_path = "#{local_anime}#{episode_path}"
    episode_path = File.dirname(episode_path)[0..-2] if directories # send to parent and remove . from end
    remote_path = "#{remote(anime)}#{episode_path}"
    puts "syncing (#{mode}) #{local_path} to #{remote_path}".indent $indent
    run_shell_command "rsync #{options} #{local_path.shellescape} #{remote_path.shellescape}"
  end
  if directories
    # Root folder
    local_path = local_anime[0..-2]
    remote_path = File.dirname(remote(anime))
    puts "syncing (#{mode}) #{local_path} to #{remote_path}".indent $indent
    run_shell_command "rsync #{options} #{local_path.shellescape} #{remote_path.shellescape}"
  end
  $indent -= $indent_size

  $indent -= $indent_size
end

def local(anime)
  path = "#{LOCAL_PATH}/#{anime}/"
  path = "#{LOCAL_PATH}/zWatched/#{anime}/" unless Dir.exist?(path)
  raise "can't find anime #{anime} at \"#{"#{LOCAL_PATH}/#{anime}/"}\" or \"#{path}\"" unless Dir.exist?(path)
  path
end

def remote(anime)
  "#{ENV['OVERMIND_USER']}@#{ENV['OVERMIND_HOST']}:#{REMOTE_PATH}/#{anime}/"
end

def iterate_recursive(path, directories = false)
  Dir.glob(escape_glob(path) + '**/*').reject { |f| directories ^ File.directory?(f) }.each do |f|
    relative_path = f.sub path, ''
    yield relative_path
  end
end

def run_shell_command(command)
  begin
    PTY.spawn(command) do |stdout, stdin, pid|
      begin
        stdout.each_char { |line| print line }
        stdout.flush
      rescue Errno::EIO
      end
    end
  rescue PTY::ChildExited
  end
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) { |x| "\\" + x }
end

main
