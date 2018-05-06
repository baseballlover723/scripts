require 'dotenv/load'
require 'pty'
require 'shellwords'

LOCAL_PATH = '/mnt/d/anime'
REMOTE_PATH = '/entertainment/anime'
ANIME_NAME = 'The Devil is a Part-Timer!'
# ANIME_NAME = 'zWatched/The Eccentric Family'
OPTS = {encoding: 'UTF-8'}

OPTIONS = "-aPv -e 'ssh -p 666' --timeout 10 --protect-args"

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
