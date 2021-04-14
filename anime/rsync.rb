require 'dotenv/load'
require 'pty'
require 'shellwords'

LOCAL_PATH = '/mnt/d/anime'
# LOCAL_PATH = '/mnt/d/anime/zWatched'
REMOTE_PATH = '/entertainment/anime'
# LOCAL_PATH = '/mnt/e/movies'
# REMOTE_PATH = '/entertainment/movies'
ANIME_NAME = ".hack"
# ANIME_NAME = 'Olympus Has Fallen/Angel Has Fallen (2019) [1080p] {x265}'
# ANIME_NAME = 'Log Horizon'
OPTS = {encoding: 'UTF-8'}

MODE = :sync_with_new_mtimes
# MODE = :sync_file_with_mtimes
# MODE = :sync_directories_with_mtimes

case MODE
when :sync_with_new_mtimes
  OPTIONS = "-chPv -e 'ssh -p 666' --timeout 10 --protect-args"
  DIRECTORIES = false
when :sync_file_with_mtimes
  OPTIONS = "-ahPv -e 'ssh -p 666' --timeout 10 --protect-args"
  DIRECTORIES = false
when :sync_directories_with_mtimes
  OPTIONS = "-ahPv -e 'ssh -p 666' --include='*/' --exclude='*' --timeout 10 --protect-args" # directory
  DIRECTORIES = true
end
# -a archieve
# -c use checksums instead of file size
# -h human readable numbers
# -P progress bar
# -v verbose

def main
  iterate_recursive local do |episode_path|
    local_path = "#{local}#{episode_path}".shellescape
    episode_path = File.dirname(episode_path)[0..-2] if DIRECTORIES # send to parent and remove . from end
    remote_path = "#{remote}#{episode_path}".shellescape
    puts "syncing #{local_path} to #{remote_path}"
    run_shell_command "rsync #{options} #{local_path} #{remote_path}"
  end
end

def options
  OPTIONS
end

def local
  "#{LOCAL_PATH}/#{ANIME_NAME}/"
end

def remote
  "#{ENV['OVERMIND_USER']}@#{ENV['OVERMIND_HOST']}:#{REMOTE_PATH}/#{ANIME_NAME}/"
end

def iterate_recursive(path)
  Dir.glob(escape_glob(path) + '**/*').reject { |f| DIRECTORIES ^ File.directory?(f) }.each do |f|
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
