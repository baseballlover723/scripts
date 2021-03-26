PATH = '/mnt/d/anime'
OPTS = {encoding: 'UTF-8'}

def iterate(path, f)
  shows = Dir.entries path, **OPTS
  count = 0
  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    # next unless show.start_with?('C')
    f.puts show
    count += 1
    # break if count > 5
  end
  puts count
end

def main
  File.open 'anime-list.txt', 'w' do |f|
    f.puts 'Not Watched: '
    f.puts ''
    iterate PATH, f
    f.puts ''
    f.puts 'Watched:'
    f.puts ''
    iterate PATH + '/zWatched', f
  end

end

main

