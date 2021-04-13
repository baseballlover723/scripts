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

OPTIONS = "-acPv -e 'ssh -p 666' --timeout 10 --protect-args"

def main
  iterate_recursive local do |episode_path|
    local_path = "#{local}#{episode_path}".shellescape
    remote_path = "#{remote}#{episode_path}".shellescape
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
  Dir.glob(escape_glob(path) + '**/*').reject {|f| File.directory? f}.each do |f|
    relative_path = f.sub path, ''
    yield relative_path
    # break
  end

end

def run_shell_command(command)
  begin
    PTY.spawn(command) do |stdout, stdin, pid|
      begin
        stdout.each_char {|line| print line}
        stdout.flush
      rescue Errno::EIO
      end
    end
  rescue PTY::ChildExited
  end
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) {|x| "\\" + x}
end

main
